---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0800-2026-06-20-heap-store-optimization-table-size-swap.md
  - ./0801-2026-06-20-heap-store-optimization-table-grow-swap.md
  - ./0837-2026-06-20-heap-store-optimization-branch-wrapper-global-swap.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` branch-wrapper table global-set swaps

Question: after `0837` proved branch-containing unrelated-global-write wrappers for `memory.grow` constructor operands, do the `table.size` and `table.grow` constructor-operand counterparts behave the same under Binaryen `version_130`?

## Answer

Yes for the six probed `version_130` shapes. Binaryen folded the later `struct.set` into the constructor while preserving the constructor operand, the branch-containing unrelated `global.set` wrapper, and the wrapper branch for:

- `table.size $t` across a `block` root containing `global.set $g` followed by `br` to the block end;
- `table.size $t` across a `block` root containing an `if` arm that performs `global.set $g` and branches to the outer block end;
- `table.size $t` across a `block` root containing a `loop` body that performs `global.set $g` and branches to the outer block end;
- the same three wrapper shapes for a side-effecting `table.grow $t` constructor operand.

Starshine already matched these table branch-wrapper swap positives, so this slice added focused coverage only and did not change HSO implementation code.

## Binaryen probes

Representative `table.grow` branch-containing wrapper probe:

```wat
(module
  (type $pair (sub (struct (field i32) (field (mut i32)))))
  (table $t 1 funcref)
  (global $g (mut i32) (i32.const 0))
  (func $f (result i32)
    (local $s (ref null $pair))
    (ref.null func)
    (i32.const 1)
    (table.grow $t)
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
# Generated six fixtures under .tmp/hso-branch-wrapper-table-global-probe:
# table-size-{block-br-after-global,block-if-br-after-global,block-loop-br-after-global}.wat
# table-grow-{block-br-after-global,block-if-br-after-global,block-loop-br-after-global}.wat
PY
for f in .tmp/hso-branch-wrapper-table-global-probe/*.wat; do
  wasm-opt --all-features --heap-store-optimization -S "$f" -o "${f%.wat}.opt.wat"
done
grep -H -E "struct.set|struct.new|table.grow|table.size|global.set|br " \
  .tmp/hso-branch-wrapper-table-global-probe/*.opt.wat
```

Observed result: all six optimized outputs preserved `table.size` or `table.grow`, `global.set`, and the branch, and removed the later `struct.set`.

## Local coverage

Added focused tests:

- `heap-store-optimization folds table.size across branch-containing global.set wrappers`
- `heap-store-optimization folds table.grow across branch-containing global.set wrappers`

Each test iterates the three wrapper shapes listed above and checks that Starshine preserves the constructor operand and `global.set` while removing `struct.set`.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 184, passed: 184, failed: 0.
```

## Audit impact

- Extends `[O4Z-AUDIT-HSO-G]` branch-containing unrelated-global-write wrapper coverage from `memory.grow` to `table.size` and `table.grow` constructor operands.
- Confirms these branch-containing wrappers remain Binaryen fold positives when the branch exits only the blocker wrapper and execution can still reach the later `struct.set` root.
- Keeps `[O4Z-AUDIT-HSO-G]` open for broader swap operands/effects, more branch/catch/control wrapper surfaces, final direct compare, and O4z slot evidence.
- No native rebuild or direct compare was run because this was coverage-only documentation of Binaryen behavior that Starshine already matched.
