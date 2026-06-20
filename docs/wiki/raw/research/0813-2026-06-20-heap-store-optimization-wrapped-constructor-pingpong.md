---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0791-2026-06-20-heap-store-optimization-memory-table-blockers.md
  - ./0799-2026-06-20-heap-store-optimization-final-root-no-swap.md
  - ./0812-2026-06-20-heap-store-optimization-loop-wrapped-table-grow-swap.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` wrapped constructor ping-pong coverage

Question: does Binaryen `version_130` treat every intervening `local.set(struct.new*)` as a constructor ping-pong barrier, or only a direct root that `trySwap(...)` sees while scanning the current block list?

## Answer

Only the direct-root shape is a `trySwap(...)` ping-pong barrier. A local Binaryen `version_130` probe folded the later `struct.set` when the intervening constructor assignment was wrapped in `block`, `if`, or branchless `loop`. The optimized output preserved the wrapped assignment to the unrelated local, rebuilt the first constructor after the wrapper, and removed the later `struct.set`.

Starshine already matched this Binaryen behavior. This slice added focused coverage only; no HSO implementation code changed.

## Binaryen probes

Representative block-wrapped probe:

```wat
(module
  (type $pair (struct (field (mut i32))))
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (local $y (ref null $pair))
    (local.set $x (struct.new_default $pair))
    (block
      (local.set $y (struct.new_default $pair)))
    (struct.set $pair 0
      (local.get $x)
      (i32.const 7))
    (struct.get $pair 0 (local.get $x))))
```

Commands:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/block-constructor-pingpong.wat \
  -o .tmp/hso-slice-probe/block-constructor-pingpong.opt.wat
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/if-constructor-pingpong.wat \
  -o .tmp/hso-slice-probe/if-constructor-pingpong.opt.wat
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/loop-constructor-pingpong.wat \
  -o .tmp/hso-slice-probe/loop-constructor-pingpong.opt.wat
```

Observed output for all three wrapper variants retained the wrapped assignment to `$y`, inserted a `nop` cleanup root, rebuilt `$x` with `struct.new $pair (i32.const 7)` after the wrapper, and removed the later `struct.set`. This confirms the source-level ping-pong rejection is narrower than "any nested constructor assignment." The rejection applies when the blocker root itself is a constructor `local.set`.

## Local coverage

Added focused test:

- `heap-store-optimization folds across wrapped constructor local.set roots`

The existing direct-root negative remains:

- `heap-store-optimization does not fold through an intervening constructor local.set`

Together they lock the Binaryen distinction: direct constructor local-set roots remain no-fold ping-pong blockers, but `block`, `if`, and branchless `loop` wrappers with an unrelated constructor assignment are ordinary reorderable roots when their effects do not require the first constructor assignment to stay before them.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 97, passed: 97, failed: 0.
```

## Audit impact

- Narrows `[O4Z-AUDIT-HSO-G]` constructor ping-pong work: the direct-root barrier is already covered, and wrapped unrelated constructor assignments are now covered as Binaryen folds.
- Keeps the broader HSO-G item open for additional swap operands/effects and remaining HOT wrapper drift.
- No direct compare or native rebuild was run because this was coverage-only documentation of behavior Starshine already matched.
