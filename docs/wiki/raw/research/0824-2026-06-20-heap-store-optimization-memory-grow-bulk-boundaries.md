---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0819-2026-06-20-heap-store-optimization-memory-size-memory-bulk-boundaries.md
  - ./0823-2026-06-20-heap-store-optimization-memory-grow-data-boundaries.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` memory.grow / memory-bulk swap boundaries

Question: after `0819` showed that Binaryen keeps `struct.set` when a constructor `memory.size` operand would cross `memory.fill` or `memory.copy`, and `0823` showed the side-effecting `memory.grow` counterpart for passive data roots, does Binaryen also keep the same no-fold boundary for `memory.grow` across memory-bulk writes?

## Answer

Yes. Local Binaryen `version_130` probes kept the later `struct.set` for both shapes:

- a constructor `memory.grow` operand before an intervening `memory.fill`; and
- a constructor `memory.grow` operand before an intervening `memory.copy`.

This completes the currently probed same-kind memory-bulk/data matrix for `memory.size` and `memory.grow`: both constructor operands stay before `memory.fill`, `memory.copy`, `memory.init`, and `data.drop`. Starshine already matched both new boundaries, so this slice added focused negative coverage only and did not change HSO implementation code.

## Binaryen probes

Memory-fill probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (func (result i32)
    (local $p (ref null $pair))
    (local.set $p
      (struct.new $pair
        (memory.grow (i32.const 1))
        (i32.const 2)))
    (memory.fill (i32.const 0) (i32.const 9) (i32.const 1))
    (struct.set $pair 1 (local.get $p) (i32.const 7))
    (struct.get $pair 1 (local.get $p)))
)
```

Memory-copy probe:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (memory 1)
  (func (result i32)
    (local $p (ref null $pair))
    (local.set $p
      (struct.new $pair
        (memory.grow (i32.const 1))
        (i32.const 2)))
    (memory.copy (i32.const 0) (i32.const 4) (i32.const 1))
    (struct.set $pair 1 (local.get $p) (i32.const 7))
    (struct.get $pair 1 (local.get $p)))
)
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-grow-memory-fill-blocker.wat \
  -o .tmp/hso-slice-probe/memory-grow-memory-fill-blocker.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/memory-grow-memory-copy-blocker.wat \
  -o .tmp/hso-slice-probe/memory-grow-memory-copy-blocker.opt.wat
```

Observed result: both optimized outputs preserved the constructor `memory.grow` operand, the intervening `memory.fill` / `memory.copy` root, and the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization keeps memory-growing constructors before memory.fill`
- `heap-store-optimization keeps memory-growing constructors before memory.copy`

These tests check that Starshine keeps `struct.set` when a fold would move a constructor `memory.grow` operand across memory-bulk writes.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 115, passed: 115, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` swap legality coverage for memory-bulk boundaries from `memory.size` to the side-effecting `memory.grow` constructor operand.
- Together with `0823`, records that the probed `memory.grow` same-kind memory roots (`memory.fill`, `memory.copy`, `memory.init`, and `data.drop`) all block folding, matching Binaryen.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects and additional HOT wrapper drift.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
