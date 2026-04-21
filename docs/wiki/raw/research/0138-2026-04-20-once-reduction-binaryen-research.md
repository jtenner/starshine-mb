# Once-Reduction Binaryen Research

## Scope

- Deepen the existing `once-reduction` landing page into a real Binaryen dossier.
- Use Binaryen `version_129` as the main semantic oracle.
- Explain the actual implementation structure in beginner-friendly language.
- Record the important difference between what the pass name suggests and what the code really proves.
- Keep the result useful for future Starshine parity work in the early module-prepass cluster between `memory-packing` and `global-refining`.

## Why this pass was the right target now

- The updated tracker named `once-reduction` as the strongest remaining implemented landing-page target after `memory-packing` was deepened.
- `once-reduction` is already implemented locally, but the living wiki surface was still only a stub landing page.
- It sits in a very important early no-DWARF module cluster:
  - `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> ...`
- The saved generated-artifact `-O4z` audit already shows slot `4` (`once-reduction`) as green on both exact wasm and normalized WAT, so this is not an emergency corruption-triage pass right now. The durable work is understanding, documenting, and teaching the real implementation contract.

## Local source material audited first

Repo docs and trackers:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- existing living pages under `docs/wiki/binaryen/passes/once-reduction/`
- saved generated-artifact audit `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- saved Binaryen debug log `.artifacts/o4z-wasm-opt-debug.log`

Current in-tree Starshine implementation surfaces:

- `src/passes/once_reduction.mbt`
- `src/passes/once_reduction_test.mbt`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/registry_test.mbt`
- parser / annotation support surfaces that matter for upstream parity:
  - `src/wast/parser.mbt`
  - `src/wast/lower_to_lib.mbt`
  - `src/wast/module_wast_tests.mbt`

## Important local backlog note

- `agent-todo.md` currently has **no dedicated `OR` / once-reduction slice**.
- The relevant local backlog surface is indirect:
  - the canonical no-DWARF pathway page still lists `once-reduction` as the early module pre-pass after `memory-packing`
  - the scheduler and registry surfaces already expose the pass in-tree
  - the meaningful missing work here is documentation and official-source parity understanding, not an active backlog slice that still needs to be discovered in `agent-todo.md`

## Official upstream source-of-truth files

Primary `version_129` sources:

- `src/passes/OnceReduction.cpp`
- `src/passes/pass.cpp`
- `src/ir/intrinsics.h`
- `src/cfg/domtree.h`
- shipped test: `test/lit/passes/once-reduction.wast`

Helpful current-main freshness surfaces:

- `src/passes/OnceReduction.cpp`
- `test/lit/passes/once-reduction.wast`

## Beginner summary

A better summary than the short registry description is:

1. scan the whole module for integer globals that behave like monotonic once-bits,
2. find no-param/no-result functions that start with the exact `if (global.get) return; global.set nonzero` guard shape,
3. iteratively learn which once-bits are definitely set on dominated control-flow paths and after certain direct calls,
4. nop later redundant direct calls and redundant writes,
5. and finally simplify a very small family of trivial once-function bodies themselves.

That is much narrower than “remove repeated calls to things that only run once.”

## Biggest durable corrections

### 1. The pass is not generic idempotent-call elimination

The pass only handles a very narrow set of direct calls:

- direct `call`, not `call_ref`
- no parameters
- no results
- either an explicit monotonic once-global guard, or an upstream idempotent function annotation that is modeled with a fake once-global name

So this is not a broad effect-analysis pass and not a generic repeated-call eliminator.

### 2. Actual Binaryen does **not** require the initial once-global value to be zero

The comments describe monotonic once-globals as starting at zero and then becoming nonzero.
But the real implementation never checks the initializer value.
The shipped lit file explicitly includes a nonzero-initializer case and still expects optimization.

A better mental model is:

- the pass cares that later writes never make the bit “not yet run” again
- not that the initializer must literally be zero

### 3. The pass reasons about **definite path facts**, not “callee bodies must have fully completed”

This is the hardest beginner correction.
A once-global is set at function entry, before the payload runs.
So from “we entered callee X” we may infer:

- X's own once-bit is now nonzero

but we may **not** always infer:

- every other once function that X might call has already fully completed

The shipped triple-loop test exists specifically to lock that distinction down.

## Scheduler placement

### Top-level no-DWARF `-O` / `-Os`

From `pass.cpp` and the repo's canonical pathway page:

- `once-reduction` runs in the early module pre-pass phase.
- It sits after `memory-packing`.
- It sits before `global-refining`.
- It is gated by `optimizeLevel >= 2`.

