---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
  - ../../../raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining/index.md
  - ../dae-optimizing/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `inlining-optimizing` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/Inlining.cpp`.
- Public registration and the plain-vs-optimizing split come from `src/passes/pass.cpp` and `src/passes/opt-utils.h`.
- The dedicated file/test map is [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md); use it for owner, helper, official lit-test, and current-main no-drift provenance.
- Heuristic defaults come from `src/pass.h`.
- Explicit no-inline policy comes from `src/passes/NoInline.cpp`.
- Clone-surviving no-inline behavior comes from `src/ir/module-utils.cpp`.
- The shipped behavior examples come from the `inlining*`, `no-inline*`, and `inline-main` lit files.
- Narrow freshness note: the 2026-04-25 current-`main` implementation/test-map bridge recorded in [`../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md) did not surface a teaching-relevant contract drift on the owner / registration / option / test surfaces. Treat `version_129` as the stable oracle unless a later source ingest says otherwise.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/NoInline.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_optimize-level=3.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_enable-tail-call.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting_basics.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-instructions.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-calls-1.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-unreachable.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>

## The pass in one sentence

Binaryen `inlining-optimizing` is the late whole-module inliner that chooses profitable direct callsites, optionally splits one of two narrow top-of-function `if` families first, copies callee bodies into callers with real control/local/type repair, removes now-dead private helpers, and then immediately reruns `precompute-propagate` plus the default function optimization pipeline on touched functions.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Scan | Build `FunctionInfo` summaries for every function | Inline profitability depends on whole-module facts, not only one call node |
| Classify | Decide `Full`, split pattern, or `Uninlineable` per function | Later planning should not recompute structural eligibility from scratch |
| Discover actions | Walk functions and collect reachable direct-call inline opportunities | Discovery is local to each caller but still uses module-wide callee facts |
| Choose actions | Filter sequentially for determinism and interaction safety | Avoid inline-into-and-inline-from races and giant-function blowups |
| Rewrite | Copy callee bodies into callers and repair locals, returns, labels, and types | Inline rewrites are structured IR surgery, not text substitution |
| Clean up | Remove now-dead callees and temporary split helpers | Inlining changes module topology |
| Optimize-after-inline | Rerun `precompute-propagate` plus the default function pipeline on touched functions | The optimizing variant is designed to cash in on fresh simplifications immediately |

## Pass family and scheduler placement

`pass.cpp` exposes two related pass names:

- `inlining`
- `inlining-optimizing`

The core implementation is one pass class parameterized by an `optimize` flag.
That split matters:

| Variant | Core inline rewrite | Post-inline filtered cleanup |
| --- | --- | --- |
| `inlining` | yes | no |
| `inlining-optimizing` | yes | yes |

So the optimizing variant is not a cosmetic alias.
It is the same shared inliner plus one real nested helper contract.

In the canonical no-DWARF `-O` / `-Os` path documented in this repo, the pass appears:

- after `dae-optimizing`
- before `duplicate-function-elimination`
- before `duplicate-import-elimination`
- before `simplify-globals-optimizing`

A future Starshine port must preserve that placement because the pass changes the function graph and the nested rerun creates fresh opportunities that later late-boundary cleanup passes assume.

## Phase 1: `FunctionInfoScanner` is the first real algorithm

Before rewriting anything, Binaryen scans each function into a `FunctionInfo` summary.
Important recorded facts include:

- `refs`
- `size`
- `hasCalls`
- `hasLoops`
- `hasTryDelegate`
- `usedGlobally`
- `trivialInstruction`
- `inliningMode`

Beginner takeaway:

- a callsite is not planned in isolation
- it is planned using facts about the callee and its whole-module environment

### What counts as a root

By the end of preparation, exports and the start function count as global roots.
That means a function can inline into some internal callers and still survive because unseen callers may still exist.

### What `refs` really means

In reviewed `version_129`, the scanner increments `refs` for:

