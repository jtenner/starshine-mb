---
kind: raw-source
status: supported
last_reviewed: 2026-04-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadArgumentElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/lubs.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/return-utils.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae_tnh.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-params.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-return.wast
related:
  - ../research/0406-2026-04-26-dead-argument-elimination-port-readiness.md
  - ../../binaryen/passes/dead-argument-elimination/index.md
---

# Binaryen `dead-argument-elimination` current-main port-readiness sources

This is a focused primary-source ingest for the 2026-04-26 Starshine wiki port-readiness bridge for plain `dead-argument-elimination` / upstream `dae`.
It supplements the earlier immutable `version_129` manifest in [`2026-04-24-dead-argument-elimination-primary-sources.md`](./2026-04-24-dead-argument-elimination-primary-sources.md) rather than replacing it.

## Checked primary sources

- Binaryen current `main` owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadArgumentElimination.cpp>
- Binaryen current `main` pass registration / scheduler file: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Shared helper surfaces used by the plain and optimizing siblings:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/lubs.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/return-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
- Plain-pass teaching lit surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae_tnh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-params.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-return.wast>

## Current-main findings

The current-main owner still teaches the same durable strategy as the 2026-04-24 `version_129` dossier:

- the public plain pass still shares `DeadArgumentElimination.cpp` with `dae-optimizing`;
- the plain pass is the direct-call boundary core without the optimizing sibling's nested post-change cleanup replay;
- the core still discovers whether function boundaries are closed enough to edit, then rewrites declarations, callsites, and bodies together;
- function exports, imports, function references, table/indirect exposure, and other unseen-call surfaces remain signature-change blockers;
- live parameters can still be retained but refined from call-operand LUB evidence;
- all-equal constant actuals can still be materialized in the callee before the incoming parameter is removed;
- dropped result removal still has to preserve uninhabited-result knowledge and tail-call compatibility;
- effectful or otherwise hard call operands can still force a localization round before a later iteration can delete the parameter;
- the single-caller unprofitable-removal throttle is still part of the implementation story, so a faithful future Starshine port should not model the pass as an unbounded chain-shrinker.

## Lit-surface findings

The current plain-pass lit files still prove the families used by this dossier:

- `dae_tnh.wast` covers traps-never-happen and unreachable-preservation cases such as removed operands that used to be `unreachable`;
- `dae-gc.wast` covers GC boundary behavior for parameter and result signatures;
- `dae-gc-refine-params.wast` covers parameter-type narrowing rather than simple deletion;
- `dae-gc-refine-return.wast` covers returned-value LUB refinement and caller repair.

The optimizing-specific files still remain sibling evidence, not the plain pass's validation oracle: they prove the extra cleanup replay that plain `dae` deliberately does not promise.

## No teaching-relevant drift found

This ingest found no teaching-relevant current-main drift from the earlier `version_129` story.
The durable delta for the wiki is Starshine-side readiness: first slice boundaries, exact local code surfaces, registry alias decisions, validation order, and the need to preserve the plain-vs-optimizing scheduler split are now filed in a dedicated bridge page.

## Uncertainties and caveats

- This was a focused source check of the owner, helper, scheduler, and representative lit surfaces, not a whole-repository semantic audit.
- GitHub current `main` is moving. Treat this file as a 2026-04-26 spot check and keep future drift notes explicit.
- Starshine has reusable `call_ref`, type-section, validator, and module-rewrite surfaces, but no current call-boundary summary engine; the implementation-readiness page therefore describes a future design ladder, not hidden local support.
