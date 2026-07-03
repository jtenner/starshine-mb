# Optimize Instructions OI-M Selected-Sixteenth Child Multi-Result Boundary

Date: 2026-07-02

## Question

Does Binaryen `version_130` localize the selected sixteenth scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-15 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-sixteenth-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64)))
  (func (result i64)
    (tuple.extract 17 15
      (tuple.make 17
        (call $many)
        (i32.const 16)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-sixteenth-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-sixteenth-child-probe.binaryen.20260702.wat
```

## Finding

Binaryen localizes the sixteen-result call into a tuple scratch local, extracts and drops the first lane, stores the selected sixteenth `i64` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for the selected arity-2 through arity-15 probes.

## Starshine coverage

The original direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt` was changed into red-first positive coverage for the arity-16 implementation slice:

- `optimize-instructions localizes sixteenth lane from sixteen-result selected tuple child`

The test builds a direct-HOT tuple with a sixteen-result selected `Call` child plus an extra scalar child, runs `optimize-instructions`, and asserts Starshine rewrites to a block with sixteen stack-pop-order scratch `local.set` roots and a final `local.get` for the selected sixteenth lane. Pre-implementation it failed because Starshine kept the `TupleExtract`; after the slice the focused positive test passed and a new seventeenth child-lane boundary remained unchanged.

## 2026-07-02 implementation evidence

- Refreshed Binaryen oracle output: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-sixteenth-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-sixteenth-child-probe.binaryen.20260702.wat`.
- New next-boundary Binaryen oracle output: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-seventeenth-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-seventeenth-child-probe.binaryen.20260702.wat`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*sixteenth lane*'` failed `1/2` because the new positive test stayed `TupleExtract` while the unrelated direct sixteenth-lane boundary still passed.
- Post-fix focused tests: the same focused command passed `2/2`; `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*seventeenth child-lane*'` passed `1/1`, preserving the next arity boundary; focused tuple.extract tests passed `24/24`, full `optimize_instructions_test.mbt` passed `631/631`, `moon fmt`, `moon info`, full `moon test`, and native `src/cmd` build passed with pre-existing warnings.
- Direct runtime-enabled fuzz `.tmp/oi-m-sixteen-result-selected-direct18-20260702` compared `18/18` with `18` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `18/0`, runtime checked/unsupported/failed `18/0/0`, and runtime matrix all-equal `1/1`.
- Grouped runtime-enabled OI-M sweep `.tmp/oi-m-sixteen-result-selected-count108-20260702` compared `108/108` with `108` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `108/0`, runtime checked/unsupported/failed `108/0/0`, runtime matrix all-equal `9/9`, and all 18 OI-M tuple labels sampled.

## Status

Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 26. This note is retained as source/probe history, not an active direct one-use arity-16 blocker. Remaining OI-M work includes selected-child arities 27+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, and broader randomized/runtime evidence. Reopen this boundary if the arity-16 implementation regresses, when adding public/binary tuple fixture coverage for this shape exposes a narrower counterexample, or if a future Binaryen source/oracle refresh stops localizing it.
