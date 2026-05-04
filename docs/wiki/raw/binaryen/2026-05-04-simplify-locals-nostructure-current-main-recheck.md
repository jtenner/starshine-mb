# Binaryen `simplify-locals-nostructure` current-main recheck

- **Captured:** 2026-05-04
- **Pass:** `simplify-locals-nostructure`
- **Scope:** current-main source / test recheck for the existing living dossier.
- **Status:** immutable raw-source manifest. Keep living conclusions in `docs/wiki/binaryen/passes/simplify-locals-nostructure/`.

## Primary upstream sources

- `SimplifyLocals.cpp` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
- `pass.cpp` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `pass.h` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- `opt-utils.h` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Dedicated no-structure proof files on `main`:
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nostructure.txt>

## Recheck result

The `main` branch still exposes `simplify-locals-nostructure` as a public pass, still schedules it in the no-DWARF locals slot after `tuple-optimization` and before `vacuum` / `reorder-locals`, and still instantiates the shared locals engine with structure-building disabled for this variant.

The reviewed surfaces did not show a teaching-relevant drift from the `version_129` contract already captured in the living dossier.

## Durable note

Use this file as the fresh provenance anchor for 2026-05-04 page updates. It is not the explanatory destination; the living dossier pages carry the interpretation.
