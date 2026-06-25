# Optimize-instructions OI-M selected second-lane boundary

_Date:_ 2026-06-25
_Status:_ completed boundary sub-slice for `[O4Z-AUDIT-OI-M]`

## Question

Does the existing Starshine direct-HOT multi-result selected-child boundary also protect extracting the second scalar lane produced by a selected multi-result tuple child?

## Binaryen `version_130` evidence

Probe: `.tmp/oi-m-tuple-multiresult-selected-second-probe.wat`.

```wat
(module
  (func $pair (import "m" "pair") (result i64 i32))
  (func $selected_second (export "selected_second") (result i32)
    (tuple.extract 3 1
      (tuple.make 2
        (call $pair)
        (i32.const 9))))
)
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-second-probe.wat -o -
```

Observed behavior: Binaryen materializes tuple scratch locals for the multi-result call and the reconstructed tuple, drops the first scalar, stores the second scalar result in a temp local, and returns that temp. This confirms that extracting the second lane is upstream OI-owned but needs tuple-scratch reconstruction.

## Starshine boundary

`src/passes/optimize_instructions_test.mbt` now includes:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected second lane boundary`

The direct-HOT fixture builds a one-use `TupleMake` whose selected child is a multi-result `Call`, then extracts index `1` from the flattened tuple. After `optimize-instructions`, Starshine keeps the root as `TupleExtract`, keeps the `TupleMake`, records extract index `1`, and keeps the multi-result `Call` available.

No pass implementation changed in this sub-slice. This is boundary/status coverage, not red-first behavior-failure evidence: the focused test passed immediately.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-second-probe.wat -o -` passed and showed tuple-scratch/scalar-temp reconstruction for the selected second result.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*multi-result selected second lane*'` passed `1/1`.

## Remaining work

This does not implement Binaryen's tuple-scratch localization. Multi-result selected children, multi-result non-selected siblings, broader tee/drop reconstruction, public tuple text/binary fixtures, and wider `tuple-optimization` / `simplify-locals` neighbor signoff remain tracked under `[O4Z-AUDIT-OI-M]`.
