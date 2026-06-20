---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0802-2026-06-20-heap-store-optimization-memory-grow-swap.md
  - ./0814-2026-06-20-heap-store-optimization-nested-wrapper-swap.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` branch-wrapper global-set swaps

Question: after the earlier wrapper coverage for unrelated `global.set` blockers, does Binaryen `version_130` still fold when the wrapper contains a branch that exits the wrapper after the unrelated global write?

## Answer

Yes for the probed `version_130` shapes. Binaryen folded the later `struct.set` into the constructor while preserving both the `memory.grow` constructor operand and the branch-containing unrelated `global.set` wrapper for:

- a `block` root containing `global.set` followed by `br` to the block end;
- a `block` root containing an `if` arm that performs `global.set` and branches to the outer block end; and
- a `block` root containing a `loop` body that performs `global.set` and branches to the outer block end.

Starshine already matched these branch-wrapper swap positives, so this slice added focused coverage only and did not change HSO implementation code.

## Binaryen probes

Representative branch-containing wrapper probe:

```wat
(module
  (type $pair (sub (struct (field i32) (field (mut i32)))))
  (memory $m 1)
  (global $g (mut i32) (i32.const 0))
  (func $f (result i32)
    (local $s (ref null $pair))
    (i32.const 1)
    (memory.grow $m)
    (i32.const 2)
    (struct.new $pair)
    (local.set $s)
    (block $b
      (i32.const 1)
      (if
        (then
          (i32.const 9)
          (global.set $g)
          (br $b))))
    (local.get $s)
    (i32.const 7)
    (struct.set $pair 1)
    (local.get $s)
    (struct.get $pair 1)))
```

Commands:

```sh
python3 - <<'PY'
# Generated three fixtures under .tmp/hso-branch-wrapper-global-probe:
# block-br-after-global.wat, block-if-br-after-global.wat,
# and block-loop-br-after-global.wat.
PY
for f in .tmp/hso-branch-wrapper-global-probe/*.wat; do
  wasm-opt --all-features --heap-store-optimization -S "$f" -o "${f%.wat}.opt.wat"
done
grep -E "struct.set|struct.new|memory.grow|global.set|br " \
  .tmp/hso-branch-wrapper-global-probe/*.opt.wat
```

Observed result: all three optimized outputs preserved `memory.grow`, `global.set`, and the branch, and removed the later `struct.set`.

## Local coverage

Added focused test:

- `heap-store-optimization folds memory.grow across branch-containing global.set wrappers`

The test iterates the three wrapper shapes listed above and checks that Starshine preserves `memory.grow` and `global.set` while removing `struct.set`.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 182, passed: 182, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` wrapper drift coverage from branchless block/if/loop and nested wrappers around unrelated global writes to branch-containing wrappers that exit the wrapper after the unrelated write.
- Confirms these branches do not turn an unrelated global-write wrapper into a Binaryen no-fold boundary when the branch exits only the blocker wrapper and execution can still reach the later `struct.set` root.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, more branch/catch/control wrapper surfaces, final direct compare, and O4z slot evidence.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
