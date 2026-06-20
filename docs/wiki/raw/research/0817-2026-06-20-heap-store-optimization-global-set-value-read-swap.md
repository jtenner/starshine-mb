---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0816-2026-06-20-heap-store-optimization-unrelated-global-swap.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
---

# `heap-store-optimization` global-set value-read swap coverage

## Question

Does Binaryen `version_130` still fold when a constructor operand reads `global.get $a`, the intervening unrelated `global.set $b` also reads `$a` as its value, and the later `struct.set` targets the fresh struct?

This is a narrower follow-up to `0816`, which fixed Starshine's coarse mutable-global swap legality so constructor `global.get $a` may cross `global.set $b` when `$a != $b`.

## Answer

Yes. A local `wasm-opt version_130` probe folded the later `struct.set`: the optimized output preserved the `global.set $b (global.get $a)` side effect, preserved the constructor `global.get $a`, moved the global write before the rewritten constructor, and removed `struct.set`.

Starshine already matched this behavior after the `0816` global-granularity fix. This slice added focused coverage only; no implementation code changed.

## Probe

Input shape:

```wat
(module
  (type $pair (struct (field (mut i32)) (field (mut i32))))
  (global $a (mut i32) (i32.const 11))
  (global $b (mut i32) (i32.const 22))
  (func (result i32)
    (local $p (ref null $pair))
    (local.set $p
      (struct.new $pair
        (global.get $a)
        (i32.const 2)))
    (global.set $b
      (global.get $a))
    (struct.set $pair 1
      (local.get $p)
      (i32.const 7))
    (struct.get $pair 1
      (local.get $p)))
)
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/global-read-unrelated-global-set-value-read.wat \
  -o .tmp/hso-slice-probe/global-read-unrelated-global-set-value-read.opt.wat
```

Observed optimized evidence:

```text
(global.set $b
 (global.get $a)
 ...
 (struct.new $pair
  (global.get $a)
```

There was no `struct.set` in the optimized output.

## Starshine coverage

Added focused test:

- `heap-store-optimization folds constructor global.get across unrelated global.set value read`

The test constructs:

1. `struct.new(pair, global.get 0, i32.const 2)` assigned to the fresh local,
2. `global.set 1 (global.get 0)` as the intervening unrelated global write whose value also reads `$a`,
3. a later `struct.set` to field 1 of the fresh local.

Expected behavior: preserve `global.get` and `global.set`, fold the stored value into the constructor, and remove `struct.set`.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 102, passed: 102, failed: 0.
```

This was coverage-only. No native rebuild or direct 10000-case compare was required because no implementation behavior changed.

## Audit impact

- HSO-G swap legality has one more mutable-global value-expression variant covered.
- The same-global conflict boundary from `0781` and unrelated-global fold from `0816` remain the core granularity contract.
- Broader swap operands/effects and additional HOT wrapper drift remain open.
