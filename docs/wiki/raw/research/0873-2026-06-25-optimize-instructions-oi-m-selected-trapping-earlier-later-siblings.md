---
kind: research
status: complete
date: 2026-06-25
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../../src/passes/optimize_instructions_test.mbt
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md
  - ../../../binaryen/passes/optimize-instructions/wat-shapes.md
---

# Optimize-instructions OI-M selected trapping lane with earlier and later siblings

## Question

For `tuple.extract(tuple.make(...))`, how does Binaryen preserve a selected trapping lane when both an earlier and a later sibling have effects?

## Oracle

Probe: `.tmp/oi-m-tuple-selected-trapping-earlier-later-probe.wat`.

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-earlier-later-probe.wat -o -
```

Binaryen keeps the earlier call before the selected trapping load, stores the selected load through tuple scratch, drops the later call, and reloads the selected local:

- `drop(call $effect64)`
- `drop(local.tee temp (i32.load ...))`
- `drop(call $effect32)`
- `local.get temp`

This preserves the original tuple child evaluation order while avoiding a second selected load after the later sibling.

## Starshine coverage

Added direct-HOT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions preserves selected trapping tuple.extract lane with earlier and later siblings`

The fixture builds a one-use tuple with an earlier `i64` call, selected `i32.load`, and later `i32` call. Starshine's direct-HOT localizer produces the same effect/trap ordering shape at the HOT level: earlier `drop(Call)`, selected `LocalSet(i32.load)`, later `drop(Call)`, and selected `LocalGet`.

This is coverage/status evidence for existing behavior, not a red-first implementation slice.

## Status

OI-M now has explicit selected trapping lane coverage for no sibling, later sibling, earlier sibling, and combined earlier+later sibling cases. Remaining OI-M boundaries include public tuple text/parser coverage, multi-result selected/sibling tuple-scratch localization, full `simplify-locals` replay hitting `InvalidChildRef`, and dedicated `tuple-optimization` neighbor parity.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-earlier-later-probe.wat -o -` passed and showed tuple-scratch preservation of the selected trapping lane between earlier/later sibling effects.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*earlier and later siblings*'` passed `1/1` as coverage/status evidence.
