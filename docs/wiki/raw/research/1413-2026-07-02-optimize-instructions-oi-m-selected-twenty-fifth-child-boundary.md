# Optimize Instructions OI-M Selected-Twenty-Fifth Child Multi-Result Boundary

Date: 2026-07-02

## Question

Does Binaryen `version_130` localize the selected twenty-fifth scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-24 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-twenty-fifth-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 f32 i64 f32 f64 i32 i64 f32 f64 i32)))
  (func (result i32)
    (tuple.extract 26 24
      (tuple.make 26
        (call $many)
        (i32.const 25)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twenty-fifth-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-twenty-fifth-child-probe.binaryen.20260702.wat
```

## Finding

Binaryen localizes the twenty-five-result call into a tuple scratch local, extracts and drops the first lane, stores the selected twenty-fifth `i32` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for selected arities 2 through 24.

## Starshine coverage

Initial direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt` was promoted to source-backed positive coverage during the 2026-07-03 arity-25 slice:

- `optimize-instructions localizes twenty-fifth lane from twenty-five-result selected tuple child`

The positive test failed red-first because Starshine kept `TupleExtract` index `24`, then passed after `src/passes/optimize_instructions.mbt` admitted the direct one-use arity-25 selected-child case. It asserts the rewrite becomes a `Block` with 25 stack-pop-order selected-lane `LocalSet` roots followed by a `LocalGet` of the selected twenty-fifth lane's scratch local. A new arity-26 boundary test now tracks the next source-backed selected-child tuple-scratch target.

## Status

Superseded for direct one-use arity-25 selected-child localization by the 2026-07-03 implementation slice. Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 26. Remaining OI-M work includes selected-child arities 27+, multi-result non-selected siblings, multi-use tuple producers, generalized tuple-scratch reconstruction/localization, control/EH sibling localization, broader randomized/runtime evidence, and public/binary tuple fixture coverage where representable. Reopen this note only if the arity-25 implementation regresses or a future Binaryen source/oracle refresh stops localizing it.