- direct calls to the function
- `ref.func` uses of the function

So `refs` is not just “number of direct callers.”
It is closer to:

- “how many direct or explicit function-reference uses still keep this function relevant?”

That is one of the main reasons “inline” and “delete callee” are related but not identical outcomes.

## Phase 2: `worthFullInlining(...)` is layered, not one threshold

The full-inline heuristic proceeds in a deliberate order.

### `try_delegate` blocks full inlining

`hasTryDelegate` immediately returns false in `version_129`.
This is a real pass boundary, not an accidental omission.

### Very small helpers inline immediately

If `size <= alwaysInlineMaxSize`, the function is full-inlineable.
`pass.h` sets the default `alwaysInlineMaxSize` to `2`.

### One-use helpers get special treatment

If:

- `refs == 1`
- `!usedGlobally`
- `size <= oneCallerInlineMaxSize`

then the function is full-inlineable.
By default `oneCallerInlineMaxSize = -1`, which effectively means Binaryen is willing to inline all such one-caller functions.

### Trivial shrinking wrappers always inline

If `trivialInstruction == Shrinks`, the function is full-inlineable even in shrink modes.

### Very large functions stop early

If `size > flexibleInlineMaxSize`, the pass returns false.
The default `flexibleInlineMaxSize` is `20`.

### Multi-use flexible cases depend on policy

Once Binaryen gets past the early always-inline cases, it becomes more conservative:

- any shrink-focused mode stops here
- optimize levels below `3` also stop here

### `MayNotShrink` trivial instructions inline only at heavy speed focus

Single-instruction wrappers whose callsite size may grow still inline under `-O3`-style settings.

### Remaining flexible cases must avoid calls and usually loops

The final case requires:

- no calls in the callee body
- and either no loops or `allowFunctionsWithLoops`

The default in `pass.h` leaves `allowFunctionsWithLoops = false`.

## Phase 3: actual action discovery is direct-call based in reviewed `version_129`

This is the biggest correction this follow-up keeps explicit.
In reviewed `version_129`, `Planner::visitCall(...)` adds chosen inline actions from reachable direct `call` / `return_call` sites.

The safe summary is:

- chosen inline actions are discovered from direct callsites
- `call_ref`, `call_indirect`, `return_call_ref`, and `return_call_indirect` still matter in copied-body repair and surrounding helper logic
- `ref.func` still matters for keeping the callee boundary alive
- but the main chosen-action planner contract in this release is not “general precise ref-call inlining”

That distinction matters for both teaching and port scope.

## Phase 4: `doCodeInlining(...)` is real IR surgery

Once a callsite is chosen, Binaryen does much more than “replace call with body.”

### It creates a fresh named wrapper block

The wrapper block gets a name derived from the callee and optional numeric hint.
Binaryen then checks for collisions against branch targets inside the copied code and call operands.

### It remaps all callee locals onto new caller locals

For every local in the callee, the updater allocates a new local in the caller and records a mapping.
The copied callee body then sees param values through those new locals.

### It zeroes zeroable vars

Binaryen explicitly zeroes copied callee vars when their types have a zero value.
This matters because the inlined block may sit inside a loop, and repeated execution must still see the same initial-local semantics the original callee had.

Nonzeroable locals are skipped, because they cannot validly be read before a write anyway.

### Returns become breaks

The updater rewrites:

- `return value` -> `br returnLabel value`
- `return` -> `br returnLabel`

so copied callee returns exit only the inlined body rather than the whole caller function.

### Nested `return_call*` repair is still subtle

If the outer callsite was not already a return call, then nested `return_call`, `return_call_indirect`, or `return_call_ref` inside the copied body cannot keep returning from the whole caller.
Binaryen handles that by converting them into ordinary calls, collecting follow-up branch information, and wrapping the copied body so the repaired control still exits correctly.

### Unreachable callees must stay unreachable

