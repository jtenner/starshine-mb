# Heap-store-optimization call_ref memory-store boundaries

Date: 2026-06-21

## Question

Do the `call_ref` no-fold boundaries from `0914` through `0917` also apply when the unrelated intervening store root is an ordinary linear-memory store?

## Probes

Local oracle: `wasm-opt version 130 (version_130)`.

Fixtures:

- `.tmp/hso-probe-call-ref-memory-store.wat`
- `.tmp/hso-probe-call-ref-old-field-memory-store.wat`

Shapes:

1. constructor operand: field `0` is produced by `(call_ref $callee (ref.as_non_null (local.get $fn)))`, followed by unrelated `i32.store`, then later `struct.set` to field `1`;
2. old field: field `0` is produced by the same `call_ref`, followed by unrelated `i32.store`, then later `struct.set` overwrites field `0`.

Commands:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-ref-memory-store.wat \
  -S -o .tmp/hso-probe-call-ref-memory-store.opt.wat

grep -n "call_ref\|i32.store\|struct.new\|struct.set" \
  .tmp/hso-probe-call-ref-memory-store.opt.wat

wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-ref-old-field-memory-store.wat \
  -S -o .tmp/hso-probe-call-ref-old-field-memory-store.opt.wat

grep -n "call_ref\|i32.store\|struct.new\|struct.set" \
  .tmp/hso-probe-call-ref-old-field-memory-store.opt.wat
```

Grep evidence:

```text
# constructor operand
12:   (struct.new $pair
13:    (call_ref $callee
21:  (i32.store
25:  (struct.set $pair 1

# old field
12:   (struct.new $pair
13:    (call_ref $callee
21:  (i32.store
25:  (struct.set $pair 0
```

Binaryen preserves the `call_ref`, the intervening `i32.store`, and the later `struct.set` in both shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps call_ref constructor operands before unrelated i32.store`
- `heap-store-optimization keeps call_ref old fields before unrelated i32.store`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'call_ref'
```

Result: `295/295` passed after adding the coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only the typed-function-reference `call_ref` / `i32.store` counterparts to `0914` through `0917`; it does not close arbitrary typed-function-reference control roots, descriptor interactions, branch/catch wrappers, or all mutable store roots.

## Reopening criteria

Reopen if Binaryen changes either `call_ref` memory-store boundary, if Starshine starts dropping or moving the `call_ref` across the intervening memory store, or if a future source-backed rule proves a narrower safe fold that preserves typed-function-reference call effects and memory-store ordering.
