# Binaryen `rereloop` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/rereloop/` dossier

## Scope

This file captures the exact primary online sources consulted for the 2026-04-24 `rereloop` / local `re-reloop` follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/rereloop/index.md`
- `docs/wiki/binaryen/passes/rereloop/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/rereloop/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/rereloop/flat-cfg-builder-and-boundaries.md`
- `docs/wiki/binaryen/passes/rereloop/wat-shapes.md`
- `docs/wiki/binaryen/passes/rereloop/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release as **Latest** and showed the publish timestamp as **2026-04-01 14:31**.
  - GitHub showed the release commit as `d0e2be9` and reported **53 commits** to `main` since this release at capture time.

### Official source files consulted

- `ReReloop.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReReloop.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `Relooper.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/cfg/Relooper.h>
- `Relooper.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/cfg/Relooper.cpp>
- `flat.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>

### Official test files consulted

- `flatten_rereloop.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_rereloop.wast>
- `opt_flatten.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/opt_flatten.wast>

## Durable observations from the captured sources

- The reviewed official release surface still anchored cleanly on Binaryen `version_129` for this pass on 2026-04-24, with the tagged release page marked **Latest** and showing publish timestamp **2026-04-01 14:31**.
- Upstream registers the public pass spelling as `rereloop`, with the short public summary `re-optimize control flow using the relooper algorithm`.
- The upstream `-O4` / flatten-era scheduler area still keeps `rereloop` as a future TODO immediately after the `flatten -> simplify-locals-notee-nostructure -> local-cse` cluster; the source does not make it an active default-slot pass in the reviewed path.
- The reviewed implementation still starts real work with `Flat::verifyFlatness(function)`, confirming that already-flat input is a hard precondition rather than a convenience.
- The reviewed implementation still rejects `try`, `throw`, and `rethrow` with a hard fatal unsupported-EH path.
- The reviewed implementation still builds temporary CFG blocks with a task stack, patches dead-end CFG blocks with `return` or `unreachable`, renders through `CFG::RelooperBuilder`, adds a fresh `i32` helper label local, appends `unreachable` for apparent result-typed fallthrough repair, and runs `ReFinalize`.
- `cfg/Relooper.h` still documents the side-effect-free condition requirement that makes the flatness precondition semantically important: the generic relooper may reorder or remove condition checks.
- The dedicated `flatten_rereloop.wast` file still runs `wasm-opt --flatten --rereloop` and remains the main visible shape oracle for helper locals, helper blocks, skip-empty structures, branch-table regrouping, and result repair.
- A narrow 2026-04-24 current-`main` spot check of the opened `ReReloop.cpp` and `flatten_rereloop.wast` surfaces did not surface teaching-relevant drift from the documented `version_129` contract.
- The Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact remains that Starshine tracks the pass under the removed spelling `re-reloop`, not under upstream `rereloop`, and rejects active requests.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
