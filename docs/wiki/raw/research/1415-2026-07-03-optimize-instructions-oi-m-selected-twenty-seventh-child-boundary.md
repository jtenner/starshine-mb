# Optimize Instructions OI-M Selected-Twenty-Seventh Child Multi-Result Boundary

Date: 2026-07-03

## Question

Does Binaryen `version_130` localize the selected twenty-seventh scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-26 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-twenty-seventh-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 f32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32)))
  (func (result i32)
    (tuple.extract 28 26
      (tuple.make 28
        (call $many)
        (i32.const 27)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twenty-seventh-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-twenty-seventh-child-probe.binaryen.20260703.wat
```

## Finding

Binaryen localizes the twenty-seven-result call into a tuple scratch local, extracts and drops the first lane, stores the selected twenty-seventh `i32` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for selected arities 2 through 26.

## Starshine coverage

Added direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected twenty-seventh child-lane boundary`

The test asserts Starshine keeps `TupleExtract` index `26`, the `TupleMake`, and the twenty-seven-result selected `Call` unchanged. This is boundary-only evidence, not an implementation slice.

## Status

Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 26. This twenty-seventh child-lane shape is the next source-backed selected-child tuple-scratch boundary after the 2026-07-03 arity-26 slice. Reopen this boundary when implementing arity-27 selected-child localization, when adding public/binary tuple fixture coverage for this shape, or if a future Binaryen source/oracle refresh stops localizing it.
