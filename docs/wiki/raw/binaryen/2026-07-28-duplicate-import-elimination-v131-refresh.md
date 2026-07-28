# Binaryen v131 `duplicate-import-elimination` refresh

Date: 2026-07-28

## Oracle

- Official release binary: `.tmp/binaryen-version-131-bin/bin/wasm-opt`
- Version text: `wasm-opt version 131 (version_131)`
- Binary SHA-256: `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`
- Release tag commit: `1f903c14babf829745b421b92ff0f286e93e4209`

## Reviewed primary sources

- `src/passes/DuplicateImportElimination.cpp`
  - v131 SHA-256: `ab76ce5b4269322002f8a5f3004bd8f180eca30b8c5a4c6ce5209c76f7b2072b`
  - identical to the retained v130 hash
- `src/passes/opt-utils.h`
  - v131 SHA-256: `aa58e1c2294c8a91af919121a7da317791d61e3c768fc4ce239d812f8875b340`
  - identical to the retained v130 hash
- `test/passes/duplicate-import-elimination.wast`
  - v131 SHA-256: `f8a2990af2b4a162c0f8b44e0e6e0b58966774d884c874ef15ec9ddc3f32d479`
  - identical to the retained v130 hash
- `test/passes/duplicate-import-elimination.txt`
  - v131 SHA-256: `30affbb9912862ce2a6993294575f495ce2e0ff67065e73f01309fdb94c3c84a`

Official source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/DuplicateImportElimination.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/duplicate-import-elimination.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_131/test/passes/duplicate-import-elimination.txt>

## Released transform contract

The released v131 contract is unchanged from v130:

1. Scan imported functions only; non-function imports remain outside the pass.
2. Bucket by exact `(module, base)` strings.
3. Compare the later function's exact resolved function type with the current bucket representative.
4. On a type mismatch, keep the later import and make it the new representative.
5. On a type match, rewrite the later name to the representative through `OptUtils::replaceFunctions` and remove the later imported function.
6. The upstream rewrite surface is `call`, `ref.func`, module-code expression trees, `start`, and function exports.

Starshine's numeric-index representation additionally requires every later defined `FuncIdx`, structured function-name map, local/label indirect-name owner, and function-annotation owner to shift after a duplicate imported function is removed. Clearing `raw_name_sec_payload` on the changed path prevents stale absolute function indices from being re-emitted.

## Family coverage used for renewal

The refreshed `duplicate-import-elimination` GenValid aggregate covers:

- body references: direct `call`, nested block/loop/if references, `ref.func`, and `return_call`;
- identity and representative policy: same-type duplicates, mixed-type representative reset, different module, different base, and structurally equal function types under distinct type indices;
- module-code references: start, function exports, table initializer `ref.func`, global initializer `ref.func`, function-index element payloads, untyped expression payloads, and typed expression payloads;
- decoded legacy EH and structured EH: protected body, typed catch, catch-all, delegate-bearing nested `try`, and `try_table` protected body;
- negative scope: duplicate globals, tables, memories, and tags remain untouched.

## Conclusion

No v131 upstream owner/helper/test drift changes this pass's transform contract. The evidence renewal is nevertheless required because Starshine's legacy-`try` decoding and raw-name invalidation changed after the previous release-scale matrix. The 2026-07-28 matrix and exact family results are recorded in the living pass `fuzzing.md` and `starshine-strategy.md` pages.
