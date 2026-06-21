# Heap-store-optimization block-wrapped call_indirect store boundaries

Date: 2026-06-21

## Question

Do the `call_indirect` constructor-operand no-fold boundaries from `0924`/`0926` still apply when the effectful indirect call is wrapped in a value-producing `block` before an unrelated `i32.store` or `table.set` root?

## Probes

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture:

- `.tmp/hso-probe-block-call-indirect-store.wat`

Shape: field `0` is produced by a `block (result i32)` containing `call_indirect`, then an unrelated `i32.store` or `table.set` root executes, then a later `struct.set` overwrites field `0`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-block-call-indirect-store.wat \
  -S -o .tmp/hso-probe-block-call-indirect-store.opt.wat

grep -n "call_indirect\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-block-call-indirect-store.opt.wat
```

Grep evidence:

```text
9:   (struct.new $pair
11:     (call_indirect $0 (type $callee)
18:  (i32.store
22:  (struct.set $pair 0
33:   (struct.new $pair
35:     (call_indirect $0 (type $callee)
42:  (table.set $0
46:  (struct.set $pair 0
```

Binaryen preserves the block-wrapped indirect call, the intervening store root, and the later `struct.set` for both probed shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps block-wrapped call_indirect constructor operands before unrelated stores`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'block-wrapped call_indirect constructor operands'
```

Result: `304/304` passed after adding the coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only block-wrapped `call_indirect` constructor operands before unrelated `i32.store` and `table.set` roots. It does not close arbitrary wrapper forms, indirect-call old-field wrappers, descriptor interactions, branch/catch wrappers, or all mutable roots.

## Reopening criteria

Reopen if Binaryen changes this block-wrapped `call_indirect` store-root boundary, if Starshine starts dropping or moving the indirect call across the intervening store root, or if a future source-backed rule proves a narrower safe fold that preserves both the indirect-call effect and store-root ordering.
