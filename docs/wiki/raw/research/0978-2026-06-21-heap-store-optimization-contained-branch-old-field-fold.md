# Heap Store Optimization Contained Branch Old-Field Fold

Date: 2026-06-21

## Summary

This slice fixes the HSO-D/G parity gap recorded in `0976` and `0977` for overwritten pure branch-containing outer-block/inner-loop old fields before unrelated store and growth roots.

Binaryen `version_130` drops an overwritten old constructor field when that old value is pure/trapless except for contained control flow, then folds the later same-field `struct.set` value into the fresh `struct.new`. The unrelated intervening root (`i32.store`, `table.set`, `memory.grow`, or `table.grow`) remains in place.

Starshine previously folded the later `struct.set` but preserved the old branch-loop value as dropped `br_if`/block debris. That was still a behavior-parity gap because Binaryen's HSO removes the overwritten pure old-field computation entirely.

## Implementation

Changed `src/passes/heap_store_optimization.mbt`:

- Added `hso_subtree_is_trapless_readonly_contained_control(...)` and a region helper.
- The new predicate treats contained branch/control wrappers as droppable readonly old-field values when:
  - all branch targets stay inside the active owner stack;
  - the subtree has no traps, throws, terminators that exit the subtree, or disallowed effects;
  - effects are limited to control plus readonly local/global/memory/table reads; and
  - side effects are only the structural control/drop/branch effects needed to model contained control.
- `hso_build_preserved_replacement(...)` now drops an overwritten old value outright when either the old strict readonly predicate or this contained-control readonly predicate succeeds.

This is intentionally narrower than making all readonly/reorder decisions branch-tolerant: the new predicate is used for droppable overwritten old-field values, not as a general blocker-swap proof.

## Tests

Changed `src/passes/heap_store_optimization_test.mbt`:

- Added encoded wasm fixtures for pure branch-loop old fields before unrelated store roots:
  - `i32.store`
  - `table.set`
- Added encoded wasm fixtures for pure branch-loop old fields before unrelated growth roots:
  - `memory.grow`
  - `table.grow`
- The fixtures assert that HSO removes `struct.set`, removes the `br_if` old-field debris, keeps `struct.new`, keeps the folded `I32(4)`, and preserves the unrelated root.

The tests were first run red after the regression commit: Starshine removed `struct.set` but still emitted dropped `br_if`/block old-field debris.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'pure branch-loop old fields'`
  - Before implementation: failed as expected; both tests still contained `br_if` debris.
  - After implementation: `343/343` passed.
- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt`
  - `343/343` passed.
- `moon fmt`
  - passed.
- `moon test src/passes`
  - `2971/2971` passed.
- `moon build --target native --release src/cmd`
  - passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-pure-branch-old-field-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - compared `10000/10000`
  - normalized matches `10000`
  - mismatches `0`
  - validation failures `0`
  - property failures `0`
  - generator failures `0`
  - command failures `0`
  - Binaryen cache: `10000` hits / `0` misses

## Status

The specific `0976`/`0977` pure branch-loop old-field gap is fixed and covered. HSO-D/G remain open for broader descriptor/later-field/barrier/wrapper families listed in the HSO wiki and backlog.
