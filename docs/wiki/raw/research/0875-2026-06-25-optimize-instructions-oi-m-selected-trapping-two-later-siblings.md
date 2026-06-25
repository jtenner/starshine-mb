---
kind: research
status: complete
date: 2026-06-25
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../../src/passes/optimize_instructions_test.mbt
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/wat-shapes.md
---

# Optimize-instructions OI-M selected trapping tuple lane with two later siblings

## Question

When a selected `tuple.extract(tuple.make(...))` lane is a trapping `i32.load`, does Binaryen preserve the selected trap/value order when there is an earlier effectful tuple sibling and two later effectful siblings?

## Oracle

Probe: `.tmp/oi-m-tuple-selected-trapping-two-later-probe.wat`.

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-two-later-probe.wat -o -
```

Binaryen keeps the order by using tuple scratch/localization: it drops the earlier `i64` call, evaluates and stores/drops the selected `i32.load`, drops the two later `i32` calls in order, then reloads the selected temp as the result.

## Starshine coverage

Added direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves selected trapping tuple.extract lane with two later siblings`

The fixture builds a one-use tuple with an earlier effectful `i64` call sibling, a selected exact `i32.load`, and two later effectful `i32` call siblings. It asserts that Starshine's existing direct-HOT localizer produces a behavior-preserving block with `drop(Call)`, `LocalSet(i32.load)`, `drop(Call)`, `drop(Call)`, then `LocalGet`, preserving effect/trap order and avoiding a second selected load after the later siblings.

This is a boundary/status slice, not a red-first implementation slice. Starshine already matched the source-backed ordering requirement for this single-result tuple-scratch subset.

## Status

OI-M now has selected trapping tuple-lane coverage for no sibling, a later effectful sibling, an earlier effectful sibling, earlier-plus-later siblings, and two later effectful siblings. Remaining OI-M work still includes public tuple text/parser coverage, multi-result selected/sibling tuple-scratch localization, the full `simplify-locals` replay that currently hits `InvalidChildRef`, and dedicated `tuple-optimization` neighbor parity.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-two-later-probe.wat -o -` passed and preserved the earlier call, selected trapping load, both later calls, and final reload.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*two later siblings*'` passed `1/1`.
