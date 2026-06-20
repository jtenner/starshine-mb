---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0814-2026-06-20-heap-store-optimization-nested-wrapper-swap.md
  - ./0833-2026-06-20-heap-store-optimization-wrapped-growth-passive-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` nested wrapped growth/passive boundaries

Question: after simple block/if/branchless-loop wrappers were covered for side-effecting growth/passive roots, does Binaryen `version_130` also keep the no-fold boundary when the same passive root is hidden under nested mixed wrappers such as `block(if ...)`, `if(block ...)`, and `loop(block ...)`?

## Answer

Yes for the probed `version_130` shapes. Local Binaryen probes kept the later `struct.set` for:

- `memory.grow $m` before `block(if ...)`, `if(block ...)`, and `loop(block ...)` wrappers around `memory.init $d`;
- `memory.grow $m` before the same nested wrappers around `data.drop $d`;
- `table.grow $t` before the same nested wrappers around `table.init $e`; and
- `table.grow $t` before the same nested wrappers around `elem.drop $e`.

Starshine already matched all twelve nested-wrapper boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Representative `block(if ...)` memory-init probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $m 1 2)
  (data $d "x")
  (func $f (result i32)
    (local $s (ref null $pair))
    (local.set $s
      (struct.new $pair
        (memory.grow $m (i32.const 1))
        (i32.const 2)))
    (block
      (if (i32.const 1)
        (then
          (memory.init $d (i32.const 0) (i32.const 0) (i32.const 1)))))
    (struct.set $pair 1 (local.get $s) (i32.const 7))
    (struct.get $pair 1 (local.get $s))))
```

Representative `loop(block ...)` elem-drop probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 2 4 funcref)
  (elem $e funcref)
  (func $f (result i32)
    (local $s (ref null $pair))
    (local.set $s
      (struct.new $pair
        (table.grow $t (ref.null func) (i32.const 1))
        (i32.const 2)))
    (loop
      (block
        (elem.drop $e)))
    (struct.set $pair 1 (local.get $s) (i32.const 7))
    (struct.get $pair 1 (local.get $s))))
```

Commands:

```sh
for f in .tmp/hso-growth-passive-nested-wrapper-probe/*.wat; do
  wasm-opt --all-features --heap-store-optimization -S "$f" -o "${f%.wat}.opt.wat"
done
grep -L "struct.set" .tmp/hso-growth-passive-nested-wrapper-probe/*.opt.wat || true
```

Observed result: all twelve optimized outputs preserved the constructor `memory.grow` / `table.grow` operand, the nested wrapped passive data/element root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory-growing constructors before block-if-wrapped memory.init`
- `heap-store-optimization keeps memory-growing constructors before if-block-wrapped memory.init`
- `heap-store-optimization keeps memory-growing constructors before loop-block-wrapped memory.init`
- `heap-store-optimization keeps memory-growing constructors before block-if-wrapped data.drop`
- `heap-store-optimization keeps memory-growing constructors before if-block-wrapped data.drop`
- `heap-store-optimization keeps memory-growing constructors before loop-block-wrapped data.drop`
- `heap-store-optimization keeps table-growing constructors before block-if-wrapped table.init`
- `heap-store-optimization keeps table-growing constructors before if-block-wrapped table.init`
- `heap-store-optimization keeps table-growing constructors before loop-block-wrapped table.init`
- `heap-store-optimization keeps table-growing constructors before block-if-wrapped elem.drop`
- `heap-store-optimization keeps table-growing constructors before if-block-wrapped elem.drop`
- `heap-store-optimization keeps table-growing constructors before loop-block-wrapped elem.drop`

These tests check that Starshine keeps `struct.set` when a fold would move a side-effecting constructor memory/table-growth operand across same-effect-family passive data/element roots hidden under nested HOT wrappers.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 173, passed: 173, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` wrapper drift coverage from simple wrapped growth/passive barriers to nested mixed-wrapper growth/passive barriers.
- Confirms Binaryen `version_130` keeps the no-fold boundary for `block(if ...)`, `if(block ...)`, and `loop(block ...)` wrapped `memory.init`, `data.drop`, `table.init`, and `elem.drop` roots when the constructor operand itself grows the same memory/table family.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, other HOT wrapper variants, final direct compare, and O4z slot evidence.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
