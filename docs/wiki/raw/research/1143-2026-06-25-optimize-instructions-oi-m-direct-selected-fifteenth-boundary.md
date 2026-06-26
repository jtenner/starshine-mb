# Optimize-instructions OI-M direct selected-fifteenth multi-result boundary

## Question

Does Binaryen `version_130` `--optimize-instructions` localize a direct `tuple.extract` of the fifteenth result from a fifteen-result call when there are no sibling `tuple.make` values to preserve or drop?

## Probe

Input saved locally as `.tmp/oi-m-tuple-multiresult-selected-fifteenth-probe.wat`:

```wat
(module
  (import "env" "multi"
    (func $multi (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32)))
  (func (export "selected") (result i32)
    (tuple.extract 15 14
      (call $multi))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-fifteenth-probe.wat -o -
```

## Finding

Binaryen keeps the direct `tuple.extract 15 14 (call $multi)` spelling. Unlike the previous selected-lane probes with a wrapping `tuple.make` and extra sibling values, this no-sibling shape does not trigger tuple-scratch localization.

A separate exploratory `tuple.make` probe with a fifteen-result selected child plus an extra scalar sibling caused Binaryen to emit an invalid transformed module during validation, so this slice deliberately records only the successful direct no-sibling oracle shape.

## Starshine coverage

`src/passes/optimize_instructions_test.mbt` now has direct-HOT boundary coverage named `optimize-instructions intentionally keeps direct multi-result selected fifteenth lane boundary`.

The test builds a fifteen-result call, extracts lane `14`, runs `optimize-instructions`, and asserts that the pass keeps the `TupleExtract` and multi-result `Call` connected unchanged.

## Classification

Boundary/status evidence, not red-first implementation work. This is narrower than the selected-first through selected-fourteenth tuple-scratch boundary set: it locks a successful direct no-sibling selected-fifteenth oracle shape and explicitly avoids claiming tuple-scratch parity for the sibling-bearing fifteenth-lane variant.

## Follow-ups

OI-M remains incomplete. Remaining work includes a real multi-result selected/sibling tuple-scratch localizer, a reducer for the sibling-bearing fifteenth-lane Binaryen validation failure if it matters for parity, full `simplify-locals` replay/reduction for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, public/binary tuple fixture coverage where representable, and broader tee/drop reconstruction.
