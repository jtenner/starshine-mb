# Heap-store-optimization branch-contained try_table global-set coverage

Date: 2026-06-21

## Question

Does the `0927` non-throwing `try_table` / unrelated `global.set` fold remain Binaryen-compatible when the `try_table` body contains a branch that is fully contained inside an inner block before the unrelated `global.set`?

## Binaryen `version_130` probe

A reduced WAT probe with:

- `memory.size` as constructor field 0,
- a fresh `struct.new` assigned to a local,
- a surrounding block with `try_table (catch_all ...)`,
- an inner `block` containing `i32.const 0; br_if 0; i32.const 9; global.set`, and
- a later same-object `struct.set` of field 1,

was run with local `wasm-opt version 130 (version_130)`:

```sh
wasm-opt --all-features .tmp/hso-branch-try-global.wat --heap-store-optimization -S -o .tmp/hso-branch-try-global.opt.wat
```

The optimized text retains `try_table`, `global.set`, `struct.new`, and `memory.size`, and removes `struct.set`. This shows Binaryen treats the inner branch as contained for the non-throwing unrelated-global-set swap family.

## Starshine finding

Starshine already matched the Binaryen behavior for both `memory.size` and `table.size` constructor operands in encoded-wasm tests. The pass preserves the branch-containing `try_table` / `global.set` wrapper, folds the later value into `struct.new`, and removes the redundant `struct.set`.

This is coverage-only. No implementation change was needed.

## Tests

Added focused tests in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds memory.size constructors across branch-contained try_table global stores`
- `heap-store-optimization folds table.size constructors across branch-contained try_table global stores`

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'branch-contained try_table global stores'` — `347/347` passed.

## Scope and reopening criteria

This note covers only non-throwing `try_table` bodies where the branch target is fully contained inside the `try_table` body and the intervening side effect is an unrelated mutable `global.set`. Reopen HSO-G if branches can escape the wrapper, catches can run, descriptor/result-typed branches are claimed, or the intervening root is a same-effect memory/table operation without separate Binaryen probes and focused tests.
