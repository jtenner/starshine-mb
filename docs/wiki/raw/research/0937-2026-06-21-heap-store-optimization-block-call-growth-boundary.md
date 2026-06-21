# Heap-store-optimization block-wrapped direct-call growth boundaries

Date: 2026-06-21

## Question

Do the block-wrapped ordinary direct-call no-fold boundaries from `0936` also apply when the unrelated intervening root is `memory.grow` or `table.grow`?

## Probes

Local oracle: `wasm-opt version 130 (version_130)`.

Fixture:

- `.tmp/hso-probe-block-call-growth.wat`

Shape: field `0` is produced by a `block (result i32)` containing `call $helper`, then an unrelated `memory.grow` or `table.grow` root executes, then a later `struct.set` overwrites field `0`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-block-call-growth.wat \
  -S -o .tmp/hso-probe-block-call-growth.opt.wat

grep -n "call\|memory.grow\|table.grow\|struct.new\|struct.set" \
  .tmp/hso-probe-block-call-growth.opt.wat
```

Grep evidence:

```text
8: (func $block_call_ctor_memory_grow (type $1)
11:   (struct.new $pair
13:     (call $helper
21:   (memory.grow
25:  (struct.set $pair 0
35: (func $block_call_ctor_table_grow (type $1)
38:   (struct.new $pair
40:     (call $helper
48:   (table.grow $0
53:  (struct.set $pair 0
```

Binaryen preserves the block-wrapped direct call, the intervening growth root, and the later `struct.set` for both probed shapes.

## Starshine result

Added focused HSO-D/G coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps block-wrapped call constructor operands before unrelated growth roots`

Starshine already matched Binaryen. Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'block-wrapped call constructor operands'
```

Result: `303/303` passed after adding the coverage.

## Classification

Coverage-only Binaryen parity boundary. No implementation changed, so no native rebuild or direct compare was required.

This closes only block-wrapped ordinary direct-call constructor/old-field operands before unrelated `memory.grow` and `table.grow` roots; it does not close arbitrary wrapper forms, descriptor interactions, branch/catch wrappers, or all growth/mutable roots.

## Reopening criteria

Reopen if Binaryen changes this block-wrapped direct-call growth-root boundary, if Starshine starts dropping or moving the call across the intervening growth root, or if a future source-backed rule proves a narrower safe fold that preserves both the direct-call effect and growth-root ordering.
