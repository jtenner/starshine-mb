# Binaryen `global-effects` / `generate-global-effects` research

Date: 2026-04-21

## Scope

This note widens the Binaryen pass wiki campaign to cover the upstream pass that Binaryen publishes as `generate-global-effects` and that the local Starshine registry currently shortens to `global-effects`.

Why this pass is eligible now:

- the original no-DWARF / saved `-O4z` queue is already dossier-covered
- the first tracker-expansion wave is also dossier-covered
- `src/passes/optimize.mbt` still names `global-effects` as a boundary-only pass
- nearby living docs for `simplify-locals` and `vacuum` already depend on the effect summaries this pass generates
- the tracker currently has no dedicated dossier for this pass family, even though it is already part of the local registry and already matters to later-pass teaching

So this is an explicit tracker expansion, not a claim that `generate-global-effects` belongs to the current canonical no-DWARF `-O` / `-Os` default path.

## Candidate selection result

Chosen pass: `global-effects` / upstream `generate-global-effects`

Why this is a fair expansion target:

- it is already a named local boundary-only registry entry
- it has an official Binaryen `version_129` implementation and public pass registration
- official tests and neighboring dossiers show that later passes can behave differently after it runs
- it fills a real documentation gap: today the wiki repeatedly mentions generated global-effect summaries, but it does not have one canonical page that explains where those summaries come from, what exactly they contain, and what a future Starshine port must preserve

## Backlog slice check

`agent-todo.md` has **no dedicated `global-effects` or `generate-global-effects` slice**.

That absence is itself worth recording, because the pass is already operationally important in nearby docs:

- the `simplify-locals` dossier explains that `--generate-global-effects` can distinguish calls that only read globals from calls that write them
- the `vacuum` dossier explains that generated global-effect summaries can make later unused-call cleanup stronger
- the local registry already treats `global-effects` as a tracked future pass surface

So the repo already relies on the concept, but it did not yet have a dedicated landing page or implementation note.

## Sources reviewed

### Local repo sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/simplify-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/vacuum/effect-pruning-and-traps-never-happen.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

### Official Binaryen `version_129` sources

- `src/passes/GlobalEffects.cpp`
- `src/passes/pass.cpp`
- `src/ir/effects.h`
- `src/wasm.h`
- `test/lit/passes/vacuum-global-effects.wast`

### Inference boundary

I also relied on already-reviewed local living docs that mention `global-effects_simplify-locals.wast`, but in this thread I directly reopened only the sources listed above.
Where I make an inference from those neighboring reviewed docs rather than from a freshly reopened upstream file, I call that out explicitly.

## Main findings

## 1. Upstream Binaryen's public name is `generate-global-effects`, while the local registry uses `global-effects`

`src/passes/pass.cpp` registers two relevant public pass names:

- `generate-global-effects`
- `discard-global-effects`

The local Starshine registry currently tracks the producer side under the shorter boundary-only name `global-effects`.

That means a future Starshine port will need to keep two naming facts straight:

- **local registry name:** `global-effects`
- **official upstream public CLI name:** `generate-global-effects`

This is the same kind of name-surface split the campaign already had to document for other passes such as `simplify-locals-notee` vs the local alias `simplify-locals-no-tee`.

## 2. Scheduler placement is unusual and deserves explicit documentation

`pass.cpp` contains an important TODO-style note right next to registration:

- `generate-global-effects` exists as a public pass
- Binaryen does **not** put it in the default optimization sequence
- the code comment says that if it ever becomes useful enough, Binaryen can run it automatically

So the right teaching summary is:

- this is a real upstream pass
- it is **not** part of the current no-DWARF default `-O` / `-Os` top-level pathway
- users or special pipelines must ask for it explicitly

That makes it a good fit for the tracker's expanded upstream-only registry table rather than the main parity queue.

## 3. The pass is metadata-producing, not IR-rewriting

The most important beginner-facing fact is easy to miss from the name alone:

`generate-global-effects` does **not** rewrite WAT shapes directly.

Instead, it computes and stores per-function effect summaries in `Function.effects`.

The reviewed `wasm.h` source shows that a `Function` carries an optional `std::unique_ptr<EffectAnalyzer>` field named `effects`.
So the pass updates module metadata, not expression trees.

That means the pass is best thought of as:

