# Heap-store-optimization call_ref growth boundaries

Date: 2026-06-21

## Question

Do the typed-function-reference `call_ref` no-fold boundaries from `0914` through `0917` and `0930` also apply when the unrelated intervening root is `memory.grow` or `table.grow`?

## Probes

Local oracle: `wasm-opt version 130 (version_130)`.

Fixtures:

- `.tmp/hso-probe-call-ref-growth.wat`
- `.tmp/hso-probe-call-ref-old-field-growth.wat`

Shapes:

1. constructor operand: field `0` is produced by `(call_ref $callee (ref.as_non_null (local.get $fn)))`, followed by unrelated `memory.grow` or `table.grow`, then later `struct.set` to field `1`;
2. old field: field `0` is produced by the same `call_ref`, followed by unrelated `memory.grow` or `table.grow`, then later `struct.set` overwrites field `0`.

Commands:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-ref-growth.wat \
  -S -o .tmp/hso-probe-call-ref-growth.opt.wat

grep -n "call_ref\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-call-ref-growth.opt.wat

wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-ref-old-field-growth.wat \
  -S -o .tmp/hso-probe-call-ref-old-field-growth.opt.wat

grep -n "call_ref\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-call-ref-old-field-growth.opt.wat
```

Grep evidence:

```text
# constructor operand
13:   (struct.new $pair
14:    (call_ref $callee
23:   (memory.grow
27:  (struct.set $pair 1
38:   (struct.new $pair
39:    (call_ref $callee
48:   (table.grow $0
53:  (struct.set $pair 1

# old field
13:   (struct.new $pair
14:    (call_ref $callee
23:   (memory.grow
27:  (struct.set $pair 0
38:   (struct.new $pair
39:    (call_ref $callee
48:   (table.grow $0
53:  (struct.set $pair 0
```

Binaryen preserves `call_ref`, the intervening growth root, and the later `struct.set` in all four shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps call_ref constructor operands before unrelated growth roots`
- `heap-store-optimization keeps call_ref old fields before unrelated growth roots`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'growth roots'
```

Result: `300/300` passed after adding this coverage and the companion `0934` coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only the typed-function-reference `call_ref` constructor and old-field boundaries before unrelated `memory.grow` and `table.grow`; it does not close arbitrary typed-function-reference control roots, branch/catch wrappers, descriptor interactions, or all growth/mutable roots.

## Reopening criteria

Reopen if Binaryen changes either `call_ref` growth boundary, if Starshine starts dropping or moving `call_ref` across the intervening growth root, or if a future source-backed rule proves a narrower safe fold that preserves typed-function-reference call effects and growth-root ordering.
