# Binaryen `alignment-lowering` primary-source capture

_Capture date:_ 2026-04-23  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/alignment-lowering/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-23 `alignment-lowering` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/alignment-lowering/index.md`
- `docs/wiki/binaryen/passes/alignment-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/alignment-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/alignment-lowering/chunk-selection-and-unreachable-semantics.md`
- `docs/wiki/binaryen/passes/alignment-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/alignment-lowering/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dealign/index.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-23.
  - GitHub showed the publish date as **2026-04-01**.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-23.
  - Used to confirm that `version_129` was still present on the official reviewed release surface for this dossier during this run.

### Official source files consulted

- `AlignmentLowering.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AlignmentLowering.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- `bits.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/bits.h>

### Official test files consulted

- `alignment-lowering.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/alignment-lowering.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/alignment-lowering.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-23, with the tagged release page and releases index both showing the release on **2026-04-01**.
- The reviewed upstream implementation still matched the existing living dossier's main teaching claims: public registration as `alignment-lowering`, a tiny standalone `createAlignmentLoweringPass()` entrypoint, default non-function-parallel walker behavior, explicit `Bits::makeSignExt(...)` signed-load repair, and a narrow `Load` / `Store`-only chunk-lowering contract centered in `AlignmentLowering.cpp`.
- The reviewed dedicated test still exposed the same main positive and negative families already taught in the living pages: natural-alignment no-ops, `align=1` and `align=2` integer chunking, signed `load16_s` repair, float reinterpret staging, 64-bit split/rebuild families, offset preservation, and operand-preserving unreachable cases.
- A narrow 2026-04-23 current-`main` spot check on `AlignmentLowering.cpp`, `pass.cpp`, `passes.h`, `pass.h`, `bits.h`, and `alignment-lowering.wast` did not surface a new teaching-relevant contract drift beyond the dossier's existing Binaryen claims.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