Inlining can accidentally make an originally unreachable callsite look reachable if the copied body wraps an unreachable child in typed structure.
Binaryen compensates when the original call was unreachable and not a return call by forcing the replacement to end in explicit `unreachable` structure.

## Phase 5: partial inlining is narrow and opt-in

`FunctionSplitter` exists only when:

- `optimizeLevel >= 3`
- `shrinkLevel == 0`
- `partialInliningIfs > 0`

The default in `pass.h` leaves `partialInliningIfs = 0`.
So partial inlining is off by default and only exists in heavier speed-oriented configurations.

Binaryen supports two narrow top-of-function pattern families:

- Pattern A: `if (simple) return;` then heavier later work
- Pattern B: a short run of simple top-level `if`s with no else arms and tight final-item/local-dependency rules

This is a structured split strategy, not arbitrary CFG extraction.

## Phase 6: iteration policy is conservative and deterministic

The pass runs iterative waves, but several limits keep it bounded.

### Bounded outer loop

Binaryen stops after more than the original function count in iterations.

### Per-name repeat cap

It also tracks per-function-name repeated operations and stops when any such name reaches `5` repeated iterations of work.

### Parallel discovery, sequential choice

Discovery of opportunities is parallel.
Choice of which actions to actually perform is sequential and deterministic over a saved function-name order.

### No inline-into and inline-from races in one iteration

If a function has been inlined into, Binaryen will not also inline that same function elsewhere in the same iteration.

### Giant-function protection

Chosen actions must satisfy `isUnderSizeLimit(...)`, which uses `maxCombinedBinarySize`.

## Phase 7: `optimizeAfterInlining(...)` is the real contract behind `optimizing`

`opt-utils.h` makes the post-inline helper explicit.
`OptUtils::optimizeAfterInlining(...)`:

1. optionally validates before the nested run in pass-debug mode
2. creates a `FilteredPassRunner` for only the touched functions
3. marks the runner nested
4. prepends `precompute-propagate`
5. reruns the default function optimization pipeline
6. optionally validates afterward in pass-debug mode

That means the optimizing variant is designed to immediately cash in on fresh opportunities created by inlining, including:

- constant propagation
- dead local cleanup
- dead branch cleanup
- redundant casts
- code folding and block merging
- redundant-set cleanup

The later cleanup is not optional polish.
It is part of the intended public behavior.

## Saved `-O4z` log evidence

The saved local `-O4z` debug log shows that the top-level `inlining-optimizing` line expands into several nested reruns before Binaryen moves on to top-level `duplicate-function-elimination`.
Repo-local counting over that interval finds:

- `5` nested `ssa-nomerge`
- `5` nested `code-folding`
- `10` nested `local-cse`
- `10` nested `merge-blocks`
- `15` nested `precompute-propagate`

Those numbers are a useful reminder that the pass is not “replace call, then stop.”

## Practical porting rules for Starshine

A future Starshine port must preserve at least these source-backed rules:

- model `inlining-optimizing` as a module pass with function summaries, not a function-local peephole
- start from the reviewed direct-call chosen-action planner surface
- keep roots, `ref.func` uses, and surviving observable uses honest
- preserve the layered trivial/one-caller/flexible heuristic structure
- preserve `try_delegate`, tail-call, and recursive-growth conservatism
- preserve the exact split between plain and optimizing variants
- repair returns, labels, nondefaultable locals, and reachability after every inline
- keep split inlining limited to the two source-backed top-of-function `if` families
- preserve the filtered nested rerun of `precompute-propagate` plus the default function optimization pipeline

## What beginners most often get wrong

- The pass is not just “plain `inlining`, but more aggressive.” The nested rerun is part of the public contract.
- The reviewed `version_129` planner surface is still direct-call based.
- Partial inlining is not arbitrary CFG extraction.
- Inlining a callee does not automatically delete the callee declaration.
- The late-tail scheduler neighborhood matters because `duplicate-function-elimination` and the rest of the cleanup tail consume the rewritten function graph immediately afterward.
