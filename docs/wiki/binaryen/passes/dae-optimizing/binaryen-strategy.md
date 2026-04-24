---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0120-2026-04-20-dae-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dead-argument-elimination/implementation-structure-and-tests.md
  - ../rse/index.md
  - ../local-cse/index.md
---

# Binaryen `dae-optimizing` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The 2026-04-24 primary-source manifest is [`../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md); it records the official release page, tagged source URLs, current-`main` spot-check URLs, and dedicated lit files reviewed in the latest follow-up.
- The core implementation is `src/passes/DeadArgumentElimination.cpp`.
- CLI registration and top-level scheduler placement come from `src/passes/pass.cpp`.
- The nested optimizing helper comes from `src/passes/opt-utils.h`.
- The main helper contracts come from:
  - `src/passes/param-utils.h`
  - `src/ir/return-utils.h`
  - `src/ir/lubs.h`
  - `src/ir/type-updating.h`
  - `src/ir/utils.h`
- The shipped behavior examples come from:
  - `test/lit/passes/dae-optimizing.wast`
  - `test/lit/passes/dae-refine-params-and-optimize.wast`
  - `test/lit/passes/dae-gc.wast`
  - `test/lit/passes/dae-gc-refine-params.wast`
  - `test/lit/passes/dae-gc-refine-return.wast`
  - `test/lit/passes/dae_tnh.wast`

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast>

## The pass in one sentence

Binaryen `dae-optimizing` is a **closed-world direct-call boundary cleanup pass** that can refine function signatures, delete dead parameters and returns, localize hard call operands when needed, and then rerun useful function optimizations on the functions it changed.

The latest source refresh did not find a teaching-relevant drift in current `main`, but it did clarify one local Starshine caveat: current Starshine uses the descriptive boundary-only registry spelling `dead-argument-elimination-optimizing`, not the exact upstream spelling `dae-optimizing`; see [`./starshine-strategy.md`](./starshine-strategy.md).

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Scan | Collect direct calls, dropped calls, tail-call facts, escaped functions, and currently used incoming params | Build the boundary facts before mutating anything |
| Filter | Ignore imports, escaped functions, and functions with no direct callers | Keep ABI-visible or low-value cases out of scope |
| Refine | Narrow ref-typed params and result types when all direct evidence allows it | Make the signature more precise before deletion or cleanup |
| Constantize | Push all-equal constant actuals into the callee and mark the old param removable | Turn repeated call-boundary constants into local callee state |
| Remove params | Delete dead params from both signature and direct calls, sometimes after localizing operands | Real dead-argument elimination |
| Remove returns | Delete result values when every direct call drops them and tail-call rules allow it | Shrink both body and callsite boundary traffic |
| Optimize | Rerun `precompute-propagate` + default function cleanup on touched functions | Remove the new boundary-rewrite debris |

## Phase 1: pass shape and naming facts matter

`pass.cpp` registers both upstream public siblings:

- `dae`
- `dae-optimizing`

Starshine's neighboring local descriptive spelling `dead-argument-elimination` is documented in [`../dead-argument-elimination/index.md`](../dead-argument-elimination/index.md).

The second one is not a separate core algorithm.
It is the same DAE engine with `optimize = true`, which later enables the nested follow-up cleanup call to `OptUtils::optimizeAfterInlining(...)`.

That means a future Starshine port must model both names honestly:

- plain DAE
- optimizing DAE

## Phase 2: the core data structures explain the real job

## `DAEFunctionInfo`

Each function gets a fact record holding:

- `stale`
- `unusedParams`
- `calls`
- `droppedCalls`
- `hasTailCalls`
- `tailCallees`
- `hasUnseenCalls`

That record already tells you this is not a local peephole pass.
It is tracking:

- function-boundary liveness
- exact direct callsites
- exact dropped-call locations
- escape and ABI visibility
- tail-call structure

## Module-wide working sets

The implementation also keeps module-scoped working data such as:

- `indexes`
  - function name -> dense index
- `callers`
  - reverse call graph
- `allCalls`
  - merged direct calls grouped by callee
- `allDroppedCalls`
  - merged `drop(call)` locations
- `tailCallees`
  - module-wide tail-callee facts
- `hasUnseenCalls`
  - module-wide escape facts
- `worthOptimizing`
  - the functions whose bodies should get the nested cleanup rerun
- `callTargetsToLocalize`
  - callees whose callsites need operand localization before param removal can succeed
- `unprofitableRemovalIters`
  - a heuristic counter that stops low-payoff one-caller-chain crawling

