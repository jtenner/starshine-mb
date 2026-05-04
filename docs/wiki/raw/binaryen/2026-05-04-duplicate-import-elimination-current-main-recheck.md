# Binaryen `duplicate-import-elimination` current-main recheck

Captured: 2026-05-04

## Scope

Official Binaryen `main` was spot-checked on the reviewed surfaces for `duplicate-import-elimination`.

## Reviewed primary sources

- `src/passes/DuplicateImportElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateImportElimination.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- `src/ir/import-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/import-utils.h>
- `test/passes/duplicate-import-elimination.wast`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/duplicate-import-elimination.wast>
- `test/passes/duplicate-import-elimination.txt`
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/duplicate-import-elimination.txt>

## Findings

- No teaching-relevant drift was found on the reviewed implementation, helper, registration, and dedicated-test surfaces.
- The current `main` contract still matches the corrected `version_129` story:
  - imported functions only
  - `(module, base)` buckets
  - exact function-type equality
  - first-import-wins canonicalization
  - function-name rewrite surface only
- The newer recheck is best treated as freshness for the living dossier, not as a contract change.
