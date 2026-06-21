---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` br_table local-escape coverage

Question: how should HSO treat `br_table` values in the same control-flow/skip-local-set family as the existing `br_if` escaping-branch and one-disappearing-bad-get tests?

## Binaryen `version_130` probes

Two local fixtures were written under `.tmp/` and run through the release oracle:

```sh
wasm-opt .tmp/hso-probe-br-table-escape.wat --heap-store-optimization -all -S -o -
wasm-opt .tmp/hso-probe-br-table-disappearing.wat --heap-store-optimization -all -S -o -
```

Observed behavior:

- `.tmp/hso-probe-br-table-escape.wat`: Binaryen preserves both `struct.set` roots when the branch-valued store can branch around the constructor local-set and the target local is read after the block. This matches the existing `br_if` escaping-local negative family.
- `.tmp/hso-probe-br-table-disappearing.wat`: Binaryen also preserves both `struct.set` roots even when the later target-local read disappears from observable code. This differs from Starshine's existing branch analysis, which applies the one-disappearing-bad-get reasoning to the equivalent `br_table` shape and folds the stores.

## Starshine tests

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps br_table branch values inside escaping local blocks`
  - parity negative: Starshine preserves `struct.set`, matching Binaryen when the target local is observed after the block.
- `heap-store-optimization folds br_table branch values when later local reads disappear`
  - documented Starshine better-than-Binaryen behavior: Starshine folds when the branch can only skip a constructor local-set whose value is not observed after the branch target. The output keeps the `br_table`, materializes `struct.new`, and removes `struct.set`.

The second test initially failed when written as a Binaryen-parity negative: Starshine had already folded the stores. After inspecting the Binaryen probe and the local output, this was classified as a narrow Starshine win rather than an implementation bug:

- the taken `br_table` exits the block before the constructor local-set in both the original and optimized control shape;
- no later `local.get $l` remains after the block in the fixture, so skipping the constructor assignment is not observable;
- the optimized Starshine module validates through the focused HSO test harness;
- the transformation is the same semantic reason already accepted for the implemented one-disappearing-bad-get exception, extended to a `br_table` value shape that Binaryen does not currently fold.

Reopening criteria: if a future fixture shows a `br_table` fold where the target local can be observed after an in-function branch target, or where a non-local side effect is reordered across the branch in a way Binaryen avoids, reopen HSO-F and prefer Binaryen behavior unless the new case is separately proven as a Starshine win.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 221, passed: 221, failed: 0.
```

No implementation changed. Native rebuild and direct 10000-case compare were not required for this coverage/classification-only slice.
