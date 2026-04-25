# Binaryen `reorder-globals` current-main and implementation/test-map source bridge

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the refreshed `docs/wiki/binaryen/passes/reorder-globals/` implementation/test-map follow-up

## Scope

This file captures the primary online sources consulted while closing the remaining `reorder-globals` dossier gap: the lack of a dedicated owner/helper/lit-test implementation map and an exact Starshine prerequisite code map.

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

- Binaryen release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Existing dossier observation retained: the official release page showed publish date **2026-04-01** when reviewed on 2026-04-23.
- `src/passes/ReorderGlobals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderGlobals.cpp>
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `src/passes/passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `src/pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- `src/wasm-traversal.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-traversal.h>
- `src/support/topological_sort.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/support/topological_sort.h>
- `src/wasm.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm.h>
- `src/passes/GlobalStructInference.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>

### Official Binaryen test surfaces

- `test/lit/passes/reorder-globals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-globals.wast>
- `test/lit/passes/reorder-globals-real.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-globals-real.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-globals-real.wast>

### Local Starshine surfaces rechecked

- `src/passes/optimize.mbt`
  - boundary-only registry entries for `reorder-globals` and `reorder-globals-always`
  - boundary-only request rejection path
- `src/lib/types.mbt`
  - numeric `GlobalIdx`, `GlobalSec`, `ImportSec`, `ExportSec`, and `Module` section model
- `src/binary/encode.mbt`
  - `GlobalIdx` ULEB encoding surface
- `src/binary/decode.mbt`
  - `GlobalIdx` decoding surface
- `src/validate/validate.mbt`
  - const-expression `GlobalGet` validation against earlier/imported immutable globals
- `src/ir/hot.mbt`
  - HOT lift representation of `GlobalGet` / `GlobalSet` as numeric global indices, confirming why this pass is not a HOT-only peephole
- `agent-todo.md`
  - `RG - Reorder Globals` backlog slice
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - canonical late-tail slot `string-gathering -> reorder-globals -> directize`

## Durable observations

- The focused 2026-04-25 current-main recheck did not find teaching-relevant drift from the existing `version_129` contract: `reorder-globals` remains a module-wide global declaration-layout pass with static `global.get` / `global.set` counting, module-code scanning, initializer dependency constraints, four candidate orderings, true-count final size scoring, a public `< 128` cutoff, and a separate `reorder-globals-always` sibling.
- The dedicated owner file is still `src/passes/ReorderGlobals.cpp`; the public and sibling pass registrations still live in `src/passes/pass.cpp` / `src/passes/passes.h`; module-code scanning is still inherited through `Pass` / traversal helpers; dependency sorting still depends on the topological-sort helper.
- The official lit proof surface is split: `reorder-globals.wast` is strongest for the visible sorting families because it uses `--reorder-globals-always`, while `reorder-globals-real.wast` is strongest for the public production cutoff and 129-global behavior.
- The current Starshine status remains boundary-only: there is still no `src/passes/reorder_globals.mbt`, no module dispatcher case, no local reduced pass tests, and no late global declaration remapper. The useful local implementation map is therefore a prerequisite/port map rather than an active owner-file map.
- A future Starshine port must rewrite numeric `GlobalIdx` surfaces, not just reorder a name-keyed declaration vector like Binaryen. That affects import/export indices, function/module-code `global.get` and `global.set` operands, global initializer dependencies, binary encode/decode expectations, and validation of declaration order.

## Uncertainties and caveats

- The current-main recheck was focused on the official owner/helper/test surfaces above. It did not attempt a full repository-wide Binaryen archaeology pass for unrelated changes to the binary writer, pass runner, or all downstream consumers of global ordering.
- Binaryen source still computes the exponential dependent-count candidate, but the shipped tests are clearest for zero/raw/summed/public-cutoff families. Treat exponential-only wins as source-confirmed but not isolated by a single obvious lit fixture in this capture.
- The `reorder-globals-always` sibling has its own living dossier. This file mentions it only where the public pass and sibling share source files or tests.

## Consumability rule

Cite this raw manifest together with the living `reorder-globals` pages when discussing the implementation/test map or current-main no-drift status. Keep explanatory claims in the living pages rather than growing this capture into a second dossier.
