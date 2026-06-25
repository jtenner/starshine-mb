# Optimize-instructions OI-M selected trapping tuple lane with two earlier siblings

Date: 2026-06-25

## Summary

This OI-M coverage/status slice locks the selected trapping tuple lane when two earlier tuple siblings have effects. Binaryen `version_130` preserves the two earlier calls before a selected `i32.load` by using tuple scratch; Starshine's direct-HOT localizer keeps a smaller behavior-preserving block that drops both earlier calls in order and then evaluates the selected load directly because no later sibling effect can reorder after it.

This is coverage/status evidence for existing behavior, not a red-first implementation slice.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-selected-trapping-two-earlier-probe.wat`

```wat
(module
  (memory 1)
  (func $effect64a (result i64) (i64.const 5))
  (func $effect64b (result i64) (i64.const 6))
  (func (param $p i32) (result i32)
    (tuple.extract 4 2
      (tuple.make 4
        (call $effect64a)
        (call $effect64b)
        (i32.load (local.get $p))
        (i32.const 7)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-two-earlier-probe.wat -o -
```

Observed Binaryen output:

- drops `call $effect64a`
- drops `call $effect64b`
- stores/drops the selected `i32.load` through a tuple scratch local
- reloads that local as the final result

## Starshine coverage

Added direct-HOT test:

- `optimize-instructions preserves selected trapping tuple.extract lane with two earlier siblings`

The fixture builds a one-use tuple with two earlier `i64` call siblings, a selected exact `i32.load`, and a later pure `i32.const`. The test asserts that Starshine's OI localizer produces a block with:

1. `drop(Call)` for the first earlier sibling
2. `drop(Call)` for the second earlier sibling
3. the exact selected `i32.load` as the block result

This is smaller than Binaryen's tuple-scratch spelling but preserves the same observable order because there are no later effects after the selected load.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-two-earlier-probe.wat -o -` passed and preserved both earlier calls before the selected load.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*two earlier siblings*'` passed `1/1`.

## Remaining OI-M work

Remaining OI-M boundaries include public tuple text/parser coverage, multi-result selected/sibling tuple-scratch localization, full `simplify-locals` replay hitting `InvalidChildRef`, and dedicated `tuple-optimization` neighbor parity.
