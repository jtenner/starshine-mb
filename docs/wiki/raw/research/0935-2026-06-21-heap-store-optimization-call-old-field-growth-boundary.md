# Heap-store-optimization direct-call old-field growth boundaries

Date: 2026-06-21

## Question

Do the ordinary direct-call old-field no-fold boundaries from `0923` and `0929` also apply when the unrelated intervening root is `memory.grow` or `table.grow`?

## Probes

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture:

- `.tmp/hso-probe-call-old-field-growth.wat`

Shape: field `0` is produced by a direct `call $helper`, followed by unrelated `memory.grow` or `table.grow`, then later `struct.set` overwrites field `0`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-call-old-field-growth.wat \
  -S -o .tmp/hso-probe-call-old-field-growth.opt.wat

grep -n "call\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-call-old-field-growth.opt.wat
```

Grep evidence:

```text
12:   (struct.new $pair
13:    (call $helper)
18:   (memory.grow
22:  (struct.set $pair 0
33:   (struct.new $pair
34:    (call $helper)
39:   (table.grow $0
44:  (struct.set $pair 0
```

Binaryen preserves the direct call, the intervening growth root, and the later `struct.set` in both old-field shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps call old fields before unrelated growth roots`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'growth roots'
```

Result: `301/301` passed after adding the coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only the ordinary direct-call old-field boundaries before unrelated `memory.grow` and `table.grow`; it does not close arbitrary direct-call branch/catch behavior, descriptor interactions, or all growth/mutable roots.

## Reopening criteria

Reopen if Binaryen changes either direct-call old-field growth boundary, if Starshine starts dropping or moving the old-field call across the intervening growth root, or if a future source-backed rule proves a narrower safe fold that preserves direct-call effects and growth-root ordering.
