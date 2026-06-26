# Optimize-instructions OI-M direct selected-sixteenth multi-result boundary

## Question

Does Binaryen `version_130` `--optimize-instructions` localize a direct `tuple.extract` that selects the sixteenth result from a sixteen-result call when there is no sibling `tuple.make` debris to preserve or drop?

## Probe

Input saved locally as `.tmp/oi-m-tuple-multiresult-selected-sixteenth-probe.wat`:

```wat
(module
  (import "env" "multi" (func $multi (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64)))
  (func (export "selected") (result i64)
    (tuple.extract 16 15
      (call $multi))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-sixteenth-probe.wat -o -
```

## Finding

Binaryen keeps the direct extraction spelling:

- `tuple.extract 16 15 (call $multi)` remains a direct `tuple.extract` over the multi-result call.
- No tuple scratch locals or scalar temp are synthesized because there are no sibling tuple values to preserve or drop.

This mirrors the direct selected-fifteenth no-sibling boundary and is narrower than the sibling-bearing selected-child tuple-scratch boundaries.

## Starshine coverage

`src/passes/optimize_instructions_test.mbt` now has direct-HOT boundary coverage named `optimize-instructions intentionally keeps direct multi-result selected sixteenth lane boundary`.

The test asserts that Starshine keeps the `TupleExtract` over the sixteen-result `Call`, preserves the selected child edge, and keeps lane index `15`.

## Classification

Boundary/status evidence, not red-first implementation work. The current Starshine tuple localizer still proves direct `tuple.extract(tuple.make(...))` selected-child shapes; direct multi-result calls without sibling tuple debris are keep-spelling boundaries under the probed Binaryen behavior.

## Follow-ups

OI-M remains incomplete. Remaining work includes a real multi-result selected/sibling tuple-scratch localizer, reducer/triage for sibling-bearing fifteenth-lane Binaryen validation failure if relevant, public/binary tuple fixture coverage where representable, full `simplify-locals` replay/reduction for the `InvalidChildRef(3, 0, 0)` blocker, dedicated `tuple-optimization` neighbor reductions, and broader tee/drop reconstruction.
