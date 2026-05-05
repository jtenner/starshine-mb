# Binaryen `reorder-functions-by-name` current-main recheck

_Status:_ immutable focused source recheck and code-map refresh for the `docs/wiki/binaryen/passes/reorder-functions-by-name/` dossier

This file captures a 2026-05-05 current-`main` recheck of the upstream `reorder-functions-by-name` surfaces. It narrows the earlier 2026-04-24 bridge to two questions:

- did current `main` drift in any teaching-relevant way from the existing Binaryen `version_129` contract?
- did the exact local Starshine code anchors used by the living dossier need a refresh?

## Pages this manifest supports

- `docs/wiki/binaryen/passes/reorder-functions-by-name/index.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/lexical-order-proof-and-boundaries.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/module-shapes.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/starshine-strategy.md`
- `docs/wiki/binaryen/passes/reorder-functions-by-name/starshine-port-readiness-and-validation.md`

## Primary sources rechecked

- `ReorderFunctions.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- dedicated lit test
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/reorder-functions-by-name.wast>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/reorder-functions-by-name.wast>

## Current-main line anchors from the 2026-05-05 spotcheck

- `ReorderFunctions.cpp#L643-L661` - `ReorderFunctionsByName` declaration-only comparator sort
- `pass.cpp#L3031-L3035` - public `reorder-functions-by-name` registration and debugging description
- `reorder-functions-by-name.wast#L458-L622` - the four lit-backed declaration permutations that normalize to `$a`, `$b`, `$c`

## Recheck result

The reviewed current-`main` sources still support the same teaching-level contract as the existing dossier:

- the pass still sorts the module function list by ascending internal name;
- the reviewed `pass.cpp` still exposes it as a separate public debugging-oriented pass;
- the dedicated lit file still proves the same four permutation families;
- the declaration-only boundary still matches `requiresNonNullableLocalFixups() == false`;
- no teaching-relevant current-`main` drift was recorded on the reviewed surface.

## Local code-map refresh

The 2026-05-05 recheck also confirmed that the local Starshine anchors used by the living dossier still point at the same surfaces:

- `src/passes/optimize.mbt:137-138`
- `src/passes/pass_manager.mbt`
- `src/lib/types.mbt`
- `src/passes/remove_unused_module_elements.mbt`
- `src/binary/encode.mbt`
- `src/wast/lower_to_lib.mbt`
- `agent-todo.md`

## Source provenance

- [`../research/0481-2026-05-05-reorder-functions-by-name-current-main-recheck.md`](../research/0481-2026-05-05-reorder-functions-by-name-current-main-recheck.md)
