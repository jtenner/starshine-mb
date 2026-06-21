# Heap-store-optimization block-wrapped direct-call store boundaries

Date: 2026-06-21

## Question

Do the ordinary direct-call constructor/old-field no-fold boundaries from `0928`/`0929` still apply when the effectful direct call is wrapped in a value-producing `block` before an unrelated `i32.store` or `table.set` root?

## Probes

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture:

- `.tmp/hso-probe-block-call-store.wat`

Shape: field `0` is produced by a `block (result i32)` containing `call $helper`, then an unrelated `i32.store` or `table.set` root executes, then a later `struct.set` overwrites field `0`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-block-call-store.wat \
  -S -o .tmp/hso-probe-block-call-store.opt.wat

grep -n "call\|i32.store\|table.set\|struct.new\|struct.set" \
  .tmp/hso-probe-block-call-store.opt.wat
```

Grep evidence:

```text
8: (func $block_call_ctor_i32_store (type $1)
11:   (struct.new $pair
13:     (call $helper
20:  (i32.store
24:  (struct.set $pair 0
34: (func $block_call_ctor_table_set (type $1)
37:   (struct.new $pair
39:     (call $helper
46:  (table.set $0
50:  (struct.set $pair 0
```

Binaryen preserves the block-wrapped direct call, the intervening store root, and the later `struct.set` for both probed shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps block-wrapped call constructor operands before unrelated stores`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'block-wrapped call constructor operands'
```

Result: `302/302` passed after adding the coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only block-wrapped ordinary direct-call constructor/old-field operands before unrelated `i32.store` and `table.set` roots; it does not close arbitrary wrapper forms, descriptor interactions, branch/catch wrappers, or all mutable roots.

## Reopening criteria

Reopen if Binaryen changes this block-wrapped direct-call store-root boundary, if Starshine starts dropping or moving the call across the intervening store root, or if a future source-backed rule proves a narrower safe fold that preserves both the direct-call effect and store-root ordering.