- **an effect-summary producer for later passes**
- not as a direct optimization pass that shrinks code on its own

This is why it can be simultaneously important and visually easy to overlook.

## 4. The first phase is a shallow per-function scan

`GlobalEffects.cpp` starts by computing a shallow effect summary for each function in parallel.

The implementation uses `ModuleUtils::ParallelFunctionAnalysis<EffectAnalyzer>` with `ShallowEffectAnalyzer(func, module)`.

That shallow summary intentionally ignores transitive callee information at first.
It only records what the function body itself obviously does, including:

- direct global reads
- direct global writes
- call edges to other functions
- and the rest of the ordinary `EffectAnalyzer` facts

The source asserts that this shallow phase has no branch or local effects, which makes sense because this pass only wants the interprocedural global/call surface.

A useful mental model is:

1. summarize each function body locally
2. then propagate callee facts through the call graph until the summaries stop changing

## 5. The second phase is a reverse-call-graph fixed point

After the shallow scan, the pass builds a reverse call graph:

- for every function, collect the functions it calls
- also collect which callers depend on that callee's summary

Then it seeds a deferred work queue with defined functions and repeatedly:

- pops one function
- recomputes its full summary from its shallow summary plus the current summaries of called functions
- if the summary changed, requeues its callers

This is the real heart of the pass.

So `generate-global-effects` is not doing a one-shot tree walk.
It is doing a classic monotone fixed-point propagation over the call graph.

That matters because it explains why the pass helps later consumers understand:

- direct callees
- transitive callees through wrappers
- recursive strongly connected components after enough rounds

## 6. Imported and defined functions play different roles

The queue is seeded with defined functions, not arbitrary imports.

The source still stores shallow summaries for all functions, but the iterative propagation work focuses on functions whose bodies Binaryen can inspect and update.

A practical reading is:

- imported functions are effect-summary leaves from the pass's point of view
- defined functions are the nodes whose summaries can be refined by chasing call edges

That is an inference from the reviewed algorithm structure rather than an explicit comment in the source, but it matches the fixed-point setup exactly.

## 7. The pass is global-specific because later `EffectAnalyzer` queries on calls can consult the stored summaries

The reviewed `effects.h` source shows why this pass matters.

When `EffectAnalyzer` visits a `Call`, it can look at the target function and, if that function has a stored `effects` summary, incorporate the target's global read/write behavior into the call's own effect model.

That is the precise handoff contract.

So the pass's value is not abstract or magical.
It gives later passes more precise answers to questions like:

- does this call write global `$g`?
- does it only read `$g`?
- does it leave unrelated globals untouched?
- is a moved expression still safe across this call?
- is a dropped call result actually removable if unused?

Without generated summaries, later passes must be more conservative.

## 8. The pass is intentionally narrower than a full whole-program side-effect system

Even though the algorithm is interprocedural, the reviewed source remains narrow in scope.

It is specifically about improving **global** effect precision across calls.

The pass does not attempt to become:

- a full heap alias analysis
- a general value-range pass
- a direct code-motion pass
- a generic purity prover for every operation kind

That narrowness matters for porting.
A future Starshine version should preserve the same practical contract:

- summarize enough to improve global read/write precision across calls
- do not accidentally oversell it as a whole-program optimizer or a replacement for the full `EffectAnalyzer`

## 9. The most important positive shapes are metadata-only, not WAT-changing

Because the pass itself does not rewrite IR, its “positive shapes” are really cases where later passes gain precision.

The most important ones are:

### 9a. Direct read-only callee

If function `$reader` only reads a global and function `$caller` invokes `$reader`, then after `generate-global-effects`, later passes can treat `call $reader` more like a read barrier than a write barrier for that specific global set.

### 9b. Direct writer callee

If function `$writer` writes global `$g`, then the summary preserves that write and later passes must still treat the call as a write barrier.

This is just as important as the positive case, because the pass is about **precision**, not about inventing optimism.

### 9c. Wrapper / trampoline call chains

If `$outer` calls `$middle` which calls `$reader`, the fixed point can eventually teach `$outer` about `$reader`'s global behavior.

That is one of the main practical wins over shallow-only analysis.

### 9d. Recursive SCC stabilization

Mutually recursive functions may need multiple queue rounds before the summaries stabilize.

The existence of the deferred fixed-point queue is direct source evidence that Binaryen expects and supports this shape.

