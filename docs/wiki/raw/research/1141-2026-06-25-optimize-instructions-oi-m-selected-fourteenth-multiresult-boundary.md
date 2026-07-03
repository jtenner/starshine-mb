# Optimize Instructions OI-M Selected-Fourteenth Multi-Result Boundary

Date: 2026-06-25

## Question

Does Binaryen `version_130` localize a selected fourteenth scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine's current direct-HOT tuple.extract localizer claim that behavior?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-fourteenth-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64)))
  (func (result f64)
    (tuple.extract 15 13
      (tuple.make 15
        (call $many)
        (i32.const 14)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-fourteenth-probe.wat -o -
```

2026-07-02 refresh command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-fourteenth-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-fourteenth-probe.binaryen.20260702.wat
```

## Finding

Binaryen localizes the fourteen-result call into a tuple scratch local, extracts and drops the earlier result lane, stores the selected fourteenth `f64` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for the earlier selected multi-result boundary probes.

## Starshine coverage

The original direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt` was changed into red-first positive coverage for the arity-14 implementation slice:

- `optimize-instructions localizes fourteenth lane from fourteen-result selected tuple child`

The test builds a direct-HOT tuple with a fourteen-result selected `Call` child plus an extra scalar child, runs `optimize-instructions`, and asserts Starshine rewrites to a block with fourteen stack-pop-order scratch `local.set` roots and a final `local.get` for the selected fourteenth lane. Pre-implementation it failed because Starshine kept the `TupleExtract`; after the slice the focused positive test passed and a new fifteenth child-lane boundary remained unchanged.

## 2026-07-02 implementation evidence

- Refreshed Binaryen oracle output: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-fourteenth-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-fourteenth-probe.binaryen.20260702.wat`.
- Red-first focused test: `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*fourteenth lane*'` failed `0/1` because the shape stayed `TupleExtract`.
- Post-fix focused tests: the same focused command passed `1/1`; `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*fifteenth child-lane*'` passed `1/1`, preserving the next arity boundary; focused tuple.extract tests passed `24/24`, full `optimize_instructions_test.mbt` passed `629/629`, `moon fmt`, `moon info`, full `moon test`, and native `src/cmd` build passed with pre-existing warnings.
- Direct runtime-enabled fuzz `.tmp/oi-m-fourteen-result-selected-direct18-20260702` compared `18/18` with `18` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `18/0`, runtime checked/unsupported/failed `18/0/0`, and runtime matrix all-equal `1/1`.
- Grouped runtime-enabled OI-M sweep `.tmp/oi-m-fourteen-result-selected-count108-20260702` compared `108/108` with `108` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `108/0`, runtime checked/unsupported/failed `108/0/0`, runtime matrix all-equal `9/9`, and all 18 OI-M tuple labels sampled.

## Status

Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 22. This note is retained as source/probe history, not an active direct one-use arity-14 blocker. Remaining OI-M work includes selected-child arities 23+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, and broader randomized/runtime evidence. Reopen this boundary if the arity-14 implementation regresses, when adding public/binary tuple fixture coverage for this shape exposes a narrower counterexample, or if a future Binaryen source/oracle refresh stops localizing it.
