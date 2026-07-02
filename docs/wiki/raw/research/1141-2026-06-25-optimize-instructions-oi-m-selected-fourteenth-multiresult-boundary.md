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

Added direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected fourteenth lane boundary`

The test asserts Starshine keeps `TupleExtract` index `13`, the `TupleMake`, and the multi-result `Call` unchanged. This is boundary-only evidence, not a red-first implementation slice.

## Status

Starshine's current tuple.extract OI localizer now supports direct one-use selected children through arity 13. This fourteenth-lane shape remains the next source-backed selected-child tuple-scratch boundary after the 2026-07-02 arity-13 slice. Reopen this boundary when implementing arity-14 selected-child localization, when adding public/binary tuple fixture coverage for this shape, or if a future Binaryen source/oracle refresh stops localizing it.