## 10. Important bailout or conservative shapes

The pass remains conservative in several situations a beginner could otherwise misread.

### 10a. No direct default scheduling

Even Binaryen does not currently trust this enough or value it enough to run it in the default optimize path.
That does **not** mean the pass is unimportant, but it does mean the expected default-pipeline impact is limited unless explicitly scheduled.

### 10b. Missing stored summaries

`effects.h` only uses a target function's stored summary if one is present.
Without generated summaries, calls fall back to more conservative assumptions.

### 10c. Imported or opaque behavior

The pass cannot inspect arbitrary external bodies the way it can inspect defined local functions.
That naturally limits how precise the metadata can become around imports and other opaque boundaries.

### 10d. Metadata invalidation after later IR rewrites

Because the pass writes metadata rather than rewiring code directly, later transforming passes must either preserve, invalidate, or recompute those summaries honestly.

The existence of the sibling public pass `discard-global-effects` is strong source-backed evidence that upstream Binaryen treats this metadata as explicit pass-managed state rather than as an always-valid ambient fact.

## 11. Nearby-pass interactions are the main reason this dossier matters

This pass becomes much easier to teach once the wiki says plainly which nearby passes benefit from it.

### `simplify-locals`

The neighboring dossier already documents that generated global-effect summaries can let `simplify-locals` move values across calls that are only readers, while still blocking unsafe motion across writers.

That is not a fresh primary-source claim from this thread's own reopened files, but it is a clearly signposted inference from:

- the reviewed `EffectAnalyzer` handoff in `effects.h`
- the neighboring living simplify-locals docs that cite `global-effects_simplify-locals.wast`

### `vacuum`

The reviewed `vacuum-global-effects.wast` file and existing `vacuum` dossier together show the other key consumer story:

- once a call is known effect-free enough, later dead-result cleanup can erase it when unused

So this pass can make later cleanup stronger even though it never rewrites the original WAT directly.

## 12. Biggest beginner misunderstandings to prevent

### Misunderstanding: “This pass optimizes code by rewriting instructions.”

Correction:

- it primarily writes per-function effect metadata in `Function.effects`
- later passes use that metadata to optimize more safely and more aggressively

### Misunderstanding: “It is part of the normal Binaryen default optimize pipeline.”

Correction:

- the reviewed `pass.cpp` registration comment explicitly says it is not part of the current default sequence

### Misunderstanding: “Global effects” means a generic whole-program purity proof.

Correction:

- the pass specifically improves global read/write precision across calls
- it is not a general-purpose optimizer or alias-analysis framework

### Misunderstanding: “If a callee is transitive, this pass cannot see it.”

Correction:

- the reverse-call-graph fixed point exists exactly so transitive and recursive relationships can be incorporated

### Misunderstanding: “Because it does not change WAT, it is not an important porting target.”

Correction:

- later pass behavior can diverge materially if this metadata is missing or wrong
- metadata-only passes still change optimization opportunities and safety decisions downstream

## 13. What a future Starshine port must preserve

A faithful port should preserve these contracts:

- the **name split** between local `global-effects` tracking and upstream `generate-global-effects`
- the fact that the pass is **explicitly scheduled**, not silently part of the normal no-DWARF default path
- the **two-phase algorithm**:
  - shallow per-function summaries first
  - then reverse-call-graph fixed-point propagation
- the fact that summaries are stored on the function object as **metadata**, not as rewritten WAT
- the **consumer contract** that later `EffectAnalyzer` queries on `Call` may incorporate stored callee summaries
- conservative behavior around opaque/imported boundaries and stale metadata invalidation

## 14. Recommended living-page split

The living dossier should teach this pass in four layers:

1. landing page
   - role, naming split, scheduler placement, and why the pass matters
2. Binaryen strategy page
   - shallow scan, reverse-call-graph fixed point, metadata storage, and consumer handoff
3. implementation/test map
   - `GlobalEffects.cpp`, `pass.cpp`, `effects.h`, `wasm.h`, and `vacuum-global-effects.wast`
4. WAT-shapes page
   - metadata-only positive and negative call/global shapes for beginners

## Sources

### Local repo

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/simplify-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/vacuum/effect-pruning-and-traps-never-happen.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

### Official Binaryen `version_129`

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast>
