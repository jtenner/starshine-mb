# Optimize Instructions OI-M Selected-Twelfth Multi-Result Tuple Boundary

Date: 2026-06-25

## Question

Does Binaryen `version_130` localize the selected twelfth scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine keep the current direct-HOT spelling until a selected-child tuple-scratch localizer exists?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-twelfth-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64)))
  (func (result i64)
    (tuple.extract 13 11
      (tuple.make 13
        (call $many)
        (i32.const 12)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twelfth-probe.wat -o -
```

## Finding

Binaryen localizes the imported multi-result call into tuple scratch, extracts the twelfth scalar lane (`tuple.extract 12 11`) into an `i64` temp, drops the tee, and returns the scalar temp. This matches the previous selected-first through selected-eleventh probes: Binaryen has a tuple-scratch reconstruction path for selected multi-result children. After the 2026-07-02 arity-12 and arity-13 Starshine implementation slices, this twelfth-lane shape is now superseded for direct one-use arity 12 and the fourteenth-lane shape is the next selected-child arity boundary.

## Starshine coverage

The original direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt` was changed into red-first positive coverage for the arity-12 implementation slice:

- `optimize-instructions localizes twelfth lane from twelve-result selected tuple child`

The test builds a direct-HOT tuple whose selected child is a twelve-result call and whose selected lane is index `11`. Pre-implementation it failed because Starshine kept the `TupleExtract`; after the slice Starshine rewrites to a block with twelve stack-pop-order scratch `local.set` roots and a final `local.get` for the selected twelfth lane.

## 2026-07-02 implementation evidence

- Refreshed Binaryen oracle output: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twelfth-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-twelfth-probe.binaryen.20260702.wat`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*twelfth lane*'` failed `0/1` because the shape stayed `TupleExtract`.
- Post-fix focused tests: the same focused command passed `1/1`; `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*thirteenth lane*'` passed `1/1`, preserving the then-next arity boundary before the later arity-13 slice superseded it.
- Direct fuzz: `.tmp/oi-m-twelve-result-selected-direct18-20260702` compared `18/18`, with `18` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `18/0`, and runtime checked/unsupported/failed `18/0/0`.
- Grouped fuzz: `.tmp/oi-m-twelve-result-selected-count108-20260702` compared `108/108`, with `108` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `108/0`, runtime checked/unsupported/failed `108/0/0`, and all 18 tuple labels sampled.

## Status

Starshine now has a bounded direct one-use selected-child localizer through arity 24. This note is retained as source/probe history, not an active direct one-use arity-12 blocker. Remaining OI-M work includes selected-child arities 25+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, and broader randomized/runtime evidence. Reopen this boundary if the arity-12 implementation regresses, if public tuple text/binary fixture support exposes a narrower counterexample, or if Binaryen changes this shape.
