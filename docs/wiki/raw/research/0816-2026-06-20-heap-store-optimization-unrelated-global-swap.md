---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0781-2026-06-20-heap-store-optimization-swap-constructor-global.md
  - ./0815-2026-06-20-heap-store-optimization-growth-store-swap-boundaries.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` unrelated global swap parity

Question: does Binaryen `version_130` let `trySwap(...)` move a constructor whose operand reads one mutable global across a `global.set` to a different mutable global?

## Finding

Yes. Binaryen folds the later `struct.set` when the constructor operand is `global.get $a` and the intervening root is `global.set $b` for a distinct mutable global. This narrows the earlier `0781` same-global blocker: the no-swap boundary is not “any constructor global read crosses any global write”; it is specifically an ordered same-global read/write conflict.

Before this slice, Starshine overblocked this family because its swap-side effect summary treated all global state as one coarse ordered-before conflict. The new local implementation keeps the existing same-global negative but ignores global-only ordering when the constructor operands do not write globals and the blocker writes a different global than any constructor operand reads.

## Binaryen probe

Input:

```wat
(module
  (type $S (struct (field (mut i32)) (field (mut i32))))
  (global $a (mut i32) (i32.const 1))
  (global $b (mut i32) (i32.const 2))
  (func (result i32)
    (local $x (ref null $S))
    (local.set $x
      (struct.new $S
        (global.get $a)
        (i32.const 2)))
    (global.set $b (i32.const 9))
    (struct.set $S 1
      (local.get $x)
      (i32.const 7))
    (struct.get $S 1 (local.get $x))))
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-slice-probe/mutable-global-read-unrelated-global-set.wat \
  -o .tmp/hso-slice-probe/mutable-global-read-unrelated-global-set.opt.wat
```

Observed output moves the `global.set $b` before the rewritten constructor, folds the `7` into `struct.new`, and removes `struct.set`. Agent classification: source-backed Binaryen behavior parity gap in Starshine, not representation drift.

## Starshine fix

Added failing focused coverage first:

- `heap-store-optimization folds constructor global.get across unrelated global.set`

Initial result:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 101, passed: 100, failed: 1.
```

Implementation:

- added two-global HSO test fixture helpers;
- added HOT subtree global read/write predicates for global-specific swap conflict checks;
- allowed `trySwap(...)` to ignore coarse global-state ordering only when both sides are otherwise effect-free, constructor operands do not write globals, and the blocker writes a global not read by the constructor operands;
- retained existing negatives for same-global constructor read / global write, call-valued constructor operands, and trapping memory-load constructor operands.

## Validation

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 101, passed: 101, failed: 0.

moon fmt
passed / up to date

moon test src/passes
Total tests: 2729, passed: 2729, failed: 0.

moon build --target native --release src/cmd
passed with existing unused-function warnings in src/passes/pass_manager.mbt
```

Direct compare:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-unrelated-global-swap-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: requested `10000`, compared `10000`, normalized matches `10000`, compare-normalized matches `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.

## Status

This closes one additional HSO-G mutable-global swap family. HSO-G remains open for broader operand/effect combinations and additional wrapper drift. HSO-B still needs early/late O4z slot or neighborhood evidence before final closeout.
