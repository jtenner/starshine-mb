# Heap-store-optimization table.copy old-field boundary

Date: 2026-06-21

## Question

How does Binaryen `version_130` handle an overwritten constructor field whose value-producing block performs `table.copy` before yielding the original field value, when an unrelated mutable `global.set` root appears before the later `struct.set`?

This is the table-side counterpart to the `memory.copy` old-field probe in `0906` and further narrows HSO-D/G old-field side-effect behavior.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe file: `.tmp/hso-probe-copy-init-old-field.wat`.

Relevant `table_copy` shape:

```wat
(func (export "table_copy") (result i32)
  (local $p (ref $pair))
  (local.set $p
    (struct.new $pair
      (block (result i32)
        (table.copy (i32.const 0) (i32.const 4) (i32.const 1))
        (i32.const 2)
      )
      (i32.const 3)))
  (global.set $g0 (i32.const 9))
  (struct.set $pair 0 (local.get $p) (i32.const 42))
  (struct.get $pair 0 (local.get $p)))
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-copy-init-old-field.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-copy-init-old-field.opt.wat
```

## Binaryen result

Binaryen preserved all relevant roots in `table_copy`:

- constructor `local.set` with `struct.new`
- old-field value-producing block containing `table.copy`
- intervening unrelated `global.set`
- later `struct.set`

The optimized text still has `table.copy`, `global.set`, and `struct.set` in that function.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps old field table.copy before unrelated global write`

The test asserts the optimized Starshine output still contains `table.copy`, `global.set`, and `struct.set`.

## Classification

Binaryen behavior-parity negative/boundary. This is not a Starshine win.

In this specific unrelated-global-write shape, `table.copy` behaves like `memory.copy` and the existing memory/table store plus memory/table fill old-field boundaries, not like the growth/passive-drop old-field positives.

Do not generalize this to every side-effectful old field. Existing evidence still distinguishes:

- fold with side-effect preservation: memory/table growth, unrelated global writes, `data.drop`, `elem.drop`
- no-fold boundary: memory/table stores, memory/table fills, `memory.copy`, and now `table.copy`

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `265/265`.

No native `src/cmd` rebuild or direct 10000-case compare was required for this coverage-only slice because Starshine already matched the probed Binaryen behavior and no implementation changed.

## Backlog impact

HSO-D/G remain open. This closes only the narrow `table.copy` old-field no-fold boundary in the probed unrelated mutable `global.set` shape.
