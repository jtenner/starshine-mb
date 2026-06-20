---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` memory.size / data-segment swap boundaries

Question: after `0819` showed that Binaryen keeps `struct.set` when a constructor `memory.size` operand would cross `memory.fill` or `memory.copy`, does the same no-fold boundary apply to passive data-segment roots such as `memory.init` and `data.drop`?

## Answer

Yes. Local Binaryen `version_130` probes kept the later `struct.set` for both shapes:

- a constructor `memory.size` operand before an intervening `memory.init`; and
- a constructor `memory.size` operand before an intervening `data.drop`.

The `memory.init` result matches the same-kind memory read/write boundary from `0819`. The `data.drop` result is a useful granularity detail: even though the root mutates a passive data segment rather than linear memory contents, Binaryen `version_130` still does not fold the later store through it in this shape. Starshine already matched both boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Memory-init probe:

```wat
(module
  (type $p (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (data $d "abc")
  (func $f (result i32)
    (local $x (ref null $p))
    (local.set $x
      (struct.new $p
        (memory.size)
        (i32.const 2)))
    (memory.init $d (i32.const 0) (i32.const 0) (i32.const 1))
    (struct.set $p 1 (local.get $x) (i32.const 7))
    (struct.get $p 1 (local.get $x)))
)
```

Data-drop probe:

```wat
(module
  (type $p (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (data $d "abc")
  (func $f (result i32)
    (local $x (ref null $p))
    (local.set $x
      (struct.new $p
        (memory.size)
        (i32.const 2)))
    (data.drop $d)
    (struct.set $p 1 (local.get $x) (i32.const 7))
    (struct.get $p 1 (local.get $x)))
)
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-size-memory-init-blocker.wat \
  -o .tmp/hso-slice-probe/memory-size-memory-init-blocker.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-size-data-drop-cross.wat \
  -o .tmp/hso-slice-probe/memory-size-data-drop-cross.opt.wat
```

Observed result: both optimized outputs preserved the constructor `memory.size` operand, the intervening `memory.init` / `data.drop` root, and the later `struct.set`.

## Local coverage

Added a small passive-data test helper and focused tests:

- `heap-store-optimization keeps memory.size constructors before memory.init`
- `heap-store-optimization keeps memory.size constructors before data.drop`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor `memory.size` operand across passive data-segment operations.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 107, passed: 107, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` swap legality coverage from `memory.fill` / `memory.copy` to passive data-segment operations.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper drift.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
