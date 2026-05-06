# Binaryen `reorder-locals` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/reorder-locals/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `reorder-locals` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-22-reorder-locals-primary-sources.md` and the later validation manifest in `docs/wiki/raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/reorder-locals/index.md`
- `docs/wiki/binaryen/passes/reorder-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-locals/names-roundtrip-and-porting.md`
- `docs/wiki/binaryen/passes/reorder-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/reorder-locals/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `ReorderLocals.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderLocals.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ReorderLocals.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `reorder-locals.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/reorder-locals.wast>
- `reorder-locals.txt`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.txt>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/reorder-locals.txt>
- `reorder-locals_print_roundtrip.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/reorder-locals_print_roundtrip.wast>
- `reorder-locals_print_roundtrip.txt`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.txt>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/reorder-locals_print_roundtrip.txt>

### Tagged comparison anchor

- `ReorderLocals.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderLocals.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `reorder-locals.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.wast>
- `reorder-locals.txt` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.txt>
- `reorder-locals_print_roundtrip.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.wast>
- `reorder-locals_print_roundtrip.txt` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.txt>

## Reviewed source surfaces

The recheck focused on the same teaching-relevant surfaces already documented in the living dossier:

- `ReorderLocals.cpp:618-624` for the pass shell and the explicit `requiresNonNullableLocalFixups() == false` boundary
- `ReorderLocals.cpp:649-845` for the access-count walk, first-use ranking, stable sorting, zero-count suffix trim, AST reindexing, and local-name repair
- `pass.cpp:3054-3058` for public registration
- `pass.cpp:3512` and `pass.cpp:3552-3562` for the repeated no-DWARF scheduler placements
- `reorder-locals.wast:351-430` for the hot-body-local, tie-break, write-only, tee-only, and zero-tail shapes
- `reorder-locals_print_roundtrip.wast:279-314` for the declaration-order and printed-name roundtrip boundary

## Durable observations

- Current `main` still registers `reorder-locals` with the same public description and places it in the same no-DWARF local-cleanup slots as `version_129`.
- The owner file still teaches the same narrow contract already captured by the living dossier: access counting, first-use ordering, parameter stability, zero-count body-local truncation, local-user reindexing, and local-name repair.
- The official lit surfaces still contain the same important boundaries: hot-body-local sorting, write-only and tee-only survival, params-fixed behavior, and print-roundtrip name/declaration order.
- No teaching-relevant drift was found on the reviewed current-main surfaces.
- The local Starshine story is unchanged by this source refresh: `reorder-locals` remains an active module pass, while preset scheduling still waits on neighboring local passes and ordered no-DWARF replay evidence.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
