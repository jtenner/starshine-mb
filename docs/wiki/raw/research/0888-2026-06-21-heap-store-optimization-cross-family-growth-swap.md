# Heap-store-optimization cross-family growth swap

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold fresh-struct `struct.set` chains when the constructor operand is a readonly size query for one index space and the intervening root grows the other index space?

The covered cross-family ordinary-store cases (`0844`/`0845`/`0846`) proved that `memory.size` can cross table stores and `table.size` can cross linear-memory stores. This slice checks the side-effecting growth counterpart:

- `memory.size` constructor operand across `table.grow`
- `table.size` constructor operand across `memory.grow`

## Binaryen oracle

Local oracle:

```sh
wasm-opt --version
```

Result:

```text
wasm-opt version 130 (version_130)
```

Probe fixture written to `.tmp/hso-probe-cross-family-growth-swap.wat`:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 1 funcref)
  (memory $m 1)
  (func $memory_size_crosses_table_grow (result i32)
    (local $s (ref null $pair))
    (memory.size $m)
    (i32.const 0)
    (struct.new $pair)
    (local.set $s)
    (ref.null func)
    (i32.const 1)
    (table.grow $t)
    (drop)
    (local.get $s)
    (i32.const 7)
    (struct.set $pair 1)
    (local.get $s)
    (struct.get $pair 1))
  (func $table_size_crosses_memory_grow (result i32)
    (local $s (ref null $pair))
    (table.size $t)
    (i32.const 0)
    (struct.new $pair)
    (local.set $s)
    (i32.const 1)
    (memory.grow $m)
    (drop)
    (local.get $s)
    (i32.const 9)
    (struct.set $pair 1)
    (local.get $s)
    (struct.get $pair 1)))
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-cross-family-growth-swap.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-cross-family-growth-swap.opt.wat \
  && grep -E "func|memory.size|table.size|memory.grow|table.grow|struct.new|struct.set|i32.const|drop" \
    .tmp/hso-probe-cross-family-growth-swap.opt.wat
```

Relevant result:

```text
 (func $memory_size_crosses_table_grow (type $1) (result i32)
  (drop
   (table.grow $t
    (ref.null nofunc)
    (i32.const 1)
   (struct.new $pair
    (memory.size)
    (i32.const 7)
 (func $table_size_crosses_memory_grow (type $1) (result i32)
  (drop
   (memory.grow
    (i32.const 1)
   (struct.new $pair
    (table.size $t)
    (i32.const 9)
```

Binaryen preserves the growth roots, folds both later `struct.set` values into the constructors, and removes the `struct.set` roots.

## Interpretation

Binaryen's `trySwap(...)` legality is resource-sensitive for these families. A readonly memory query can cross a table growth root, and a readonly table query can cross a memory growth root. Same-family growth/store/bulk/passive barriers from `0815` through `0843` remain no-fold boundaries; this slice only covers cross-family memory/table growth.

## Starshine coverage

Added focused tests:

- `src/passes/heap_store_optimization_test.mbt`
  - `heap-store-optimization folds memory.size constructors across table.grow roots`
  - `heap-store-optimization folds table.size constructors across memory.grow roots`

Both tests use the existing memory/table fixture, assert that the growth root remains in the optimized function, and assert that the later `struct.set` is removed.

## Validation

Focused command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 246, passed: 246, failed: 0.
```

The new focused tests passed on the first run. This slice was coverage-only: Starshine already matched Binaryen, no implementation behavior changed, and no native rebuild or direct compare was required.

## Classification

- HSO-G coverage-only progress.
- Binaryen behavior: fold cross-family memory/table size-vs-growth swap shapes while preserving the growth root.
- Starshine behavior: already matches.
- Not a Starshine-vs-Binaryen divergence.

## Reopening criteria

Reopen this family if:

- Binaryen changes `trySwap(...)` resource ordering for cross-family memory/table growth roots;
- Starshine starts preserving `struct.set` for these cross-family shapes without a documented Starshine win;
- broader effect-summary work accidentally treats all growth roots as same-family barriers or, conversely, weakens the same-family no-fold boundaries covered by `0815` through `0843`.
