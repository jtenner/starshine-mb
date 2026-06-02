# Binaryen `reorder-globals` current-main recheck

_Capture date:_ 2026-06-01  
_Status:_ immutable source manifest for the freshness refresh that keeps the `docs/wiki/binaryen/passes/reorder-globals/` dossier aligned with the current release horizon.

## Scope

This file captures the primary online sources consulted while refreshing the `reorder-globals` dossier against the current `main` branch and the `version_130` release horizon.

Use the living pages for interpretation:

- `docs/wiki/binaryen/passes/reorder-globals/index.md`
- `docs/wiki/binaryen/passes/reorder-globals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-globals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-globals/size-model-and-dependency-order.md`
- `docs/wiki/binaryen/passes/reorder-globals/wat-shapes.md`
- `docs/wiki/binaryen/passes/reorder-globals/starshine-strategy.md`
- `docs/wiki/binaryen/passes/reorder-globals-always/index.md`

## Provenance

### Official Binaryen release and source surfaces

- Binaryen release `version_130`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
- `src/passes/ReorderGlobals.cpp`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/ReorderGlobals.cpp>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderGlobals.cpp>
- `src/passes/pass.cpp`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `src/passes/passes.h`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/passes.h>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/passes.h>
- `src/pass.h`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/pass.h>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/pass.h>
- `src/wasm-traversal.h`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/wasm-traversal.h>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/wasm-traversal.h>
- `src/support/topological_sort.h`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/support/topological_sort.h>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/support/topological_sort.h>
- `src/wasm.h`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/wasm.h>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/wasm.h>
- `src/passes/GlobalStructInference.cpp`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/GlobalStructInference.cpp>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GlobalStructInference.cpp>

### Official Binaryen test surfaces

- `test/lit/passes/reorder-globals.wast`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/reorder-globals.wast>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/reorder-globals.wast>
- `test/lit/passes/reorder-globals-real.wast`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/reorder-globals-real.wast>
  - current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/reorder-globals-real.wast>

## Durable observations

- The refreshed current-main review still matches the reviewed `version_129`/`version_130` teaching contract on the owner/helper/test surfaces above: `reorder-globals` remains a late module-wide global declaration-layout pass with static `global.get` / `global.set` counting, module-code scanning, initializer dependency constraints, four candidate orderings, true-count final size scoring, a public `< 128` cutoff, and a separate `reorder-globals-always` sibling.
- The official release horizon has advanced to `version_130`, but the reviewed implementation/test surfaces do not teach a new contract for this pass.
- The dedicated owner file is still `src/passes/ReorderGlobals.cpp`; the public and sibling pass registrations still live in `src/passes/pass.cpp` / `src/passes/passes.h`; module-code scanning is still inherited through `Pass` / traversal helpers; dependency sorting still depends on the topological-sort helper.
- The lit-test split remains the same: `reorder-globals.wast` is strongest for visible sorting families through `--reorder-globals-always`, while `reorder-globals-real.wast` is strongest for the public production cutoff and 129-global behavior.
- The current Starshine status remains boundary-only for the sibling helper: the direct public pass exists, but the `always` variant stays separate, and the local representation still needs numeric `GlobalIdx` remapping rather than Binaryen's name-keyed declaration swap.

## Uncertainties and caveats

- This focused review covers the owner/helper/test surfaces above. It does not attempt a full Binaryen archaeology pass over unrelated binary writer, pass-runner, or downstream consumer changes.
- Binaryen source still computes the exponential dependent-count candidate, but the shipped tests are clearest for zero/raw/summed/public-cutoff families. Treat exponential-only wins as source-confirmed but not isolated by a single obvious lit fixture in this capture.
- The `reorder-globals-always` sibling has its own living dossier. This file mentions it only where the public pass and sibling share source files or tests.

## Consumability rule

Cite this raw manifest together with the living `reorder-globals` pages when discussing the implementation/test map or current-main freshness layer. Keep explanatory claims in the living pages rather than growing this capture into a second dossier.
