# Optimize-instructions OI-M selected trapping tuple lane with two earlier and one later siblings

Date: 2026-06-25

## Summary

This OI-M coverage/status slice locks the selected trapping tuple lane when two earlier tuple siblings and one later tuple sibling have effects. Binaryen `version_130` preserves the two earlier calls before a selected `i32.load`, stores the selected load through tuple scratch before the later call, drops the later call, then reloads the selected lane. Starshine's direct-HOT localizer keeps the same observable order with a behavior-preserving block: drop both earlier calls, store the selected load, drop the later call, and reload the selected temp.

This is coverage/status evidence for existing behavior, not a red-first implementation slice.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-selected-trapping-two-earlier-one-later-probe.wat`

```wat
(module
  (memory 1)
  (func $effect64a (result i64) (i64.const 5))
  (func $effect64b (result i64) (i64.const 6))
  (func $effect32 (result i32) (i32.const 8))
  (func (param $p i32) (result i32)
    (tuple.extract 5 2
      (tuple.make 5
        (call $effect64a)
        (call $effect64b)
        (i32.load (local.get $p))
        (call $effect32)
        (i32.const 7)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-two-earlier-one-later-probe.wat -o -
```

Observed Binaryen output:

- drops `call $effect64a`
- drops `call $effect64b`
- stores/drops the selected `i32.load` through a tuple scratch local
- drops `call $effect32`
- reloads that local as the final result

## Starshine coverage

Added direct-HOT test:

- `optimize-instructions preserves selected trapping tuple.extract lane with two earlier and one later siblings`

The fixture builds a one-use tuple with two earlier `i64` call siblings, a selected exact `i32.load`, a later `i32` call sibling, and a later pure `i32.const`. The test asserts that Starshine's OI localizer produces a block with:

1. `drop(Call)` for the first earlier sibling
2. `drop(Call)` for the second earlier sibling
3. `LocalSet` of the exact selected `i32.load`
4. `drop(Call)` for the later sibling
5. `LocalGet` of the same temp as the final result

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-two-earlier-one-later-probe.wat -o -` passed and preserved both earlier calls, the selected trapping load, the later call, and the selected reload order.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*two earlier and one later siblings*'` passed `1/1`.

## Remaining OI-M work

Remaining OI-M boundaries include public tuple text/parser coverage, multi-result selected/sibling tuple-scratch localization, full `simplify-locals` replay hitting `InvalidChildRef`, and dedicated `tuple-optimization` neighbor parity.
