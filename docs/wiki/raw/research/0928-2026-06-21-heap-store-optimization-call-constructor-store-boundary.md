# Heap-store-optimization direct-call constructor store boundaries

Date: 2026-06-21

## Question

Do the HSO-G direct-call constructor-operand no-swap boundary from `0803` and the indirect-call/table/memory-store boundaries from `0924` / `0926` also cover ordinary direct calls before unrelated ordinary table and memory stores?

## Binaryen oracle

Local oracle: `wasm-opt version 130 (version_130)`.

Probed shapes:

1. A fresh `$pair` constructor has field 0 produced by `call $helper`; an intervening unrelated `i32.store` runs before a later `struct.set $pair 0`.
2. The same constructor shape with an intervening unrelated `table.set`.

Commands:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-constructor-memory-store.wat \
  -S -o .tmp/hso-probe-call-constructor-memory-store.opt.wat

wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-constructor-table-set.wat \
  -S -o .tmp/hso-probe-call-constructor-table-set.opt.wat
```

Observed shape: Binaryen preserves the direct `call`, the intervening store root, and the later `struct.set` in both fixtures. Folding would move the effectful direct call across the memory/table store root, so this is a no-swap boundary rather than a missed fold.

## Starshine coverage

Added focused tests:

- `heap-store-optimization keeps call constructor operands before unrelated i32.store`
- `heap-store-optimization keeps call constructor operands before unrelated table.set`

Starshine already matched Binaryen: the focused filter passed without implementation changes.

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'call constructor operands before unrelated'
```

Result: `292/292` passed.

## Classification

Coverage-only HSO-G boundary slice. This closes the direct-call constructor/store counterparts for unrelated `i32.store` and `table.set`, but does not generalize to arbitrary call-bearing control roots, old-field combinations beyond existing notes, or descriptor/later-field interactions.

## Reopening criteria

Reopen if a future Binaryen source/oracle refresh folds a direct-call constructor operand across these store roots under a narrower proof, or if Starshine starts dropping the later `struct.set` or moving the direct call across the intervening memory/table store.
