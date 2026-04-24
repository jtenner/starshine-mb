# Binaryen `minimize-rec-groups` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/minimize-rec-groups/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `minimize-rec-groups` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/minimize-rec-groups/index.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/permutations-brands-and-public-conflicts.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/wat-shapes.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01 14:31**.
  - The page identified the release as the latest release when reviewed.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep the dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `MinimizeRecGroups.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinimizeRecGroups.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinimizeRecGroups.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MinimizeRecGroups.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MinimizeRecGroups.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
- `type-updating.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.cpp>
- `strongly_connected_components.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/strongly_connected_components.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/support/strongly_connected_components.h>
- `topological_sort.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/support/topological_sort.h>
- `disjoint_sets.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/disjoint_sets.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/support/disjoint_sets.h>
- `wasm-type-shape.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type-shape.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-type-shape.h>
- `wasm-type-shape.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-type-shape.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm/wasm-type-shape.cpp>

### Official test files consulted

- `minimize-rec-groups.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/minimize-rec-groups.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/minimize-rec-groups.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/minimize-rec-groups.wast>
- `minimize-rec-groups-brands.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/minimize-rec-groups-brands.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/minimize-rec-groups-brands.wast>
- `minimize-rec-groups-desc.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/minimize-rec-groups-desc.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/minimize-rec-groups-desc.wast>
- `minimize-rec-groups-exact.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/minimize-rec-groups-exact.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/minimize-rec-groups-exact.wast>
- `minimize-rec-groups-ignore-exact.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/minimize-rec-groups-ignore-exact.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/minimize-rec-groups-ignore-exact.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `pass.cpp` registers the public CLI name `minimize-rec-groups` with the compact summary `Split types into minimal recursion groups`, but the owner source shows that the actual contract is larger than SCC splitting.
- `MinimizeRecGroups.cpp` still owns the pass-specific algorithm: GC gate, private/public heap-type split, private SCC discovery, valid-order repair, shape-collision handling, canonicalization, permutation/brand updates, and final type rewrite.
- The helper files remain central to correctness: `module-utils.h` supplies heap-type visibility, `strongly_connected_components.h` supplies SCCs, `topological_sort.h` supplies valid order enumeration, `disjoint_sets.h` supplies conflict-class tracking, `wasm-type-shape.*` supplies feature-sensitive rec-group shapes and brands, and `type-updating.*` supplies the module-wide type/name/index remap.
- The dedicated lit roster remains intentionally broad: baseline SCC splitting, public conflicts, permutation wins, brand fallback and brand-stress cases, descriptor/described ordering, exactness-sensitive shapes, and exactness-erasure behavior.
- The Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `minimize-rec-groups` is a preserved **boundary-only** registry name, not an active HOT or module pass.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, helper headers, and dedicated lit files did not surface a teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
