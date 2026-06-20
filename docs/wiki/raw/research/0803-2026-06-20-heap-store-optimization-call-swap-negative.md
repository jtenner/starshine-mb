---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0802-2026-06-20-heap-store-optimization-memory-grow-swap.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` call constructor operand swap negative

Question: does Binaryen `version_130` allow `trySwap(...)` to move a fresh `local.set(struct.new ...)` whose constructor operand is a call across an unrelated mutable `global.set` to reach a later `struct.set`?

## Answer

No. A local Binaryen `version_130` probe kept the later `struct.set` when the fresh constructor's first field operand was a `call`, even when the call was a trivial defined helper returning a constant and the intervening root was only an unrelated mutable `global.set`.

A second probe with an imported helper call showed the same no-fold behavior. This means the already-covered positive swap family for `memory.size`, `memory.grow`, `table.size`, and `table.grow` should not be generalized to call-valued constructor operands. Calls remain an effect-ordering barrier for this `trySwap(...)` surface.

Starshine already matched this negative. This slice added focused coverage only; no implementation code changed.

## Binaryen probe

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (global $g (mut i32) (i32.const 0))
  (func $pure (result i32) (i32.const 1))
  (func (export "f") (result i32)
    (local $x (ref null $pair))
    (local.set $x
      (struct.new $pair
        (call $pure)
        (i32.const 2)))
    (global.set $g (i32.const 9))
    (struct.set $pair 0
      (local.get $x)
      (i32.const 42))
    (struct.get $pair 0 (local.get $x)))
)
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-call-swap-probe/call-global-set.wat \
  -o .tmp/hso-call-swap-probe/call-global-set.opt.wat
```

Observed output kept the constructor call before the global write and retained the later `struct.set`; no fold occurred.

Imported-call variant command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-call-swap-probe/import-call-global-set.wat \
  -o .tmp/hso-call-swap-probe/import-call-global-set.opt.wat
```

Observed output also retained the later `struct.set`.

## Local coverage

Added focused test:

- `heap-store-optimization keeps call constructor operands before unrelated global.set`

The test builds an imported-call fixture with a mutable global, runs the direct pass, and asserts that the call, `global.set`, and `struct.set` all remain, with `global.set` still before `struct.set`.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result after fixing the fixture signature:

```text
Total tests: 87, passed: 87, failed: 0.
```

## Audit impact

- Narrows `[O4Z-AUDIT-HSO-G]`: constructor operands with memory/table grow/size effects can cross an unrelated mutable `global.set`, but call-valued constructor operands do not.
- Confirms Starshine does not overgeneralize the recent swap positives.
- No direct compare or native rebuild was run because this was coverage-only documentation of behavior Starshine already matched.

Remaining HSO-G work still includes broader swap operands/effects, constructor ping-pong variants, and HOT wrapper peeling / flattening drift.
