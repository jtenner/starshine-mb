# Optimize Instructions OI-M Selected-Thirteenth Multi-Result Tuple Boundary

Date: 2026-06-25

## Question

Does Binaryen `version_130` localize the selected thirteenth scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine keep the current direct-HOT spelling until a selected-child tuple-scratch localizer exists?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-thirteenth-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32)))
  (func (result f32)
    (tuple.extract 14 12
      (tuple.make 14
        (call $many)
        (i32.const 13)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-thirteenth-probe.wat -o -
```

## Finding

Binaryen localizes the imported multi-result call into tuple scratch, extracts the thirteenth scalar lane (`tuple.extract 13 12`) into an `f32` temp, drops the tee, and returns the scalar temp. This matches the previous selected-first through selected-twelfth probes: Binaryen has a tuple-scratch reconstruction path for selected multi-result children. After the 2026-07-02 arity-13 through arity-16 Starshine implementation slices, this thirteenth-lane shape is superseded for direct one-use arity 13 and no longer marks the next selected-child boundary.

## Starshine coverage

The original direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt` was changed into red-first positive coverage for the arity-13 implementation slice:

- `optimize-instructions localizes thirteenth lane from thirteen-result selected tuple child`

The test builds a direct-HOT tuple with a thirteen-result selected `Call` child plus an extra scalar child, runs `optimize-instructions`, and asserts Starshine rewrites to a block with thirteen stack-pop-order scratch `local.set` roots and a final `local.get` for the selected thirteenth lane. Pre-implementation it failed because Starshine kept the `TupleExtract`; after the slice the focused positive test passed. The later arity-14 and arity-17 slices superseded the fourteenth- and fifteenth-lane boundaries too.

## 2026-07-02 implementation evidence

- Refreshed Binaryen oracle output: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-thirteenth-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-thirteenth-probe.binaryen.20260702.wat`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*thirteenth lane*'` failed `0/1` because the shape stayed `TupleExtract`.
- Post-fix focused tests: the same focused command passed `1/1`; `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*fourteenth lane*'` passed `1/1`, preserving the next arity boundary.

## Status

Starshine now has a bounded direct one-use selected-child localizer through arity 23. This note is retained as source/probe history, not an active direct one-use arity-13 blocker. Remaining OI-M work includes selected-child arities 24+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, and broader randomized/runtime evidence. Reopen this boundary if the arity-13 implementation regresses, if public tuple text/binary fixture support exposes a narrower counterexample, or if Binaryen changes this shape.
