# Optimize-instructions OI-K array.new_default get large-length trap boundary

Date: 2026-06-26

## Summary

This slice fixes a correctness gap in Starshine's `array.get(array.new_default(...), const-index)` cleanup. Binaryen `version_130` keeps `array.get` over `array.new_default` when the default-array length is negative or above the O4z-observed non-trapping allocation bound, even if the access index is in range for the signed integer spelling. Starshine previously folded those shapes to an element default or `unreachable`, which could erase the allocation-size trap.

## Oracle evidence

Fresh Binaryen probe:

```sh
wasm-opt --all-features -S --optimize-instructions \
  .tmp/oi-array-get-new-default-large-len-probe.wat \
  -o .tmp/oi-array-get-new-default-large-len-probe.out.wat
```

The output keeps `array.new_default`, `array.get`, and `i32.const 50000000`; it does not fold to a default value.

## Starshine change

- `src/passes/optimize_instructions.mbt`: `optimize_instructions_try_fold_array_get_new_fixed` now requires `array.new_default` lengths to satisfy `optimize_instructions_array_new_len_is_known_non_trapping(...)` before folding a constant-index get.
- `src/passes/optimize_instructions_test.mbt`: the existing `array.new_default` get test now covers negative and huge lengths as trap-preserving boundaries.

## Red-first evidence

Before the implementation, the focused test failed because the negative-length function had already been rewritten to raw `unreachable`:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt \
  --filter '*array.get of constant-size array.new_default defaults*'
```

After the implementation the same focused test passed `1/1`.

## Boundary

This is a correctness narrowing for `array.new_default` get folding only. It does not add safe localization for effectful default values, dynamic lengths, dynamic indices, or huge-allocation proofs beyond the existing `optimize_instructions_array_new_len_is_known_non_trapping` helper.
