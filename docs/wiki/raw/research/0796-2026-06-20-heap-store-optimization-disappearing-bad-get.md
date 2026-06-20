---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0795-2026-06-20-heap-store-optimization-nested-control-sequence.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../.tmp/hso-v130-refresh/heap-store-optimization-v130.wast
---

# `heap-store-optimization` one-disappearing-bad-get fold

Question: can Starshine match Binaryen `version_130`'s exact `control-flow-in-set-value-sequence-yes` exception, where a branch-valued `struct.set` may fold because the only bad local read is inside the branch target's skipped tail and there is no later outside read of the fresh-struct local?

## Answer

Not before this slice. After `0795`, Starshine reached the nested `drop(block(result ...))` sequence and folded the first safe store, but it still retained the branch-valued later `struct.set` in the `control-flow-in-set-value-sequence-yes` shape. Binaryen folds that later store too because if the `br_if` is taken it exits the block, skips the delayed local assignment, and also skips the only local read that would have observed the missing assignment. The function then returns a constant and never reads the target local outside the block.

This slice implements a narrow HOT equivalent: when a branch-only root immediately precedes a matching later `struct.set`, and the target local is not touched after the owner expression, HSO may move that branch root before the delayed constructor `local.set` and then fold the following store. The pre-existing negative from `0795` still blocks when a later outside `struct.get(local.get $ref)` exists.

## Binaryen source/lit evidence

Binaryen `version_130` lit has two adjacent shapes:

- `control-flow-in-set-value-sequence-2`: Binaryen folds the first non-branching store but keeps the later `br_if`-valued `struct.set`, because a later outside `struct.get(local.get $ref)` makes skipping the local assignment observable.
- `control-flow-in-set-value-sequence-yes`: Binaryen folds the branch-valued later store too. The in-block `struct.get(local.get $ref)` remains, but it is skipped when the branch exits the block, and there is no outside local read after the dropped block.

The implementation is a Starshine HOT-region approximation of Binaryen's `LazyLocalGraph::canMoveSet(...)` exception, not a broad acceptance of all skipped-local-set control flow.

## Starshine change

- Added a focused red-first test for the disappearing-bad-get shape. It failed with a retained `struct.set` after the first store folded.
- Added external-root tracking to HSO region traversal so nested owner regions can distinguish local reads after the owner expression from local reads in the owner's own skipped suffix.
- Added a branch-only skip predicate and a narrow chain-scan rule: branch-only roots with no target-local touch after the owner can move before the delayed fresh-struct `local.set` when the next root is a matching `struct.set`; the later store then folds normally.
- Kept the existing escaping-local negative green: when a later outside read of the target local exists, the branch root is not moved and the branch-valued `struct.set` remains.

## Evidence

- Red-first focused run: `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` failed on `heap-store-optimization folds branch values when later bad local reads disappear`; Starshine retained the later branch-valued `struct.set`.
- Final focused run: `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `78/78`.
- `moon fmt` passed.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct compare: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-disappearing-bad-get-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `10000/10000`, normalized `10000`, compare-normalized `0`, mismatches `0`, validation/property/generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.

## Remaining HSO-F risk

This closes the exact one-disappearing-bad-get exception that `0795` left open. HSO-F still needs safe external throw and return-call probes/classification plus broader in-function branch/catch negatives before the control-flow audit can close. Return-call remains especially sensitive because it may throw before returning when inside a catchable region.
