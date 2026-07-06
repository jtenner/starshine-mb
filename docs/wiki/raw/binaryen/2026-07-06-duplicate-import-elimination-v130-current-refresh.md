# Binaryen `duplicate-import-elimination` v130/current refresh

Date: 2026-07-06

## Sources checked

- Local oracle: `wasm-opt --version` reports `wasm-opt version 130 (version_130)`.
- Official `version_130` source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/DuplicateImportElimination.cpp>
  - Raw SHA-256 captured locally from GitHub raw content: `ab76ce5b4269322002f8a5f3004bd8f180eca30b8c5a4c6ce5209c76f7b2072b`.
- Official `main` source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateImportElimination.cpp>
  - Raw SHA-256 captured locally from GitHub raw content: `ab76ce5b4269322002f8a5f3004bd8f180eca30b8c5a4c6ce5209c76f7b2072b`.
- Official `version_130` rewrite helper: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/opt-utils.h>
  - Raw SHA-256 captured locally from GitHub raw content: `aa58e1c2294c8a91af919121a7da317791d61e3c768fc4ce239d812f8875b340`.
- Official `version_130` dedicated pass test: <https://github.com/WebAssembly/binaryen/blob/version_130/test/passes/duplicate-import-elimination.wast>
  - Raw SHA-256 captured locally from GitHub raw content: `f8a2990af2b4a162c0f8b44e0e6e0b58966774d884c874ef15ec9ddc3f32d479`.

## Refreshed contract

- `version_130` and current `main` are byte-identical for `DuplicateImportElimination.cpp` on this check.
- The pass is still function-import-only. The source still carries the non-function-import TODO, so globals, tables, memories, and tags are not currently deduplicated by upstream Binaryen.
- Duplicate detection still keys only by import `(module, base)` and then compares the resolved function type.
- Important correction to older local wording: the bucket representative is the most recent kept import for that `(module, base)`, not permanently the first import in the bucket. When a same `(module, base)` import has a different type, Binaryen keeps it and updates the representative. A later import of that new type deduplicates against it.
- When a type match is found, Binaryen records a function replacement to the current representative, then removes the duplicate imported function. Rewrites are delegated to `OptUtils::replaceFunctions(...)`.

## Local probe for representative reset

Input:

```wat
(module
  (type $i (func (param i32)))
  (type $v (func))
  (import "env" "waka" (func $first (type $i)))
  (import "env" "waka" (func $second (type $v)))
  (import "env" "waka" (func $third (type $v)))
)
```

Command:

```sh
wasm-opt --all-features --duplicate-import-elimination .tmp/die-type-bucket.wat -S -o -
```

Observed Binaryen output keeps `$first` and `$second` only, proving `$third` deduplicates against the second import after `$second` reset the bucket representative.

## Starshine impact

The previous Starshine test and implementation treated `(i32), (), ()` same-module/base imports as three kept imports. That was a parity bug against the refreshed `version_130` contract. The 2026-07-06 slice changed Starshine to update the representative on type mismatch and added/updated focused coverage in `src/passes/duplicate_import_elimination_test.mbt`.
