# Binaryen `duplicate-import-elimination` current-main recheck

_Capture date:_ 2026-04-25  
_Status:_ immutable follow-up source manifest for the `docs/wiki/binaryen/passes/duplicate-import-elimination/` dossier

## Scope

This file records the 2026-04-25 primary-source recheck done after Starshine gained an active `duplicate-import-elimination` module pass. It complements, but does not supersede, the broader 2026-04-23 raw manifest:

- `docs/wiki/raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md`

Use the living dossier pages for explanation:

- `docs/wiki/binaryen/passes/duplicate-import-elimination/index.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/identity-and-rewrite-surface.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/wat-shapes.md`
- `docs/wiki/binaryen/passes/duplicate-import-elimination/starshine-strategy.md`

## Primary sources rechecked

### Binaryen `main`

- `DuplicateImportElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateImportElimination.cpp>
- `pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `import-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/import-utils.h>
- dedicated test input
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/duplicate-import-elimination.wast>
- dedicated expected output
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/duplicate-import-elimination.txt>

### Binaryen `version_129` anchors retained

- `DuplicateImportElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateImportElimination.cpp>
- `pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `import-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.h>
- dedicated test input and expected output
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/duplicate-import-elimination.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/duplicate-import-elimination.txt>

## Durable observations

- The 2026-04-25 reviewed `main` surface still teaches the same pass contract as the `version_129` dossier: duplicate imported **functions** only, `(module, base)` bucketing, exact function-type equality, first-import-wins canonicalization, function-name replacement, and duplicate imported-function deletion.
- The reviewed `main` implementation still carries the explicit non-function-import TODO, so globals, tables, memories, and tags remain outside the source-confirmed upstream contract.
- The reviewed `main` dedicated test pair still covers the same practical shape set as the `version_129` dossier: duplicate nullary function imports, a same-module/base different-signature negative, element payload rewrite, start rewrite, and direct-call rewrite.
- No teaching-relevant drift was found on the checked `main` files. Treat future broadening beyond imported functions as new upstream drift or a deliberate Starshine divergence, not as part of the current reviewed Binaryen strategy.

## Starshine cross-check from this run

The local code map was rechecked against the current repository while filing this manifest:

- `src/passes/duplicate_import_elimination.mbt` owns planning, remapping, user rewrite, metadata repair, and duplicate import removal.
- `src/passes/optimize.mbt` registers `duplicate-import-elimination` as a module pass.
- `src/passes/pass_manager.mbt` dispatches it through the module-pass path.
- `src/passes/duplicate_import_elimination_test.mbt`, `src/passes/registry_test.mbt`, and `src/cmd/cmd_wbtest.mbt` provide focused local regression coverage.

## Consumability rule

Cite this manifest when a page needs the 2026-04-25 current-main recheck. Cite the 2026-04-23 manifest for the broader original source capture and release-page provenance.
