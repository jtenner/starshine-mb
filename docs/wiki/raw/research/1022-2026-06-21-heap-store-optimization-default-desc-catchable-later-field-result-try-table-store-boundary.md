---
kind: research
status: supported
created: 2026-06-21
sources:
  - ../../../../src/passes/heap_store_optimization.mbt
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../docs/wiki/binaryen/passes/heap-store-optimization/index.md
  - ../../../../docs/wiki/binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
---

# HSO default-descriptor catchable later-field result `try_table` store boundary

## Question

When a `struct.new_default_desc` allocation is followed by a `struct.set` whose value is a non-tail result-typed `try_table` with a catchable call, does Binaryen still fold the later same-field store?

This extends the later-field result-wrapper audit to the default-descriptor constructor combined with a catchable result-typed `try_table` store value. It is distinct from the immutable-descriptor old-field fold in `1021` (the `try_table` is the moved value, not another constructor field) and from the result-wrapper set-value boundaries in `1005`/`0996`/`0999`/`1000` (the `try_table` value writes the field, rather than appearing after the constructor).

## Binaryen probe

Probe file:

- `.tmp/hso-default-desc-later-field-result-try-oldfield-call-moved-const-catchall.wat`

Command:

```sh
wasm-opt --all-features .tmp/hso-default-desc-later-field-result-try-oldfield-call-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-default-desc-later-field-result-try-oldfield-call-moved-const-catchall.opt.wat
```

Result: Binaryen does not fold the pure `i32.const 9` later same-field store. It materializes `struct.new_desc` with the default field `0`, preserves the intervening `call` store on field `0`, the result-typed `try_table` / direct call store on field `1`, the immutable descriptor `global.get`, and the later `struct.set` of `i32.const 9`. The catchable `try_table` store value is a no-fold barrier.

## Starshine gap and fix

Red-first focused test:

- `heap-store-optimization keeps default descriptor stores before catchable later-field result try_table stores`

Initial Starshine behavior folded the pure later same-field store and lifted the result-typed `try_table` store value before the constructor local assignment, dropping the catchable call ordering and the later store.

Implementation change:

- `src/passes/heap_store_optimization.mbt`
  - `hso_try_fold_into_struct_new` now rejects folds whose moved store value contains a catchable `try_table` escape, mirroring the existing later-constructor-field tail/throw guard added in `1018`. This keeps the catchable `try_table` store value ordered after the constructor local assignment and preserves the later `struct.set`.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'default descriptor later-field result try_table store boundary'
```

Result: `401/401` passed (red before the fix, green after).

Additional validation:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-default-desc-result-try-catchable-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- `moon fmt` passed.
- Focused HSO tests passed `401/401`.
- Native `src/cmd` build passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct 10000-case `heap-store-optimization` compare compared `10000/10000`, normalized `10000`, `0` mismatches, `0` validation/property/generator failures, and `0` command failures.

## Classification and reopening criteria

Classification: HSO-D/E/G behavior-parity fix. A catchable result-typed `try_table` store value must not be reordered across a fresh-struct constructor assignment, because the catch may branch back before the assignment runs; Binaryen treats this as a no-fold barrier and Starshine now matches.

Reopen if Binaryen starts folding catchable result-typed `try_table` store values across default/plain/descriptor constructors, if Starshine reintroduces a broad catchable-escape fold, or if direct compare exposes another default/descriptor combined-with-result-wrapper family with different behavior.
