# Binaryen `dae-optimizing` current-main implementation/test-map bridge

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/dae-optimizing/` dossier

## Scope

This file captures a focused primary-source recheck for the `dae-optimizing` dossier after the 2026-04-24 source manifest. It exists to support the newly separate implementation/test-map page and to make the current-main status explicit without duplicating the explanatory living pages.

Use these living pages for interpretation:

- `docs/wiki/binaryen/passes/dae-optimizing/index.md`
- `docs/wiki/binaryen/passes/dae-optimizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dae-optimizing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dae-optimizing/signature-updates-and-nested-reruns.md`
- `docs/wiki/binaryen/passes/dae-optimizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`

## Provenance

### Official source files rechecked

- `src/passes/DeadArgumentElimination.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadArgumentElimination.cpp>
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `src/passes/param-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/param-utils.h>
- `src/ir/return-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/return-utils.h>
- `src/ir/lubs.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/lubs.h>
- `src/ir/type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
- `src/ir/utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/utils.h>

### Official test files rechecked

- `test/lit/passes/dae-optimizing.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-optimizing.wast>
- `test/lit/passes/dae-refine-params-and-optimize.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-refine-params-and-optimize.wast>
- `test/lit/passes/dae-gc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc.wast>
- `test/lit/passes/dae-gc-refine-params.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-params.wast>
- `test/lit/passes/dae-gc-refine-return.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae-gc-refine-return.wast>
- `test/lit/passes/dae_tnh.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae_tnh.wast>

### Maintainer / upstream change context

- Binaryen PR `#8072`, `DeadArgumentElimination: Skip unprofitable single-call chains`
  - URL: <https://github.com/WebAssembly/binaryen/pull/8072>
  - Consulted as upstream context for the `unprofitableRemovalIters` stop rule that already appears in the tagged `version_129` strategy. This PR is supporting context, not a separate Starshine requirement.

## Durable observations from the recheck

- The source owner split remains stable: `DeadArgumentElimination.cpp` owns the shared boundary-rewrite engine for both public DAE siblings; `pass.cpp` owns the public `dae` / `dae-optimizing` registration split; `opt-utils.h` owns the optimizing-only `optimizeAfterInlining(...)` nested cleanup helper.
- The proof surface remains distributed. There is no single test file that proves every `dae-optimizing` behavior. The important dedicated or shared files are `dae-optimizing.wast`, `dae-refine-params-and-optimize.wast`, `dae-gc.wast`, `dae-gc-refine-params.wast`, `dae-gc-refine-return.wast`, and `dae_tnh.wast`.
- The 2026-04-25 current-main recheck did not surface a new teaching-relevant behavior drift from the `version_129` contract already taught in the dossier.
- The implementation/test-map gap was local wiki structure, not a source contradiction: the existing strategy pages had the right broad contract, but readers lacked a compact owner-file and lit-proof map for the optimizing sibling.
- The local Starshine status remains unchanged: current Starshine tracks the descriptive boundary-only spelling `dead-argument-elimination-optimizing` in `src/passes/optimize.mbt`, while `dae-optimizing` is still the upstream / audit / backlog spelling and not an exact local registry alias.

## Uncertainties and contradictions

- No upstream contradiction was found in the rechecked source set.
- Starshine naming remains an unresolved local design decision: future work may add exact upstream aliases `dae` / `dae-optimizing`, keep only descriptive names, or support both.
- Current-main source can continue to drift after this capture. Treat `version_129` as the tagged oracle for parity work until a future run deliberately changes the source baseline.
