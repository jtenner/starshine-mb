# Optimize Instructions OI-M Selected-Twenty-Fourth Child Multi-Result Boundary

Date: 2026-07-02

## Question

Does Binaryen `version_130` localize the selected twenty-fourth scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-23 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-twenty-fourth-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 f32 i64 f32 f64 i32 i64 f32 f64)))
  (func (result f64)
    (tuple.extract 25 23
      (tuple.make 25
        (call $many)
        (i32.const 24)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twenty-fourth-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-twenty-fourth-child-probe.binaryen.20260702.wat
```

## Finding

Binaryen localizes the twenty-four-result call into a tuple scratch local, extracts and drops the first lane, stores the selected twenty-fourth `f64` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for selected arities 2 through 23.

## Starshine coverage

Added direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected twenty-fourth child-lane boundary`

The test asserts Starshine keeps `TupleExtract` index `23`, the `TupleMake`, and the twenty-four-result selected `Call` unchanged. This is boundary-only evidence, not an implementation slice.

## Status

Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 23. This twenty-fourth child-lane shape is the next source-backed selected-child tuple-scratch boundary after the 2026-07-02 arity-23 slice. Reopen this boundary when implementing arity-24 selected-child localization, when adding public/binary tuple fixture coverage for this shape, or if a future Binaryen source/oracle refresh stops localizing it.
