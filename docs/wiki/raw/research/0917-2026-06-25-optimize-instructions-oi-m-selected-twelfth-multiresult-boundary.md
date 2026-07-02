# Optimize Instructions OI-M Selected-Twelfth Multi-Result Tuple Boundary

Date: 2026-06-25

## Question

Does Binaryen `version_130` localize the selected twelfth scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine keep the current direct-HOT spelling until a selected-child tuple-scratch localizer exists?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-twelfth-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64)))
  (func (result i64)
    (tuple.extract 13 11
      (tuple.make 13
        (call $many)
        (i32.const 12)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twelfth-probe.wat -o -
```

## Finding

Binaryen localizes the imported multi-result call into tuple scratch, extracts the twelfth scalar lane (`tuple.extract 12 11`) into an `i64` temp, drops the tee, and returns the scalar temp. This matches the previous selected-first through selected-eleventh probes: Binaryen has a tuple-scratch reconstruction path for selected multi-result children. After the 2026-07-02 arity-11 Starshine implementation slice, this twelfth-lane shape is the next direct one-use selected-child boundary.

## Starshine coverage

Added direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected twelfth lane boundary`

The test builds a direct-HOT tuple with a twelve-result selected `Call` child plus an extra scalar child, runs `optimize-instructions`, and asserts Starshine keeps the `TupleExtract` index `11`, the `TupleMake`, and the multi-result `Call` unchanged. This is boundary-only evidence, not a red-first implementation slice.

## Status

Starshine intentionally keeps selected multi-result tuple children wider than the current bounded arity-11 localizer unchanged until the cap moves again or a generalized tuple-scratch localizer exists. Reopen this when implementing arity-12 selected-child localization, when adding public/binary tuple fixture coverage for this shape, or if a future Binaryen source/oracle refresh stops localizing the selected twelfth lane.
