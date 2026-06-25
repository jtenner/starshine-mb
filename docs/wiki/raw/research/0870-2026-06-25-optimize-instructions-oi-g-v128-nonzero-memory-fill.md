# Optimize-instructions OI-G v128 nonzero memory.fill

Date: 2026-06-25

## Scope

This OI-G slice completes the constant-size-16 repeated-byte `memory.fill` lowering that the previous zero-fill slice left open. Starshine now lowers `memory.fill(dst, i32.const BYTE, i32.const 16)` to a repeated-byte `v128.const` plus one `v128.store` for any constant fill value, using the low byte exactly like the smaller `memory.fill` lowerings.

This is a behavior implementation slice, not a boundary-only classification. Nonconstant size-16 fill values remain outside this slice.

## Binaryen oracle

Probe: `.tmp/oi-g-memory-fill-16-nonzero-probe.wat`

`wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-fill-16-nonzero-probe.wat -o -` lowers `memory.fill(dst, i32.const 171, i32.const 16)` to:

- destination address: original `local.get $dst`;
- stored value: `v128.const i32x4 0xabababab ...`;
- store: `v128.store align=1`.

This matches the earlier zero-fill probe while proving the nonzero repeated-byte SIMD materialization is OI-owned by Binaryen `version_130`.

## Starshine change

`src/ir/hot_builders.mbt` adds `hot_build_const_v128_splat`, a public HOT builder for repeated-byte `v128.const` values. `hot_build_const_v128_zero` now delegates to that helper.

`src/passes/optimize_instructions.mbt` uses the new builder in `optimize_instructions_try_expand_tiny_memory_fill` so constant size-16 fills materialize a repeated-byte SIMD constant instead of accepting only zero.

`src/passes/optimize_instructions_test.mbt` extends the existing public-pipeline test `optimize-instructions expands constant sixteen-byte memory.fill to v128.store` with a nonzero `i32.const 171` function. The test failed red-first with the nonzero `memory.fill` still present, then passed after implementation.

## Validation

- Binaryen oracle probe above passed.
- Red-first `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*sixteen-byte memory.fill*'` failed before implementation because the nonzero function still contained `memory.fill`.
- The same focused test passed `1/1` after implementation.

## Remaining boundaries

This does not close OI-G. Zero-size `memory.fill`, nonconstant-size fills, nonconstant size-16 fill values, non-local wider fill values beyond the documented byte-fill exceptions, and broader load/store canonicalization remain as documented OI-G boundaries.
