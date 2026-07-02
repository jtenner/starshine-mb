# Optimize-instructions OI-M selected-fourth multi-result tuple boundary

Date: 2026-06-25

## Question

How should Starshine treat `tuple.extract` when the selected lane is the fourth scalar result produced by a multi-result child?

## Summary

This note originally recorded a boundary/status slice for the fourth scalar result of a multi-result selected tuple child.

2026-07-02 update: this note is superseded for the direct one-use arity-4 selected-child case. Binaryen `version_130` localizes the selected fourth lane through tuple scratch and scalar temps, and Starshine now implements the bounded arity-4 localizer by storing all four selected-child lanes in stack-pop order before reloading the selected lane. Wider selected-child arities, multi-result non-selected siblings, multi-use tuple producers, and generalized tuple-scratch reconstruction remain open.

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-multiresult-selected-fourth-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-fourth-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-fourth-probe.binaryen.20260702.wat
```

Result: Binaryen `version_130` localizes the selected fourth result from an imported `(result i32 i64 f32 f64)` call through tuple scratch and scalar temps before returning the selected `f64` lane. The emitted shape drops earlier tuple lanes, stores/drops the selected lane through a scalar temp, and reloads the selected value.

## Starshine coverage

Original direct-HOT boundary coverage in `src/passes/optimize_instructions_test.mbt` was `optimize-instructions intentionally keeps tuple.extract with multi-result selected fourth lane boundary`.

2026-07-02 implementation coverage renamed that fixture to `optimize-instructions localizes fourth lane from four-result selected tuple child` and changed it red-first to require a block-localized replacement. The focused test failed 0/1 before implementation because the result stayed `TupleExtract`, then passed after `src/passes/optimize_instructions.mbt` admitted selected-child arity 4 and emitted scratch `local.set` roots for lanes 3, 2, 1, and 0 before reloading lane 3.

This now covers only the direct one-use arity-4 selected-child subset. It must not be generalized to arity 5+, multi-result non-selected siblings, multi-use tuple producers, control/EH siblings, or full tuple-scratch reconstruction.

## Evidence

- Binaryen oracle command above passed and wrote `.tmp/oi-m-tuple-multiresult-selected-fourth-probe.binaryen.20260702.wat`.
- Original boundary validation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*selected fourth lane*'` passed `1/1`.
- 2026-07-02 implementation validation: red-first `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*four-result selected tuple child*'` failed 0/1 before implementation and passed 1/1 after; focused tuple.extract tests passed 33/33, full `optimize_instructions_test.mbt` passed 628/628, full `moon test` passed 7230/7230, and direct/grouped OI-M runtime-enabled compare lanes remained failure-free aside from expected raw mismatches.

## Remaining work

A real generalized tuple-scratch localizer remains open. Related OI-M work includes selected-child arities 5+, multi-result non-selected siblings, multi-use tuple producers, control/EH sibling localization, public/binary tuple fixture coverage where representable, full `simplify-locals` replay for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction.
