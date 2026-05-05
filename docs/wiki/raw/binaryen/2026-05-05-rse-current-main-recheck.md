# Binaryen `rse` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/rse/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `rse` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-26-rse-cfg-source-correction.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/rse/index.md`
- `docs/wiki/binaryen/passes/rse/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/rse/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/rse/cfg-and-value-tracking.md`
- `docs/wiki/binaryen/passes/rse/wat-shapes.md`
- `docs/wiki/binaryen/passes/rse/starshine-strategy.md`
- `docs/wiki/binaryen/passes/rse/starshine-port-readiness-and-validation.md`

## Official sources rechecked

### Binaryen `main`

- `RedundantSetElimination.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RedundantSetElimination.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RedundantSetElimination.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Dedicated pass test `rse_all-features.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/rse_all-features.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/rse_all-features.wast>
- Dedicated GC/refinement test `rse-gc.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/rse-gc.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/rse-gc.wast>

### Tagged comparison anchor

- `RedundantSetElimination.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `rse_all-features.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- `rse-gc.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>

## Durable observations

- Current `main` still exposes `rse` through the same public pass name and the same dedicated lit surfaces.
- The reviewed `main` source stayed aligned with the corrected `version_129` contract on the reviewed surfaces: `CFGWalker`-based block value flow, block start/end local-value facts, same-value `local.set` / `local.tee` shell removal, strict-subtype `local.get` retargeting, and conditional refinalization.
- The current-main check did not surface any teaching-relevant contract drift from the existing `version_129` story.
- The local Starshine status remains active and direct; this bridge exists so the living dossier can point at a fresh 2026-05-05 source anchor instead of only the older 2026-04-26 capture.

## Consumability rule

If future wiki pages restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
