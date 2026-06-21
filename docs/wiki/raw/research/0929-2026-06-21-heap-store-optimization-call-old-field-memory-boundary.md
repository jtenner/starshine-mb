# Heap-store-optimization direct-call old-field memory-store boundary

Date: 2026-06-21

## Question

Does the direct-call old-field no-fold boundary from `0923` also apply when the unrelated intervening store root is an ordinary linear-memory store?

## Probe

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture:

- `.tmp/hso-probe-call-old-field-memory-store.wat`

Shape:

- construct `$pair` with field `0` from value-producing `(call $helper (i32.const 5))` and field `1` from `i32.const 2`;
- store the fresh struct in a local;
- execute unrelated `(i32.store (i32.const 0) (i32.const 99))`;
- later overwrite field `0` with `struct.set`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-old-field-memory-store.wat \
  -S -o .tmp/hso-probe-call-old-field-memory-store.opt.wat

grep -n "call\|i32.store\|struct.new\|struct.set" \
  .tmp/hso-probe-call-old-field-memory-store.opt.wat
```

Grep evidence:

```text
10:   (struct.new $pair
11:    (call $helper
17:  (i32.store
21:  (struct.set $pair 0
```

Binaryen preserves the direct call, the intervening `i32.store`, and the later `struct.set`. It does not drop the overwritten call old-field or move it across the unrelated memory store root.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps call old fields before unrelated i32.store`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'call old fields'
```

Result: `293/293` passed after adding the coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only the ordinary direct-call old-field / `i32.store` counterpart to `0923`; it does not close arbitrary call-bearing old-field combinations, descriptor interactions, branch/catch wrappers, or all mutable store roots.

## Reopening criteria

Reopen if Binaryen changes this old-field preservation rule, if Starshine starts dropping or moving the direct call across the intervening memory store, or if a future source-backed rule proves a narrower safe fold that preserves direct-call side effects and memory-store ordering.
