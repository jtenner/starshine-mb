# Binaryen `reorder-types` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/reorder-types/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `reorder-types` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/reorder-types/index.md`
- `docs/wiki/binaryen/passes/reorder-types/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-types/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-types/ordering-cost-model-and-boundaries.md`
- `docs/wiki/binaryen/passes/reorder-types/wat-shapes.md`
- `docs/wiki/binaryen/passes/reorder-types/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the publish date as **2026-04-01 14:31**.
  - The page identified `version_129` as the latest release when reviewed.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24.
  - Used to keep the dossier anchored to the official release surface reviewed in this run.

### Official source files consulted

- `ReorderTypes.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderTypes.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/ReorderTypes.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderTypes.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderTypes.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.h>
- `type-updating.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.cpp>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
- `module-utils.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp>
- `wasm-type-ordering.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type-ordering.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-type-ordering.h>

### Official test files consulted

- `reorder-types.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-types.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/reorder-types.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-types.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/reorder-types.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page showing publish date **2026-04-01 14:31**.
- `pass.cpp` registers public `reorder-types` and hidden `reorder-types-for-testing` names. The hidden sibling changes the cost model so tiny lit modules show byte-width transitions more easily; it is not a separate algorithm.
- `ReorderTypes.cpp` owns the pass-specific algorithm: GC gate, hard `--closed-world` requirement, private-type predecessor graph, direct use-count seeding, 21 successor-weight factors, encoded-index cost scoring, and best-order selection.
- `type-updating.*` owns the shared `GlobalTypeRewriter` machinery that makes the pass correct: public/private split, predecessor discovery, private-type rebuild, module-wide type mapping, type-name repair, and preserved type-index metadata repair.
- `module-utils.*` owns the heap-type counting and visibility surface. The reorder pass uses the used-IR heap-type inventory, not every type-like binary surface.
- The dedicated `reorder-types.wast` file proves unconstrained count-driven wins, legality-pinned subtype chains, successor-weight effects, the testing cost model, and a regression around mismatched counted type inventories.
- The Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `reorder-types` is a preserved **boundary-only** registry name, not an active HOT or module pass.
- A narrow 2026-04-24 current-`main` spot check on the owner file, registration surface, helper files, and dedicated lit file did not surface teaching-relevant contract drift from the reviewed `version_129` story. The durable claim is intentionally narrow, not a whole-repo equivalence proof.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