That placement matters because:

- `memory-packing` first cleans up data-segment layout and related module baggage,
- `once-reduction` then removes redundant run-once scaffolding,
- and later module passes see a cleaner module before GC refinement and the main function pipeline start.

### The saved audit and debug log

The saved generated-artifact audit reports slot `4` (`once-reduction`) as:

- exact wasm equal: `yes`
- normalized WAT equal: `yes`
- Starshine wall time: `421.087 ms`
- Binaryen wall time: `206.659 ms`
- Starshine pass time: `12.455 ms`
- Binaryen pass time: `13.674 ms`

The saved Binaryen debug log contains one top-level `running pass: once-reduction` line, followed by `running nested passes`.
That second phrase is easy to misread.
Here it means the module pass internally launches nested helper passes (`Scanner` and `Optimizer`), not that `once-reduction` participates in the later optimize-after-inlining rerun helper.

## Actual implementation structure in `OnceReduction.cpp`

## 1. Top-level state: `OptInfo`

The pass centralizes its shared state in `OptInfo`:

- `onceGlobals`
  - map from global name to whether the global still looks like a legal once-bit
- `onceFuncGlobals`
  - map from function name to the real or fake global name used to track that function's once-ness
- `onceGlobalsSetInFuncs`
  - current per-function summary of definitely-set once-bits
- `newOnceGlobalsSetInFuncs`
  - next-iteration version of the same summary map

Two details matter here:

- `onceGlobals` stores `std::atomic<bool>` values because the scan phase is function-parallel and mutates shared candidacy state.
- the function map stores a **global name**, not just a boolean. That lets the optimizer track one once-function via the same machinery it uses for once-globals.

## 2. Module scan phase: `Scanner`

`Scanner` is a parallel `PostWalker` over functions.
It has two jobs:

### A. reject bad once-globals

A candidate once-global survives only if all observed writes are integer constant writes with a strictly positive value.
The moment the scanner sees:

- a zero write
- a nonconstant write
- or a non-integer write that is not relevant to the pass

that global stops being a once-global candidate.

The pass also invalidates a global if it is read anywhere except for the single guard read at the top of a detected once function.

This is the most important monotonicity rule in the whole file:

- the exact nonzero value does not matter
- but reads outside the guard position do matter

### B. detect exact once-function shapes

`getOnceGlobal(...)` only recognizes an exact top-of-body pattern:

- function body is a `block`
- first item is an `if`
- the `if` condition is `global.get $g`
- true arm is exactly `return`
- false arm is absent
- second item is `global.set $g <nonzero-const>`
- function has no params and no results

That means the pass deliberately rejects nearby variants such as:

- a `nop` before the `if`
- a `nop` between the `if` and the `global.set`
- an `else` arm
- a different global in the `get` and `set`
- a non-block body root
- bodies that are too short to prove the shape

The lit file explicitly tests all of those.

## 3. Candidate-global initialization before the scan

Before `Scanner` runs, `OnceReduction::run(...)` seeds `onceGlobals` optimistically for globals that are:

- integer-typed
- and not imported

Then it immediately makes exported globals ineligible.

That means the legal starting surface is already narrower than “all globals.”
The pass assumes imported or exported globals might be observed or mutated from outside the module boundary.

## 4. Post-scan combine step

After the module scan, the pass tightens `onceFuncGlobals` again:

- if a function matched the once-function body shape,
- but its controlling global was later proven not-once,
- the function is demoted back to ordinary.

So the scanner is intentionally optimistic first and validating second.

## 5. Upstream idempotent-annotation path

The next step is easy to miss and is not covered by the local Starshine implementation today.

Binaryen checks every no-param/no-result function for the function annotation:

- `@binaryen.idempotent`

If that annotation is present, Binaryen assigns the function a **fake** once-global name using `Names::getValidGlobalName(...)` and marks that fake name as a legal once-global.

Why this is clever:

- the optimizer already knows how to track “has this once-global definitely been set?”
- an idempotent no-arg no-result function can reuse the exact same framework if it gets a synthetic once-global key

Why it is still narrow:

- params are still rejected
- results are still rejected
- fake globals only help the call-elimination analysis; later body cleanup that requires a real global cannot apply to fake-global functions

## 6. Fixed-point optimizer: `Optimizer`

The real rewrite work happens in `Optimizer`, a `CFGWalker` pass with `BlockInfo`.
Each basic block records only two kinds of relevant expressions:

- `GlobalSet`
- `Call`

That already tells us a lot about the real pass:

