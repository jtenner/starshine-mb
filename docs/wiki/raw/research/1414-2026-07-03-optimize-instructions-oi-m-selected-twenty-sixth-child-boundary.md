# Optimize Instructions OI-M Selected-Twenty-Sixth Child Multi-Result Boundary

Date: 2026-07-03

## Question

Does Binaryen `version_130` localize the selected twenty-sixth scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-25 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-twenty-sixth-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 f32 i64 f32 f64 i32 i64 f32 f64 i32 i64)))
  (func (result i64)
    (tuple.extract 27 25
      (tuple.make 27
        (call $many)
        (i32.const 26)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twenty-sixth-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-twenty-sixth-child-probe.binaryen.20260703.wat
```

## Finding

Binaryen localizes the twenty-six-result call into a tuple scratch local, extracts and drops the first lane, stores the selected twenty-sixth `i64` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for selected arities 2 through 25.

## Starshine coverage

Initial direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt` was promoted to source-backed positive coverage during the 2026-07-03 arity-26 slice:

- `optimize-instructions localizes twenty-sixth lane from twenty-six-result selected tuple child`

The positive test failed red-first because Starshine kept `TupleExtract` index `25`, then passed after `src/passes/optimize_instructions.mbt` admitted the direct one-use arity-26 selected-child case. It asserts the rewrite becomes a `Block` with 26 stack-pop-order selected-lane `LocalSet` roots followed by a `LocalGet` of the selected twenty-sixth lane's scratch local. A new arity-27 boundary test now tracks the next source-backed selected-child tuple-scratch target.

## Implementation evidence

The 2026-07-03 arity-26 implementation slice promoted this boundary to positive coverage. Evidence:

- Red-first `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*twenty-sixth lane*'` failed 0/1 before implementation because the result stayed `TupleExtract`.
- Post-fix focused twenty-sixth filter passed 1/1, twenty-seventh boundary passed 1/1, tuple.extract filter passed 24/24, and full `optimize_instructions_test.mbt` passed 641/641.
- `moon fmt`, `moon info`, full `moon test` (7243/7243), and native `src/cmd` build passed; warnings were pre-existing.
- Direct `.tmp/oi-m-twenty-six-result-selected-direct18-20260703` compared 18/18 with 18 raw mismatches, zero validation/generator/property/command failures, Binaryen cache `18/0`, runtime checked/unsupported/failed `18/0/0`, and runtime matrix all-equal `1/1`.
- Grouped `.tmp/oi-m-twenty-six-result-selected-count108-20260703` compared 108/108 with 108 raw mismatches, zero validation/generator/property/command failures, Binaryen cache `108/0`, runtime checked/unsupported/failed `108/0/0`, runtime matrix all-equal `9/9`, and all 18 OI-M tuple labels sampled.

## Status

Superseded for direct one-use arity-26 selected-child localization by the 2026-07-03 implementation slice. Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 26. Remaining OI-M work includes selected-child arities 27+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, broader randomized/runtime evidence, and public/binary tuple fixture coverage where representable. Reopen this note only if the arity-26 implementation regresses or a future Binaryen source/oracle refresh stops localizing it.
