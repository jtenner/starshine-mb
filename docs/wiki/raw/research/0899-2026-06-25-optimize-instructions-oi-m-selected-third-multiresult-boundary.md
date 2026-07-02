# OptimizeInstructions OI-M selected third multi-result tuple boundary

## Summary

This boundary/status slice originally extended the OI-M multi-result selected-lane tuple-scratch evidence to the third scalar result of a multi-result child.

2026-07-02 update: this note is superseded for the direct one-use arity-3 selected-child case. Binaryen `version_130` can localize the selected value through tuple scratch and scalar temps, and Starshine now implements the bounded arity-3 localizer by storing all three selected-child lanes in stack-pop order before reloading the selected lane. Wider selected-child arities, multi-result non-selected siblings, multi-use tuple producers, and generalized tuple-scratch reconstruction remain open.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-multiresult-selected-third-probe.wat`.

Observed with:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-third-probe.wat -o -
```

Binaryen rewrites the selected third lane of an imported `(result i64 i32 f64)` call by:

- storing the multi-result call in tuple scratch,
- dropping the earlier non-selected `i64` lane,
- rebuilding/localizing a tuple containing the selected `f64` lane plus the later scalar sibling,
- storing/dropping the selected `f64` scalar temp,
- returning the selected scalar local.

## Starshine coverage

Original boundary coverage added direct-HOT boundary test `optimize-instructions intentionally keeps tuple.extract with multi-result selected third lane boundary` in `src/passes/optimize_instructions_test.mbt`.

2026-07-02 implementation coverage renamed that fixture to `optimize-instructions localizes third lane from three-result selected tuple child` and changed it red-first to require a block-localized replacement. The focused test failed 0/1 before implementation because the result stayed `TupleExtract`, then passed after `src/passes/optimize_instructions.mbt` admitted selected-child arity 3 and emitted scratch `local.set` roots for lanes 2, 1, and 0 before reloading lane 2.

This now covers only the direct one-use arity-3 selected-child subset. It must not be generalized to arity 4+, multi-result non-selected siblings, multi-use tuple producers, control/EH siblings, or full tuple-scratch reconstruction.

## Validation

- Binaryen oracle command above passed.
- Original boundary validation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected third lane*'` passed `1/1`.
- 2026-07-02 implementation validation: Binaryen probe output was refreshed at `.tmp/oi-m-tuple-multiresult-selected-third-probe.binaryen.20260702.wat`; the red-first focused command `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*three-result selected tuple child*'` failed 0/1 before implementation and passed 1/1 after; focused tuple.extract tests passed 34/34, full `optimize_instructions_test.mbt` passed 628/628, full `moon test` passed 7230/7230, and direct/grouped OI-M runtime-enabled compare lanes remained failure-free aside from expected raw mismatches.

## Remaining work

OI-M still needs a real generalized tuple-scratch localizer for selected and sibling lanes beyond the current direct one-use arity-2/3 selected-child subsets before Starshine can claim Binaryen parity for these multi-result tuple shapes. Public/binary tuple fixture coverage remains limited by local tuple text/parser support, and the full `simplify-locals` replay blocker that previously produced `InvalidChildRef(3, 0, 0)` remains open.
