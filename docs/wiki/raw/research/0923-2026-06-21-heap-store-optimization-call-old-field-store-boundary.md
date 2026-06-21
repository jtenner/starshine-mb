# Heap-store-optimization call old-field store boundaries

Date: 2026-06-21

## Question

Do the `call_ref` old-field boundaries from `0915` / `0917` have the same direct-call counterpart when an overwritten constructor field is a value-producing ordinary `call` and an unrelated store root intervenes before the later `struct.set`?

## Probes

Local oracle: `wasm-opt version 130 (version_130)`.

Two fixtures were probed:

1. overwritten old field `(call $side)` before an unrelated mutable `global.set`;
2. overwritten old field `(call $side)` before an unrelated `table.set`.

Commands:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-old-field-global-set.wat \
  -S -o .tmp/hso-probe-call-old-field-global-set.opt.wat

wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-old-field-table-set.wat \
  -S -o .tmp/hso-probe-call-old-field-table-set.opt.wat
```

Binaryen preserved the `call`, the intervening `global.set` / `table.set`, and the later `struct.set` in both shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps call old fields before unrelated global.set`
- `heap-store-optimization keeps call old fields before unrelated table.set`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'call old fields'
```

Result: `283/283` passed.

## Classification

Binaryen-matching no-fold boundary, not a Starshine win/non-goal. A value-producing ordinary call in an overwritten constructor field must remain before the intervening store root, and the later `struct.set` must remain.

This narrows the broader HSO-D/G old-field/effect matrix but does not close arbitrary call-bearing old-field combinations, descriptor interactions, or catch/branch wrappers.
