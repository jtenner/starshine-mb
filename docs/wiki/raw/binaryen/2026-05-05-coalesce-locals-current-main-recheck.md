# Binaryen `coalesce-locals` current-main recheck

_Status:_ immutable focused source recheck and code-map refresh for the `docs/wiki/binaryen/passes/coalesce-locals/` dossier

This file captures a 2026-05-05 current-`main` recheck of the upstream `coalesce-locals` surfaces. It narrows the earlier 2026-04-25 bridge to two questions:

- did current `main` drift in any teaching-relevant way from the existing Binaryen `version_129` contract?
- did any of the exact local Starshine code anchors used by the living dossier move?

## Pages this manifest supports

- `docs/wiki/binaryen/passes/coalesce-locals/index.md`
- `docs/wiki/binaryen/passes/coalesce-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/coalesce-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/coalesce-locals/interference-and-ordering.md`
- `docs/wiki/binaryen/passes/coalesce-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/coalesce-locals/starshine-strategy.md`
- `docs/wiki/binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md`

## Primary sources rechecked

- `CoalesceLocals.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CoalesceLocals.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- helper surfaces used by the owner-file read-along
  - `liveness-traversal.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/cfg/liveness-traversal.h>
  - `numbering.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/numbering.h>
  - `utils.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/utils.h>
- dedicated lit test
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/coalesce-locals.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>

## Recheck result

The reviewed current-`main` sources still support the same teaching-level contract as the existing dossier:

- the pass still uses function-parallel, nonlinear local-slot coalescing;
- interference is still value-aware, not plain lifetime-only;
- exact-type coloring and copy-weighting still drive slot choice;
- redundant copy/dead write cleanup still belongs to the pass tail;
- the ordinary pass and the `coalesce-locals-learning` variant still remain distinct;
- the dedicated lit file still covers the same positive and negative shape families.

No teaching-relevant current-`main` drift was recorded for the reviewed upstream contract.

## Local code-map refresh

The 2026-05-05 recheck also refreshed the exact local Starshine anchors used by the living dossier:

- `src/passes/coalesce_locals.mbt:2-5`
- `src/passes/coalesce_locals.mbt:347-574`
- `src/passes/coalesce_locals.mbt:576-850`
- `src/passes/coalesce_locals.mbt:851-1031`
- `src/passes/coalesce_locals.mbt:1032-1057`
- `src/passes/coalesce_locals_test.mbt:14-155`
- `src/passes/optimize.mbt:277`
- `src/passes/pass_manager.mbt:8936`

## Source provenance

- [`../../research/0473-2026-05-05-coalesce-locals-current-main-recheck.md`](../../research/0473-2026-05-05-coalesce-locals-current-main-recheck.md)
