# Optimize Instructions OI-G size-19 bulk-memory boundary

Date: 2026-06-26

## Summary

Boundary/status slice for `[O4Z-AUDIT-OI-G]`.

Binaryen `version_130` direct `--optimize-instructions` keeps constant-size-19 `memory.copy` and `memory.fill` in bulk-memory form. It does not synthesize a 16-byte SIMD lane plus trailing scalar load/store sequence.

Starshine already matched this narrow boundary: the existing tiny bulk-memory lowering remains limited to exact sizes `1`, `2`, `4`, `8`, and `16` for `memory.copy`, plus the corresponding proven `memory.fill` lanes. This slice adds explicit public-pipeline coverage so future OI work does not accidentally widen size-19 lowering without source-backed proof and validation evidence.

## Binaryen oracle

Probe file: `.tmp/oi-g-memory-copy-size19-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size19-probe.wat -o -
```

Observed output keeps both bulk operations:

- `memory.copy(local.get $dst, local.get $src, i32.const 19)` remains `memory.copy`
- `memory.fill(local.get $dst, local.get $value, i32.const 19)` remains `memory.fill`

This is a boundary, not a missing Starshine lowering.

## Starshine coverage

Added focused public-pipeline test in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions keeps size-19 bulk-memory outside exact lowering boundary`

The test asserts both bulk operations remain and that no scalar or SIMD load/store lowering appears.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size19-probe.wat -o -` — passed; Binaryen kept size-19 bulk-memory spelling.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*size-19 bulk-memory*'` — passed `1/1`.

## Backlog impact

This increments OI-G boundary/status coverage beyond the first sixty-two memory/load-store sub-slices. Remaining OI-G work still includes source-backed stored-value/load-result canonicalization, broader raw-gate escapes, and any future evidence that Binaryen lowers additional exact constant-size bulk-memory forms. Size-19 itself is a keep-spelling boundary under the current `version_130` oracle.