- it is not value-numbering everything
- it is not effect-walking arbitrary expression trees
- it only cares about writes to once-bits and direct calls that may set them

## 7. Dominator-driven local reasoning

For each function, `Optimizer`:

- builds a CFG
- builds a dominator tree
- walks blocks in reverse postorder
- inherits the known-once set from the immediate dominator only

That last bullet is one of the most important non-obvious details.
The file even leaves TODOs saying Binaryen could intersect information from all predecessors or exit blocks, but does not do that today.

So the released pass is deliberately conservative:

- if one branch dominates another block, facts flow
- if two branches merge, the pass does **not** do a general all-path intersection there
- it mostly reasons with immediate-dominator facts plus direct straight-line accumulation

That is exactly why the lit file keeps certain after-`if` calls alive even when both arms appear to call the same once function.

## 8. The `optimizeOnce(...)` action

Inside a block, both relevant expression families are normalized to the same action:

- “this instruction definitely sets once-global `G`”

If `G` was already known set on the current dominated path:

- the instruction becomes `nop`

If not:

- `G` is inserted into the current known-once set

This is how the pass removes both:

- redundant direct calls to once-functions
- redundant `global.set` writes to once-globals

Why this can use raw `nop` safely:

- the pass only optimizes direct calls to no-param/no-result functions, so there are no call operands or result values to preserve
- the pass only optimizes `global.set` when the value is a constant nonzero write, so dropping the whole node preserves the zero/nonzero semantics the pass has already proved irrelevant

## 9. Function-summary propagation across calls

When the optimizer sees a direct call to a function that is not itself a once-function, it still unions in that callee's known summary set from `onceGlobalsSetInFuncs`.
That is how straight-line call chains like:

- `A -> B -> C -> D -> once`

can eventually let `A` remove a later direct `call once`.

But the summary is intentionally conservative.

### Source-derived inference: summary facts are entry-prefix guarantees, not full-function postconditions

The implementation stores each function summary from `onceGlobalsWrittenVec[0]`, and the file comments note a TODO about intersecting exit blocks in the future.
Taken together with the lit tests, the safest reading is:

- current Binaryen propagates only the once-bits it can treat as guaranteed from the entry-side dominated walk it has today,
- not arbitrary “everything that probably happened somewhere before function return” facts.

This is an inference from the code structure plus the shipped tests, not a prose comment stated outright in one sentence.
But it explains the observed conservatism very well.

## 10. Outer fixed-point iteration

The pass reruns the optimizer until the total count of known once-globals in all function summaries stops increasing.

This is a simple but effective fixed-point heuristic:

- if more guaranteed once-bits are being learned,
- another pass through functions may open new call eliminations,
- and the call eliminations themselves may expose more guaranteed once-bits to callers

So `once-reduction` is conceptually a small whole-module dataflow pass, not just a local peephole.

## 11. Final once-body cleanup

Only after the main iterative optimization stabilizes does Binaryen mutate once-function bodies themselves.
That avoids confusing the earlier analysis with mid-pass body surgery.

The cleanup covers two tiny but important families.

### A. empty-payload once function

If the body is effectively just:

- guard `if (global.get) return`
- `global.set nonzero`

with no payload afterward, the entire function body can become `nop`.

### B. trivial once-wrapper around another once function

If the body is:

- guard
- `global.set nonzero`
- `call $other_once`

then Binaryen may drop the first two early-exit lines, leaving only the payload call.

Why this is safe:

- one layer of early-exit guard is enough if the only payload is another once-function

Why it is not always safe:

- if the wrapper does anything after that call, removing the guard would allow the rest of the body to run more than once
- if the pass removed wrapper guards on every node in a call cycle, the cycle could become an infinite loop

So the implementation tracks `removedExitLogic` and iterates functions deterministically, refusing to remove the guard when that would compose badly with an already-simplified cycle partner.
The lit file's loop, triple-loop, and self-loop families exist largely to freeze that safety story.

## Important WAT / IR shapes that the living dossier must document

Positive families:

- classic no-param/no-result once function guarded by one integer global
- repeated straight-line direct calls after a dominating first call
- repeated direct calls inside dominated loop regions
- nonzero initializer still allowing optimization
- nonzero later writes elsewhere still allowing optimization
- straight-line call-chain propagation (`A -> B -> C -> D -> once`)
- trivial empty-payload once bodies becoming `nop`
- trivial once-wrapper bodies losing redundant early-exit logic
- self-recursive once calls becoming inner `nop`
- upstream-only idempotent-annotation positives

Negative or bailout families:

