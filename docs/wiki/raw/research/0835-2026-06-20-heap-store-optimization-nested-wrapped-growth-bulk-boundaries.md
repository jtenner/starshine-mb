---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0824-2026-06-20-heap-store-optimization-memory-grow-bulk-boundaries.md
  - ./0825-2026-06-20-heap-store-optimization-table-grow-bulk-boundaries.md
  - ./0834-2026-06-20-heap-store-optimization-nested-wrapped-growth-passive-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` nested wrapped growth/bulk boundaries

Question: after simple block/if/branchless-loop wrappers were covered for bulk-memory and bulk-table roots, and nested mixed wrappers were covered for side-effecting growth/passive roots, does Binaryen `version_130` also keep the no-fold boundary when `memory.fill`, `memory.copy`, `table.fill`, or `table.copy` are hidden under nested mixed wrappers?

## Answer

Yes for the probed `version_130` shapes. Local Binaryen probes kept the later `struct.set` for:

- `memory.grow $m` before `block(if ...)`, `if(block ...)`, and `loop(block ...)` wrappers around `memory.fill $m`;
- `memory.grow $m` before the same nested wrappers around `memory.copy $m $m`;
- `table.grow $t` before the same nested wrappers around `table.fill $t`; and
- `table.grow $t` before the same nested wrappers around `table.copy $t $t`.

Starshine already matched all twelve nested-wrapper bulk boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Representative `block(if ...)` memory-fill probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory $m 1)
  (func $f (result i32)
    (local $x (ref null $pair))
    (i32.const 1)
    (memory.grow $m)
    (i32.const 2)
    (struct.new $pair)
    (local.set $x)
    (block
      (if (i32.const 1)
        (then
          (i32.const 0)
          (i32.const 0)
          (i32.const 1)
          (memory.fill $m))))
    (local.get $x)
    (i32.const 7)
    (struct.set $pair 1)
    (local.get $x)
    (struct.get $pair 1)))
```

Representative `loop(block ...)` table-copy probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (table $t 1 funcref)
  (func $f (result i32)
    (local $x (ref null $pair))
    (ref.null func)
    (i32.const 1)
    (table.grow $t)
    (i32.const 2)
    (struct.new $pair)
    (local.set $x)
    (loop
      (block
        (i32.const 0)
        (i32.const 0)
        (i32.const 1)
        (table.copy $t $t)))
    (local.get $x)
    (i32.const 7)
    (struct.set $pair 1)
    (local.get $x)
    (struct.get $pair 1)))
```

Commands:

```sh
for f in .tmp/hso-growth-bulk-nested-probe/*.wat; do
  wasm-opt --all-features --heap-store-optimization -S "$f" -o "${f%.wat}.opt.wat"
done
grep -L "struct.set" .tmp/hso-growth-bulk-nested-probe/*.opt.wat || true
```

Observed result: all twelve optimized outputs preserved the constructor `memory.grow` / `table.grow` operand, the nested wrapped bulk root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory-growing constructors before nested wrapped memory.fill`
- `heap-store-optimization keeps memory-growing constructors before nested wrapped memory.copy`
- `heap-store-optimization keeps table-growing constructors before nested wrapped table.fill`
- `heap-store-optimization keeps table-growing constructors before nested wrapped table.copy`

Each test iterates the same three nested wrapper shapes: `block(if ...)`, `if(block ...)`, and `loop(block ...)`. These tests check that Starshine keeps `struct.set` when a fold would move a side-effecting constructor memory/table-growth operand across same-effect-family bulk-memory or bulk-table roots hidden under nested HOT wrappers.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 177, passed: 177, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` wrapper drift coverage from nested mixed-wrapper growth/passive barriers to nested mixed-wrapper growth/bulk barriers.
- Confirms Binaryen `version_130` keeps the no-fold boundary for `block(if ...)`, `if(block ...)`, and `loop(block ...)` wrapped `memory.fill`, `memory.copy`, `table.fill`, and `table.copy` roots when the constructor operand itself grows the same memory/table family.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, additional HOT wrapper variants, final direct compare, and O4z slot evidence.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
