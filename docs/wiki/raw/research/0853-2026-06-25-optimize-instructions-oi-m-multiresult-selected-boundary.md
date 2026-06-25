# Optimize-instructions OI-M multi-result selected-lane boundary

_Date:_ 2026-06-25
_Status:_ completed boundary sub-slice for `[O4Z-AUDIT-OI-M]`

## Question

Can Starshine's current `tuple.extract(tuple.make(...))` helper safely fold or localize a selected tuple child that itself produces multiple results?

## Binaryen `version_130` evidence

Probe: `.tmp/oi-m-tuple-multiresult-selected-probe.wat`.

```wat
(module
  (func $pair (import "m" "pair") (result i64 i32))
  (func $selected (export "selected") (result i64)
    (tuple.extract 3 0
      (tuple.make 2
        (call $pair)
        (i32.const 9))))
  (func $selected-second (export "selected_second") (result i32)
    (tuple.extract 3 1
      (tuple.make 2
        (call $pair)
        (i32.const 9))))
)
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-probe.wat -o -
```

Observed behavior: Binaryen materializes tuple scratch locals for the multi-result call, extracts and drops the non-selected values in order, stores the selected scalar in a temp local, and returns that scalar. This proves the shape is OI-owned upstream but also shows that correct lowering needs tuple-scratch reconstruction, not a simple selected-child forwarding rewrite.

## Starshine boundary

`src/passes/optimize_instructions_test.mbt` now includes:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected lane boundary`

The direct-HOT fixture builds a one-use `TupleMake` whose selected child is a multi-result `Call`. After `optimize-instructions`, Starshine keeps the root as `TupleExtract`, keeps the `TupleMake`, and keeps the multi-result `Call` available. This matches the current local proof boundary: the tuple.extract helper only forwards or localizes selected children that produce exactly one result.

No pass implementation changed in this sub-slice. The focused boundary test passed immediately.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-probe.wat -o -` passed and showed tuple-scratch/scalar-temp reconstruction for both selected first and selected second results from the multi-result child.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*multi-result selected lane*'` passed `1/1`.

## Classification

This is an explicit tuple-scratch localization boundary, not behavior parity for the upstream transform. Reopen when Starshine has a safe helper that can localize multi-result selected children, drop non-selected tuple lanes in evaluation order, and preserve validation/writeback invariants.
