---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0120-2026-04-20-dae-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../dead-argument-elimination/implementation-structure-and-tests.md
  - ../rse/index.md
  - ../local-cse/index.md
---

# Binaryen `dae-optimizing` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The 2026-04-24 primary-source manifest is [`../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md); it records the official release page, tagged source URLs, current-`main` spot-check URLs, and dedicated lit files reviewed in the original follow-up.
- The 2026-04-25 implementation/test-map bridge is [`../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md); it rechecked current `main` and found no teaching-relevant drift while adding a compact owner-file / lit-proof map.
- The 2026-05-05 current-main recheck is [`../../../raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md); it keeps the same contract fresh and points the dossier at the new readiness bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
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

The latest source refresh did not find a teaching-relevant drift in current `main`, but it did close a local wiki gap: [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) now maps the upstream owner files and distributed lit-test proof surface. The local Starshine caveat remains unchanged: current Starshine uses the descriptive boundary-only registry spelling `dead-argument-elimination-optimizing`, not the exact upstream spelling `dae-optimizing`; see [`./starshine-strategy.md`](./starshine-strategy.md).

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

[... truncated ...]