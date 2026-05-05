# Binaryen `global-type-optimization` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/global-type-optimization/` dossier

## Scope

This file records the 2026-05-05 current-main spot check for `global-type-optimization`.
Use it as the freshness bridge for the living dossier pages:

- `docs/wiki/binaryen/passes/global-type-optimization/index.md`
- `docs/wiki/binaryen/passes/global-type-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-type-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/global-type-optimization/field-removal-subtyping-js-interop-and-traps.md`
- `docs/wiki/binaryen/passes/global-type-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-type-optimization/starshine-strategy.md`
- `docs/wiki/binaryen/passes/global-type-optimization/starshine-port-readiness-and-validation.md`

## Provenance

### Current-main source files checked

- `GlobalTypeOptimization.cpp`
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalTypeOptimization.cpp>
- `pass.cpp`
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `gto_and_cfp_in_O.wast`
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gto_and_cfp_in_O.wast>

### Source facts observed on 2026-05-05

- `GlobalTypeOptimization.cpp` still frames the pass as private-struct mutability/layout cleanup, with the same GC + `--closed-world` gate, the same `StructScanner`/`TypeHierarchyPropagator` split, and the same instruction-before-type rewrite ordering.
- `pass.cpp` still registers the pass as `gto` and still places it in the closed-world GC/type cluster after `global-refining` and before `remove-unused-module-elements` / `remove-unused-types` / `cfp` / `gsi`.
- `gto_and_cfp_in_O.wast` still teaches the same closed-world-only scheduler interaction: `-O` plus `--closed-world` runs `gto` and then lets later cleanup and CFP exploit the removed field.

## Durable conclusion

The 2026-05-05 recheck did not surface teaching-relevant drift from the existing `version_129` story.
The living dossier can keep treating this pass as the same closed-world `gto` struct-layout optimizer, with the same upstream/local naming split and the same Starshine boundary-only status.
