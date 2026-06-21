# Heap-store-optimization block-wrapped call_indirect growth boundaries

Date: 2026-06-21

## Question

Do the `call_indirect` constructor-operand growth-root no-fold boundaries from `0932` still apply when the effectful indirect call is wrapped in a value-producing `block` before an unrelated `memory.grow` or `table.grow` root?

## Probes

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture:

- `.tmp/hso-probe-block-call-indirect-growth.wat`

Shape: field `0` is produced by a `block (result i32)` containing `call_indirect`, then an unrelated `memory.grow` or `table.grow` root executes, then a later `struct.set` overwrites field `0`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-block-call-indirect-growth.wat \
  -S -o .tmp/hso-probe-block-call-indirect-growth.opt.wat

grep -n "call_indirect\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-block-call-indirect-growth.opt.wat
```

Grep evidence:

```text
9:   (struct.new $pair
11:     (call_indirect $0 (type $callee)
19:   (memory.grow
23:  (struct.set $pair 0
34:   (struct.new $pair
36:     (call_indirect $0 (type $callee)
44:   (table.grow $0
49:  (struct.set $pair 0
```

Binaryen preserves the block-wrapped indirect call, the intervening growth root, and the later `struct.set` for both probed shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps block-wrapped call_indirect constructor operands before unrelated growth roots`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'block-wrapped call_indirect constructor operands'
```

Result: `305/305` passed after adding the coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only block-wrapped `call_indirect` constructor operands before unrelated `memory.grow` and `table.grow` roots. It does not close arbitrary wrapper forms, indirect-call old-field wrappers, descriptor interactions, branch/catch wrappers, or all growth/control roots.

## Reopening criteria

Reopen if Binaryen changes this block-wrapped `call_indirect` growth-root boundary, if Starshine starts dropping or moving the indirect call across the intervening growth root, or if a future source-backed rule proves a narrower safe fold that preserves both the indirect-call effect and growth-root ordering.
