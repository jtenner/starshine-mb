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

# HSO later-field result-typed `try_table` tail-call boundary

## Question

Do later constructor fields that are result-typed `try_table` wrappers with tail calls follow the pure-fold side of the `1015`-`1017` call split, or do they remain no-fold barriers?

The tested constructor has field 1 supplied by a result-typed `try_table` whose body performs `return_call`, `return_call_indirect`, or `return_call_ref`; the later same-object `struct.set` targets field 0 with a pure `i32.const 9` value.

## Binaryen probes

Probe files:

- `.tmp/hso-later-field-result-try-return-call-moved-const-catchall.wat`
- `.tmp/hso-later-field-result-try-return-call-indirect-moved-const-catchall.wat`
- `.tmp/hso-later-field-result-try-return-call-ref-moved-const-catchall.wat`

Commands:

```sh
wasm-opt --all-features .tmp/hso-later-field-result-try-return-call-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-return-call-moved-const-catchall.opt.wat
wasm-opt --all-features .tmp/hso-later-field-result-try-return-call-indirect-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-return-call-indirect-moved-const-catchall.opt.wat
wasm-opt --all-features .tmp/hso-later-field-result-try-return-call-ref-moved-const-catchall.wat --heap-store-optimization -S -o .tmp/hso-later-field-result-try-return-call-ref-moved-const-catchall.opt.wat
```

Result: Binaryen preserves `struct.new`, the result-typed `try_table` tail-call wrapper, and the later `struct.set` for all three tail-call spellings, even when the moved set value is pure.

## Starshine change

Added failing focused tests first:

- `heap-store-optimization keeps pure set values after later-field result try_table return_call constructors`
- `heap-store-optimization keeps pure set values after later-field result try_table return_call_indirect constructors`
- `heap-store-optimization keeps pure set values after later-field result try_table return_call_ref constructors`

Initial result before the fix: the three tests failed because Starshine folded the pure set value before the tail-call later-field wrapper, producing invalid HOT/lowered output where `i32.const 9` preceded a `try_table` whose body exits through a tail call inside `struct.new`.

Fix: `hso_try_fold_into_struct_new` now rejects folding a later same-field `struct.set` into a constructor when any later constructor field subtree has a tail/throw escape. This keeps the `1015`-`1017` direct/indirect/typed-function-reference non-tail pure folds intact while matching Binaryen's tail-call later-field boundary.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'later-field result try_table return_call'
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'later-field result try_table call_indirect'
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-later-field-tail-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Results:

- Focused return-call lane: `394/394` passed.
- Focused non-tail `call_indirect` regression lane: `394/394` passed.
- `moon fmt`: passed.
- Full focused HSO file: `394/394` passed.
- Native `src/cmd` build: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct compare: compared `10000/10000`, normalized matches `10000`, mismatches `0`, validation/property/generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.

## Classification and reopening criteria

Classification: Binaryen behavior parity fix. Later constructor fields that can leave the current function through result-typed `try_table` tail-call bodies are no-fold barriers, even for pure moved set values. This is narrower than the non-tail result-wrapper split: direct calls, indirect calls, and `call_ref` wrappers still fold pure moved values but preserve effectful moved calls.

Reopen if Binaryen starts folding pure values across later-field tail-call result wrappers, if Starshine regresses the `1015`-`1017` non-tail pure folds, or if a later-field throw/catch variant proves Binaryen has a narrower escape distinction than the current tail/throw-escape guard.
