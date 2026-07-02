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

Binaryen localizes the multi-result call through a tuple scratch local, extracts the eleventh scalar lane, stores it into a scalar temp, and returns that scalar temp. This matches the previously observed selected-first through selected-tenth family: Binaryen has a tuple-scratch localizer for selected multi-result children. After the 2026-07-02 arity-10 Starshine implementation slice, this eleventh-lane shape is now the next direct one-use selected-child arity boundary.

## Starshine coverage

Added direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected eleventh lane boundary`

The test builds a direct HOT tuple whose selected child is an eleven-result call and whose selected lane is index `10`. Starshine keeps the `TupleExtract`, `TupleMake`, and multi-result `Call` unchanged. This is boundary-only evidence after the arity-10 implementation, not a red-first implementation slice.

## Status

Starshine now has a bounded direct one-use selected-child localizer through arity 10, but still needs either an arity-11 implementation or an accepted blocker before matching this Binaryen shape. Reopen this boundary when the bounded cap moves again, when public tuple text/binary fixture support improves, or if Binaryen changes this shape.
