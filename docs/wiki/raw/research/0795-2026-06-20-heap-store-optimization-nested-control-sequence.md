---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0794-2026-06-20-heap-store-optimization-in-function-catch-control.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ../../../.tmp/hso-v130-refresh/heap-store-optimization-v130.wast
---

# `heap-store-optimization` nested control-sequence folds

Question: does Starshine match the Binaryen `version_130` control-flow sequence family where a `local.set(struct.new_default)` and later `struct.set` chain live inside a block that is itself used as a value, for example under `drop (block (result i32) ...)`?

## Answer

Not before this slice. Starshine's HSO region traversal only descended into HOT control-region roots. That meant a Binaryen lit-shaped `drop (block (result i32) ...)` did not run HSO inside the nested block at all, so even the safe first `struct.set` in the sequence stayed outside the constructor.

This slice makes HSO recurse through ordinary expression children to find nested control regions, while preserving the active-catch depth handling added in `0794`: control nodes are still traversed through their typed regions so `try` / `try_table` bodies receive the catchable-region context and the caught-call negative stays blocked.

## Binaryen source/lit evidence

Binaryen `version_130` has a control-flow sequence family in `test/lit/passes/heap-store-optimization.wast`:

- `control-flow-in-set-value-sequence-2` folds the safe first store into `struct.new` but keeps the later `br_if`-valued `struct.set` because a later outside `struct.get(local.get $ref)` makes delaying the local assignment unsafe.
- `control-flow-in-set-value-sequence-yes` is the one-disappearing-bad-get exception: when the outside bad get is absent, Binaryen can fold the branch-valued store too.

This slice covers the first-store nested traversal and the unsafe escaping-branch negative. The exact one-disappearing-bad-get exception remains open: an attempted positive fixture still retained the branch-valued `struct.set`, so it was not landed as passing coverage and remains a real HSO-F follow-up rather than an accepted non-goal.

## Starshine change

- Added focused coverage for a safe function-external call value outside catchable regions. It folds into `struct.new`, complementing `0794`'s in-function caught-call negative.
- Added focused coverage for a nested `drop(block(result i32) ...)` control-flow sequence where Starshine should fold the safe first store but retain the later escaping `br_if`-valued store because the target local is read after the block.
- Added a broader multi-`br_if` escaping-local negative for the same in-function branch hazard family.
- Changed `hso_process_node_regions(...)` / `hso_process_region(...)` so HSO descends through ordinary expression children and reaches nested control regions under non-control roots, while control nodes still recurse via their regions with the correct active-catch depth.

## Evidence

- Red-first focused run: `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` failed after adding the nested control-sequence test; Starshine left the safe first `struct.set` in the nested block.
- Final focused run: `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` passed `77/77`.
- `moon fmt` passed.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct compare: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-control-sequence-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `10000/10000`, normalized `10000`, compare-normalized `0`, mismatches `0`, validation/property/generator failures `0`, command failures `0`, Binaryen cache `10000` hits / `0` misses.
- `moon info` passed with existing `gen_valid` / `gen_valid_ssa` warnings.
- `moon test src/passes` passed `2705/2705`.
- Full `moon test` passed `6018/6018`.

## Remaining HSO-F risk

This improves the in-function branch sequence coverage and fixes nested expression traversal, but it does not close HSO-F. The exact one-disappearing-bad-get exception remains a Starshine gap, safe external throw/return-call coverage still needs probes, and broader in-function branch/catch negatives should stay open until focused tests and source-backed classification cover them.
