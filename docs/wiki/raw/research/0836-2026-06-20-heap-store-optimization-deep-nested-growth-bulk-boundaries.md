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
  - ./0835-2026-06-20-heap-store-optimization-nested-wrapped-growth-bulk-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` deep nested growth/bulk boundaries

Question: after `0835` covered two-level nested mixed wrappers around bulk-memory and bulk-table roots, does Binaryen `version_130` still keep the no-fold boundary when those same-effect-family roots are hidden under one more HOT wrapper layer?

## Answer

Yes for the probed `version_130` shapes. Local Binaryen probes kept the later `struct.set` for:

- `memory.grow $m` before `block(block(if ...))`, `if(block(block ...))`, and `loop(block(block ...))` wrappers around `memory.fill $m`;
- `memory.grow $m` before the same deep wrappers around `memory.copy $m $m`;
- `table.grow $t` before the same deep wrappers around `table.fill $t`; and
- `table.grow $t` before the same deep wrappers around `table.copy $t $t`.

Starshine already matched all twelve deep nested-wrapper bulk boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Representative `block(block(if ...))` memory-fill probe:

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
      (block
        (if (i32.const 1)
          (then
            (i32.const 0)
            (i32.const 9)
            (i32.const 1)
            (memory.fill $m)))))
    (local.get $x)
    (i32.const 7)
    (struct.set $pair 1)
    (local.get $x)
    (struct.get $pair 1)))
```

Representative `loop(block(block ...))` table-copy probe:

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
        (block
          (i32.const 0)
          (i32.const 4)
          (i32.const 1)
          (table.copy $t $t))))
    (local.get $x)
    (i32.const 7)
    (struct.set $pair 1)
    (local.get $x)
    (struct.get $pair 1)))
```

Commands:

```sh
python3 - <<'PY'
# Generated the 12 fixtures under .tmp/hso-growth-bulk-deep-nested-probe,
# then ran wasm-opt on each fixture.
PY
for f in .tmp/hso-growth-bulk-deep-nested-probe/*.wat; do
  wasm-opt --all-features --heap-store-optimization -S "$f" -o "${f%.wat}.opt.wat"
done
grep -L "struct.set" .tmp/hso-growth-bulk-deep-nested-probe/*.opt.wat || true
```

Observed result: all twelve optimized outputs preserved the constructor `memory.grow` / `table.grow` operand, the deep wrapped bulk root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory-growing constructors before deep nested wrapped memory.fill`
- `heap-store-optimization keeps memory-growing constructors before deep nested wrapped memory.copy`
- `heap-store-optimization keeps table-growing constructors before deep nested wrapped table.fill`
- `heap-store-optimization keeps table-growing constructors before deep nested wrapped table.copy`

Each test iterates the same three deep wrapper shapes: `block(block(if ...))`, `if(block(block ...))`, and `loop(block(block ...))`. These tests check that Starshine keeps `struct.set` when a fold would move a side-effecting constructor memory/table-growth operand across same-effect-family bulk-memory or bulk-table roots hidden under deeper HOT wrappers.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 181, passed: 181, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` wrapper drift coverage from two-level nested mixed-wrapper growth/bulk barriers to deeper three-level wrapper variants.
- Confirms Binaryen `version_130` keeps the no-fold boundary for `block(block(if ...))`, `if(block(block ...))`, and `loop(block(block ...))` wrapped `memory.fill`, `memory.copy`, `table.fill`, and `table.copy` roots when the constructor operand itself grows the same memory/table family.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, branch-containing wrapper variants if expressible, final direct compare, and O4z slot evidence.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