## Phase 3: `DAEScanner` collects boundary facts

`DAEScanner` is the cheap parallel gatherer.

It does several important jobs.

### Direct-call collection

`visitCall(...)` groups direct callsites by callee name.

Those are the easy, rewritable boundaries.

### Tail-call collection

If a direct call is a `return_call`, the scanner records the callee in `tailCallees`.

`visitCallIndirect(...)` and `visitCallRef(...)` still matter because they can set tail-call-related conservatism, but they do not give DAE the same direct easy-to-rewrite boundary.

### Dropped-call collection

`visitDrop(...)` recognizes `drop(call ...)` and stores the exact location of the call expression.

This is what later allows DAE to remove function return values safely and repair the callers in place.

### Escape / unseen-call collection

`visitRefFunc(...)` marks the referenced function as having unseen calls.

Exports are also folded into the unseen-call story later.

This is one of the most important safety rules in the whole pass:

- if a function boundary escapes through `ref.func` or export visibility,
- DAE refuses signature-changing rewrites there.

### Used incoming params

When a function is stale, `doWalkFunction(...)` recomputes used params with `ParamUtils::getUsedParams(...)`.

The complement becomes the current candidate set of removable params.

## Phase 4: Binaryen only optimizes closed and worthwhile boundaries

After merging the scanner output, DAE skips several families immediately.

## Imports are out

Imported functions are not rewritten.

That is both:

- an ABI rule
- and a practical call-boundary rule

## Escaped or externally visible functions are out

If a function has unseen calls, it is skipped.

That includes at least:

- exported functions
- functions referenced by `ref.func`

The clean beginner summary is:

- DAE only changes signatures when Binaryen still owns the whole direct-call surface.

## Functions with no direct callers are out

This is easy to misunderstand.
The pass explicitly treats functions with no direct callers as not worth optimizing here.

So DAE is not trying to speculate on dead or isolated code.
Other passes are expected to clean that territory up.

## Phase 5: parameter type refinement is real DAE work

A lot of people hear the name and imagine only deletion.
That is incomplete.

## `refineArgumentTypes(...)`

This phase is:

- GC-gated
- reference-type-only
- caller-evidence-based

For each still-used ref-typed param, DAE:

1. gathers the operand types supplied by all direct callers
2. finds a least upper bound with `LUBFinder`
3. checks whether that type is more specific than the current param type
4. if so, applies it with `TypeUpdating::updateParamTypes(...)`

This is not just signature bookkeeping.
The body may contain:

- `local.get`
- `local.set`
- `local.tee`

that need repair once the incoming param type narrows.
That is why `type-updating.h` is a core dependency.

## Unused params are deliberately not refined first

The source comments explain that unused params are skipped during refinement.

The idea is practical:

- such params may later turn into locals or defaulted values when constants are applied or params are removed
- refining them too early complicates that later rewrite path

So the pass chooses a stable order instead of maximum eagerness.

## Phase 6: return type refinement is also part of DAE

`refineReturnTypes(...)` uses `LUB::getResultsLUB(...)` to narrow a function’s result type when the actual returned values prove a tighter type.

If that happens, Binaryen updates:

- the function signature
- direct call expression types
- and then later runs `ReFinalize` so surrounding expressions keep correct types too

This matters most for GC-heavy pipelines because more precise results can unlock later cast cleanup and subtype-aware simplifications.

## The pass does not promise a perfect recursive fixed point

The source comments explicitly say return refinement can miss more global optima in recursive or mutually recursive flows.

So the honest summary is:

- useful refinement, not a full interprocedural theorem prover

## Phase 7: constant actuals can become callee locals

`ParamUtils::applyConstantValues(...)` is another big part of the algorithm.

If every direct call passes the same constant actual in a given slot, Binaryen can:

- materialize that constant inside the callee body
- mark the old incoming parameter unused
- later remove that parameter entirely

The modern-important part is that the constant does not need to be only an integer literal.
The GC tests cover constant families such as:

- `ref.null`
- `ref.i31`
- `ref.func`
- `string.const`

So DAE is also doing a small interprocedural constant-boundary cleanup pass.

## Phase 8: removing params can require call localization first

This is one of the easiest parts to miss.

`ParamUtils::removeParameters(...)` does not always succeed immediately.
If deleting a call operand in place would disturb evaluation order or interact badly with nested effects, the helper can fail.

When that happens, DAE records the callee in `callTargetsToLocalize` and later calls:

- `ParamUtils::localizeCallsTo(...)`

