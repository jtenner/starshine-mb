---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0813-2026-06-20-heap-store-optimization-wrapped-constructor-pingpong.md
  - ./0837-2026-06-20-heap-store-optimization-branch-wrapper-global-swap.md
  - ./0838-2026-06-20-heap-store-optimization-branch-wrapper-table-global-swap.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` branch-wrapper constructor ping-pong coverage

Question: after `0813` proved that Binaryen folds through branchless wrappers around unrelated constructor `local.set` roots, do branch-containing wrappers around the same constructor ping-pong roots still fold under Binaryen `version_130`?

## Answer

Yes for the three probed `version_130` shapes. Binaryen folded the later `struct.set` into the original constructor while preserving the unrelated constructor assignment and the branch when the intervening root was:

- a `block` that performs `local.set $b (struct.new_default $pair)` and then `br`s to the block end;
- a `block` containing an `if` arm that performs that constructor `local.set` and branches to the outer block end;
- a `block` containing a `loop` body that performs that constructor `local.set` and branches to the outer block end.

This extends the constructor ping-pong distinction from `0813`: a direct intervening constructor `local.set` root still blocks the fold, but block/if/loop wrappers around unrelated constructor assignments are fold positives even when the wrapper contains a branch that exits only the wrapper.

Starshine already matched these Binaryen positives, so this slice added focused coverage only and did not change HSO implementation code.

## Binaryen probes

Representative branch-containing constructor wrapper probe:

```wat
(module
  (type $pair (struct (field (mut i32))))
  (func $f (result i32)
    (local $a (ref null $pair)) (local $b (ref null $pair))
    (local.set $a (struct.new_default $pair))
    (block $blk
      (loop $loop
        (local.set $b (struct.new_default $pair))
        (br $blk)))
    (struct.set $pair 0 (local.get $a) (i32.const 7))
    (struct.get $pair 0 (local.get $a)))
)
```

Commands:

```sh
for f in .tmp/hso-branch-wrapper-constructor-pingpong-probe/*.wat; do
  wasm-opt --all-features --heap-store-optimization -S "$f" -o - |
    grep -E 'struct\.set|struct\.new_default|local\.set|br ' || true
done
```

Observed result: all three optimized outputs preserved the unrelated `struct.new_default` / `local.set` wrapper and branch, moved or retained the original constructor materialization as needed, and removed the later `struct.set`.

## Local coverage

Added focused test:

- `heap-store-optimization folds across branch-containing constructor local.set wrappers`

The test iterates the same block, if, and loop branch-containing wrapper shapes and checks that Starshine preserves the constructor assignment and branch while removing `struct.set`.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 185, passed: 185, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` branch-containing wrapper coverage from unrelated global writes to unrelated constructor ping-pong roots.
- Keeps the direct-root constructor ping-pong no-fold boundary from `0783` / `0813` intact while covering another wrapper-peeling positive family.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, additional HOT wrapper variants, final direct compare, and O4z slot evidence.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
