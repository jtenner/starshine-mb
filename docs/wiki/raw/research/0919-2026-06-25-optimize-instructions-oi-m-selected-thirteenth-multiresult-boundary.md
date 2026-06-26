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

Binaryen localizes the imported multi-result call into tuple scratch, extracts the thirteenth scalar lane (`tuple.extract 13 12`) into an `f32` temp, drops the tee, and returns the scalar temp. This matches the previous selected-first through selected-twelfth probes: Binaryen has a tuple-scratch reconstruction path for selected multi-result children.

## Starshine coverage

Added direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected thirteenth lane boundary`

The test builds a direct-HOT tuple with a thirteen-result selected `Call` child plus an extra scalar child, runs `optimize-instructions`, and asserts Starshine keeps the `TupleExtract` index `12`, the `TupleMake`, and the multi-result `Call` unchanged. This is boundary-only evidence, not a red-first implementation slice.

## Status

Starshine intentionally keeps selected multi-result tuple children unchanged until a safe tuple-scratch localizer exists. Reopen this when implementing multi-result selected-child localization, when adding public/binary tuple fixture coverage for this shape, or if a future Binaryen source/oracle refresh stops localizing the selected thirteenth lane.
