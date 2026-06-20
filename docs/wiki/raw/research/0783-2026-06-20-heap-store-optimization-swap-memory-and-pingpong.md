---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0781-2026-06-20-heap-store-optimization-swap-constructor-global.md
  - ./0782-2026-06-20-heap-store-optimization-immutable-descriptor-swap.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` swap memory and constructor-ping-pong coverage

Question: after the `0781` / `0782` swap-effect fixes, does Starshine have focused coverage for broader `trySwap(...)` constructor operands and the constructor-ping-pong boundary in Binaryen `version_130`?

## Finding

This slice did not find a new Starshine behavior gap. It added focused tests for three source-backed `trySwap(...)` subfamilies that were previously only indirectly covered:

1. A non-trapping constructor operand such as `memory.size` can move with the constructor across an unrelated `global.set`, allowing the later `struct.set` to fold.
2. A potentially trapping constructor operand such as `i32.load` must remain before even an unrelated `global.set`; the later `struct.set` remains.
3. An intervening `local.set` of another `struct.new_default` does not let the first constructor fold through the constructor-ping-pong shape; Binaryen may reorder the second constructor relative to the later `struct.set`, but the first `struct.set` is retained in a single HSO run.

Agent classification: Starshine now has explicit coverage matching the probed Binaryen `version_130` behavior for these subfamilies. This is coverage closure, not a behavior-changing implementation slice.

## Binaryen probes

### `memory.size` constructor operand across unrelated `global.set`

Input shape:

```wat
(local.set $x
  (struct.new $S
    (memory.size)
    (i32.const 2)))
(global.set $g (i32.const 9))
(struct.set $S 1 (local.get $x) (i32.const 7))
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-swap-memory-size-global-set.wat \
  -o .tmp/hso-probe-swap-memory-size-global-set.opt.wat
```

Observed output moves `global.set` before the rewritten constructor, keeps `memory.size` as a constructor operand, and removes `struct.set`.

### trapping `i32.load` constructor operand before unrelated `global.set`

Input shape:

```wat
(local.set $x
  (struct.new $S
    (i32.load (i32.const 0))
    (i32.const 2)))
(global.set $g (i32.const 9))
(struct.set $S 1 (local.get $x) (i32.const 7))
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-swap-memory-read-global-set.wat \
  -o .tmp/hso-probe-swap-memory-read-global-set.opt.wat
```

Observed output retains `struct.set`: Binaryen does not move the potentially trapping constructor operand past the side-effecting `global.set`.

### intervening constructor local-set / ping-pong boundary

Input shape:

```wat
(local.set $a (struct.new_default $S))
(local.set $b (struct.new_default $S))
(struct.set $S 0 (local.get $a) (i32.const 7))
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-swap-pingpong.wat \
  -o .tmp/hso-probe-swap-pingpong.opt.wat
```

Observed output retains `struct.set`. Binaryen reordered the second constructor local-set after the `struct.set`, but did not fold the first constructor through the intervening constructor-local-set in that pass invocation.

## Starshine tests added

Focused tests added to `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds memory.size constructor operands across unrelated global.set`
- `heap-store-optimization keeps trapping memory loads before unrelated global.set`
- `heap-store-optimization does not fold through an intervening constructor local.set`

A small helper fixture was added for modules that need both memory and a mutable i32 global.

Focused validation:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 57, passed: 57, failed: 0.
```

Because the new tests passed before any implementation change, no native rebuild or 10000-case direct compare was required for this coverage-only slice under the pass workflow. HSO-G remains open for broader table and descriptor operand expressions, final-element no-swap coverage, HOT wrapper peeling/flattening drift, and any unprobed effect combinations.
