# Heap-store-optimization call_indirect old-field growth boundaries

Date: 2026-06-21

## Question

Do the indirect-call old-field no-fold boundaries from `0925` and `0926` also apply when the unrelated intervening root is `memory.grow` or `table.grow`?

## Probes

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture:

- `.tmp/hso-probe-call-indirect-old-field-growth.wat`

Shape: field `0` is produced by `call_indirect`, followed by unrelated `memory.grow` or `table.grow`, then later `struct.set` overwrites field `0`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-indirect-old-field-growth.wat \
  -S -o .tmp/hso-probe-call-indirect-old-field-growth.opt.wat

grep -n "call_indirect\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-call-indirect-old-field-growth.opt.wat
```

Grep evidence:

```text
13:   (struct.new $pair
14:    (call_indirect $0 (type $callee)
21:   (memory.grow
25:  (struct.set $pair 0
36:   (struct.new $pair
37:    (call_indirect $0 (type $callee)
44:   (table.grow $0
49:  (struct.set $pair 0
```

Binaryen preserves `call_indirect`, the intervening growth root, and the later `struct.set` in both old-field shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps call_indirect old fields before unrelated growth roots`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'growth roots'
```

Result: `300/300` passed after adding this coverage and the companion `0933` coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only the `call_indirect` old-field boundaries before unrelated `memory.grow` and `table.grow`. It does not close arbitrary indirect-call branch/catch behavior, descriptor interactions, or all growth/mutable roots.

## Reopening criteria

Reopen if Binaryen changes either `call_indirect` old-field growth boundary, if Starshine starts dropping or moving `call_indirect` across the intervening growth root, or if a future source-backed rule proves a narrower safe fold that preserves indirect-call effects and growth-root ordering.
