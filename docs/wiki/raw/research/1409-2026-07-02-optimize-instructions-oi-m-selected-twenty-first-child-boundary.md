# Optimize Instructions OI-M Selected-Twenty-First Child Multi-Result Boundary

Date: 2026-07-02

## Question

Does Binaryen `version_130` localize the selected twenty-first scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-20 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-twenty-first-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 f32 i64 f32 f64 i32)))
  (func (result i32)
    (tuple.extract 22 20
      (tuple.make 22
        (call $many)
        (i32.const 21)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twenty-first-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-twenty-first-child-probe.binaryen.20260702.wat
```

## Finding

Binaryen localizes the twenty-one-result call into a tuple scratch local, extracts and drops the first lane, stores the selected twenty-first `i32` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for selected arities 2 through 20.

## Starshine coverage

Added direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected twenty-first child-lane boundary`

The test asserts Starshine keeps `TupleExtract` index `20`, the `TupleMake`, and the twenty-one-result selected `Call` unchanged. This is boundary-only evidence, not an implementation slice.

## Status

Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 20. This twenty-first child-lane shape is the next source-backed selected-child tuple-scratch boundary after the 2026-07-02 arity-20 slice. Reopen this boundary when implementing arity-21 selected-child localization, when adding public/binary tuple fixture coverage for this shape, or if a future Binaryen source/oracle refresh stops localizing it.
