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

Binaryen localizes the multi-result call through a tuple scratch local, extracts the eleventh scalar lane, stores it into a scalar temp, and returns that scalar temp. This matches the previously observed selected-first through selected-tenth boundary family: Binaryen has a tuple-scratch localizer for selected multi-result children.

## Starshine coverage

Added direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected eleventh lane boundary`

The test builds a direct HOT tuple whose selected child is an eleven-result call and whose selected lane is index `10`. Starshine keeps the `TupleExtract`, `TupleMake`, and multi-result `Call` unchanged. This is boundary-only evidence, not a red-first implementation slice.

## Status

Starshine still needs a safe selected-child tuple-scratch localizer before matching Binaryen for multi-result selected children. Reopen this boundary when that localizer exists, when public tuple text/binary fixture support improves, or if Binaryen changes this shape.
