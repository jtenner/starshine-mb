# Optimize Instructions OI-M Selected-Eleventh Multi-Result Tuple Boundary

Date: 2026-06-25

## Question

How does Binaryen `version_130` handle `tuple.extract` when the selected lane is the eleventh scalar result of a multi-result child?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-eleventh-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32)))
  (func (result i32)
    (tuple.extract 12 10
      (tuple.make 12
        (call $many)
        (i32.const 11)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-eleventh-probe.wat -o -
```

## Finding

Binaryen localizes the multi-result call through a tuple scratch local, extracts the eleventh scalar lane, stores it into a scalar temp, and returns that scalar temp. This matches the previously observed selected-first through selected-tenth family: Binaryen has a tuple-scratch localizer for selected multi-result children. After the later 2026-07-02 arity-11 Starshine implementation slice, this note is superseded for direct one-use arity 11 and the twelfth-lane shape was later implemented too; the thirteenth-lane shape is now the next selected-child arity boundary.

## Starshine coverage

The original direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt` was changed into red-first positive coverage for the arity-11 implementation slice:

- `optimize-instructions localizes eleventh lane from eleven-result selected tuple child`

The test builds a direct HOT tuple whose selected child is an eleven-result call and whose selected lane is index `10`. Pre-implementation it failed because Starshine kept the `TupleExtract`; after the slice Starshine rewrites to a block with eleven stack-pop-order scratch `local.set` roots and a final `local.get` for the selected eleventh lane. This is now implementation evidence for the bounded direct one-use arity-11 subset only.

## 2026-07-02 implementation evidence

- Refreshed Binaryen oracle output: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-eleventh-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-eleventh-probe.binaryen.20260702.wat`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*eleventh lane*'` failed `0/1` because the shape stayed `TupleExtract`.
- Post-fix focused tests: the same focused command passed `1/1`; `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*twelfth lane*'` passed `1/1` at that time; the later arity-12 slice moved the active boundary to thirteenth lane.
- Direct fuzz: `.tmp/oi-m-eleven-result-selected-direct18-20260702` compared `18/18`, with `18` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `18/0`, runtime checked/unsupported/failed `18/0/0`, and runtime matrix all-equal `1/1`.
- Grouped fuzz: `.tmp/oi-m-eleven-result-selected-count108-20260702` compared `108/108`, with `108` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `108/0`, runtime checked/unsupported/failed `108/0/0`, runtime matrix all-equal `9/9`, and all 18 tuple labels sampled.

## Status

Starshine now has a bounded direct one-use selected-child localizer through arity 21. This note is retained as source/probe history, not an active direct one-use arity-11 blocker. Remaining OI-M work includes selected-child arities 22+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, and broader randomized/runtime evidence. Reopen this boundary if the arity-11 implementation regresses, if public tuple text/binary fixture support exposes a narrower counterexample, or if Binaryen changes this shape.