- any extra read of the once-global outside the single guard read
- zero write anywhere to the once-global
- nonconstant write anywhere to the once-global
- imported mutable global
- exported mutable global
- non-integer global
- param or result carrying once-functions
- body shape variants (`nop` before the `if`, `nop` between `if` and `set`, `else` arm, different get/set globals, non-block root, too-short body)
- after-merge cases where both arms call the once-function but the pass does not do all-predecessor merge reasoning
- conditional-loop-entry cases that do not prove a post-loop call is redundant
- triple-loop/cycle cases where entering one once-function does not prove the full payloads of other once-functions have already completed
- `call_ref` / indirect-call-like shapes, which are outside this pass today

## Important non-goals and dependencies

This pass depends on:

- CFG construction
- immediate-dominator reasoning
- a whole-module fixed point over direct-call summaries
- function annotation reading for upstream idempotent support

This pass does **not** depend on:

- effect lattices like `effects.h`
- type repair / refinalization helpers
- liveness or SSA analyses
- branch-value rewrites
- general indirect-call reasoning

That dependency story is useful for future Starshine work because it tells us what kind of port this really is:

- not an effects-heavy hot pass
- not a refinalization-heavy AST mutator
- but a conservative module pass with nested function-level CFG reasoning

## Starshine comparison

The current in-tree Starshine implementation in `src/passes/once_reduction.mbt` clearly overlaps with Binaryen's explicit once-global story:

- it recognizes no-param/no-result once bodies
- it tracks integer nonzero writes and disqualifying reads
- it computes per-function definitely-set summaries to a fixed point
- it rewrites redundant calls and redundant global sets
- it performs a limited once-body cleanup pass afterward

But the local implementation is still narrower than upstream in important ways.

Direct source-visible gaps today include:

- no `@binaryen.idempotent` handling in `src/passes/once_reduction.mbt`
- no Binaryen-style CFG/dominator walker; the local implementation uses recursive AST/block traversal instead
- a much smaller local test surface than upstream `once-reduction.wast`

There is also a source-visible divergence in emphasis:

- local code explicitly handles `return_call`
- upstream `OnceReduction.cpp` only tracks direct `Call`

I did **not** validate in this thread whether that lateral divergence is currently beneficial, redundant, or a latent parity mismatch.
It should be treated as an explicit follow-up question, not a silent assumption.

## Saved artifact evidence

The saved generated-artifact `-O4z` audit is still valuable here.
Slot `4` (`once-reduction`) is green on both exact wasm and normalized WAT.
That means the local narrower implementation is already good enough for at least one real artifact slice.

But that green slot is not proof of full official-surface parity.
The official source and test surface is broader than what the local code and tests document today.

## Freshness note

A narrow 2026-04-20 direct source comparison found **no semantic post-`version_129` drift** for the official surfaces used here.

- current `main` `src/passes/OnceReduction.cpp` is identical to the `version_129` file
- current `main` `test/lit/passes/once-reduction.wast` is also identical to the `version_129` file

So the safe durable rule for this dossier is:

- treat Binaryen `version_129` as the released oracle
- mention current-main only to say there is no visible drift in the owning source and dedicated lit surface right now

## Open questions / labeled inferences

1. **Function-summary meaning.**
   - Inference: `onceGlobalsSetInFuncs` is best read as an entry-prefix or otherwise strongly conservative guaranteed-set summary, not a general “all globals definitely set by function return” summary.
   - Why: the optimizer stores `onceGlobalsWrittenVec[0]`, the code leaves TODOs about intersecting predecessors and exit blocks, and the shipped after-merge and triple-loop tests match that conservative reading.

2. **Idempotent test coverage.**
   - Direct source fact: `OnceReduction.cpp` contains an explicit idempotent-annotation path.
   - Direct source fact: the dedicated shipped `once-reduction.wast` file I audited does not isolate a visible `@binaryen.idempotent` textual fixture.
   - Consequence: the idempotent story in this dossier is source-derived and trustworthy, but its dedicated lit-coverage status should stay explicit.

3. **Local `return_call` divergence.**
   - Direct source fact: local Starshine handles `ReturnCall` in the pass, while the upstream C++ file only visits `Call`.
   - Unknown: whether this is a harmless extension, a future parity hazard, or currently dead code for the exercised artifacts.

## Sources

Local repo sources:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/once_reduction.mbt`
- `src/passes/once_reduction_test.mbt`
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/registry_test.mbt`
- `src/wast/parser.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/wast/module_wast_tests.mbt`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/o4z-wasm-opt-debug.log`

Official Binaryen sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OnceReduction.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/once-reduction.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OnceReduction.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/once-reduction.wast>