That helper rewrites the hard callsites into a safer local-temporary shape first.
Then DAE iterates again and retries parameter removal.

So the real model is often:

- discover removable params
- fail to remove them safely today
- localize the hard operand trees
- remove them on the next pass iteration

## Phase 9: dropped-return elimination is a second major family

The pass also removes function return values in some cases.

If a function:

- has a non-`none` result
- and every observed direct call is wrapped in `drop`
- and tail-call facts do not make the rewrite unsafe

then DAE can:

- change the function result to `none`
- rewrite every `drop(call ...)` into just `call ...`
- use `ReturnUtils::removeReturns(...)` to rewrite the body

## Uninhabitable old results need `call; unreachable`

A very important correctness detail is the special repair for uninhabitable result types.

If the old call expression told the caller that normal execution could not continue, Binaryen must preserve that fact.
So it rewrites such a caller site conceptually as:

- `call ...`
- `unreachable`

rather than only deleting the surrounding `drop`.

That is why `dae-optimizing` is more than a signature editor: it is preserving typing and control-flow meaning while it rewrites the boundary.

## Phase 10: tail-call conservatism matters

Dropped-return elimination is more conservative than ordinary return-type refinement.

The pass tracks:

- `hasTailCalls`
- `tailCallees`

and uses those facts to avoid unsafe or overly tricky result-removal situations.

So “all direct callers drop the result” is necessary but not always sufficient.

## Phase 11: the optimizing helper is part of the pass contract

When the optimizing variant is active and Binaryen made useful changes, it calls:

- `OptUtils::optimizeAfterInlining(worthOptimizing, getPassOptions(), getModule(), 0)`

That helper:

1. filters to the touched functions only
2. prepends `precompute-propagate`
3. reruns the default function optimization pipeline

This is what cleans up many of the new byproducts DAE creates, such as:

- localized call operands
- new local traffic from constant actual materialization
- redundant casts after param or result refinement
- dead code after result deletion

A Starshine port that stops after boundary edits will not match Binaryen behavior honestly.

## Phase 12: Binaryen deliberately stops some low-payoff iteration chains

The `unprofitableRemovalIters` heuristic is an important performance / scheduler detail.

If DAE sees a pattern like:

- only one function had params removed this iteration
- that function has exactly one caller
- nothing else useful is happening

then it stops pushing deeper down that single-caller chain in the same invocation.

The intuition is:

- let inlining or a later DAE run handle the next link more profitably
- do not spend this pass crawling one boundary at a time forever

## Top-level scheduler placement is part of the real story

## Ordinary no-DWARF slot

The top-level post-pass order puts `dae-optimizing` first in the late boundary cluster.
That means later boundary and module passes see the already-cleaned function signatures and bodies.

## Saved `-O4z` nested evidence

The saved generated-artifact debug log is a useful reality check:

- DAE is one top-level slot
- but it triggers many nested function-cleanup replays underneath

Repo-local counting over the saved DAE section shows that the nested pipeline replay is not theoretical documentation drift. It is happening repeatedly in the real artifact trace.

## What this pass does **not** do

Binaryen `version_129` `dae-optimizing` is not:

- an arbitrary indirect-call signature optimizer
- an import-boundary optimizer
- a full recursive fixed-point interprocedural analyzer
- a pure function-local local-cleanup pass
- only “remove unused arguments”
- safe to model as one top-level slot with no nested follow-up work

## A good porting checklist

A future Starshine port should preserve all of the following:

- module / boundary scope instead of function-local scope
- direct-call-only signature rewrites
- export / `ref.func` / unseen-call escape conservatism
- import exclusion
- functions-with-no-direct-callers exclusion
- GC ref-typed param LUB refinement
- result-type LUB refinement
- constant actual materialization into callee locals
- param-removal retry via call localization
- dropped-return elimination with tail-call conservatism
- `call; unreachable` repair for uninhabitable old results
- touched-function tracking for later cleanup
- `precompute-propagate` + default function pipeline rerun in the optimizing variant
- the low-payoff one-caller-chain stop heuristic
- an explicit local naming decision for the upstream `dae-optimizing` spelling versus the current Starshine `dead-argument-elimination-optimizing` boundary-only entry

## Bottom line

The cleanest beginner-friendly summary is:

- `dae-optimizing` is a **boundary rewrite plus targeted cleanup replay** pass
- its real complexity is not only in call-graph discovery, but also in preserving types, evaluation order, ABI boundaries, and later pipeline expectations
- if a future Starshine port preserves those boundary rules and nested reruns, it will match what Binaryen actually does, not just what the pass name sounds like
