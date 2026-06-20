---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0820-2026-06-20-heap-store-optimization-memory-size-data-segment-boundaries.md
  - ./0821-2026-06-20-heap-store-optimization-table-size-elem-boundaries.md
  - ./0829-2026-06-20-heap-store-optimization-wrapped-bulk-fill-boundaries.md
  - ./0831-2026-06-20-heap-store-optimization-wrapped-copy-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` wrapped passive segment boundaries

Question: after direct passive-segment boundaries and wrapped bulk-fill/copy boundaries were covered, does Binaryen `version_130` also keep the no-fold boundary when a same-effect-family passive data/element operation is hidden under a block, if, or branchless loop wrapper?

## Answer

Yes for the probed `version_130` shapes. Local Binaryen probes kept the later `struct.set` for:

- `memory.size $m` before block-, if-, and loop-wrapped `memory.init $d`;
- `memory.size $m` before block-, if-, and loop-wrapped `data.drop $d`;
- `table.size $t` before block-, if-, and loop-wrapped `table.init $e`; and
- `table.size $t` before block-, if-, and loop-wrapped `elem.drop $e`.

Starshine already matched all twelve boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Representative block-wrapped memory-init probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $m 1 1)
  (data $d "x")
  (func $f (result i32)
    (local $s (ref null $pair))
    (local.set $s
      (struct.new $pair
        (memory.size $m)
        (i32.const 2)))
    (block
      (memory.init $d (i32.const 0) (i32.const 0) (i32.const 1)))
    (struct.set $pair 1 (local.get $s) (i32.const 7))
    (struct.get $pair 1 (local.get $s))))
```

Representative loop-wrapped elem-drop probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 2 2 funcref)
  (elem $e funcref)
  (func $f (result i32)
    (local $s (ref null $pair))
    (local.set $s
      (struct.new $pair
        (table.size $t)
        (i32.const 2)))
    (loop
      (elem.drop $e))
    (struct.set $pair 1 (local.get $s) (i32.const 7))
    (struct.get $pair 1 (local.get $s))))
```

Commands:

```sh
for f in .tmp/hso-passive-wrapper-probe/*.wat; do
  o=${f%.wat}.opt.wat
  wasm-opt --all-features --heap-store-optimization -S "$f" -o "$o"
done
```

Observed result: all twelve optimized outputs preserved the constructor `memory.size` / `table.size` operand, the wrapped passive data/element root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory.size constructors before block-wrapped memory.init`
- `heap-store-optimization keeps memory.size constructors before if-wrapped memory.init`
- `heap-store-optimization keeps memory.size constructors before loop-wrapped memory.init`
- `heap-store-optimization keeps memory.size constructors before block-wrapped data.drop`
- `heap-store-optimization keeps memory.size constructors before if-wrapped data.drop`
- `heap-store-optimization keeps memory.size constructors before loop-wrapped data.drop`
- `heap-store-optimization keeps table.size constructors before block-wrapped table.init`
- `heap-store-optimization keeps table.size constructors before if-wrapped table.init`
- `heap-store-optimization keeps table.size constructors before loop-wrapped table.init`
- `heap-store-optimization keeps table.size constructors before block-wrapped elem.drop`
- `heap-store-optimization keeps table.size constructors before if-wrapped elem.drop`
- `heap-store-optimization keeps table.size constructors before loop-wrapped elem.drop`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor memory/table-size operand across same-effect-family passive data/element roots hidden under simple structured wrappers.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 149, passed: 149, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` wrapper drift coverage from bulk fill and copy roots to passive init/drop roots for same-effect-family memory/table-size boundaries.
- Confirms Binaryen `version_130` keeps the no-fold boundary for block-, if-, and branchless loop-wrapped `memory.init`, `data.drop`, `table.init`, and `elem.drop` roots when the constructor operand observes the same memory/table family.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, other wrapper variants, final direct compare, and O4z slot evidence.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
