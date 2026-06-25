# Optimize-instructions OI-G v128 zero memory.fill

Date: 2026-06-25

## Scope

This OI-G slice extends the exact constant-size `memory.fill` lowering surface to the narrow SIMD-safe zero-fill case: `memory.fill(dst, i32.const 0, i32.const 16)`.

This is a behavior implementation slice, not a boundary-only classification. The implementation is deliberately narrower than Binaryen's full repeated-byte SIMD fill materialization because Starshine currently only has a public HOT builder for `v128.const 0`; nonzero size-16 fills remain open until an arbitrary repeated-byte `v128.const` builder or equivalent representation is added.

## Binaryen oracle

Probe: `.tmp/oi-g-memory-fill-16-zero-probe.wat`

`wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-fill-16-zero-probe.wat -o -` lowers the size-16 zero fill to one SIMD store:

- destination address: original `local.get $dst`;
- stored value: `v128.const` all-zero lanes;
- store: `v128.store align=1`.

A companion nonzero probe `.tmp/oi-g-memory-fill-16-probe.wat` shows Binaryen also materializes repeated nonzero bytes as a `v128.const`, but this slice does not claim that broader nonzero surface.

## Starshine change

`src/passes/optimize_instructions_test.mbt` adds red-first public-pipeline coverage:

- `optimize-instructions expands constant sixteen-byte memory.fill to v128.store`

The test initially failed with the original `memory.fill` still present. `src/passes/optimize_instructions.mbt` now recognizes constant size `16` only when the fill value's low byte is zero, builds `v128.const 0`, and replaces the bulk fill with `v128.store` through the existing exact-store rewrite path.

## Validation

- Binaryen oracle probe above passed.
- Red-first `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*sixteen-byte memory.fill*'` failed before implementation with `memory.fill` still present.
- The same focused test passed `1/1` after implementation.

## Remaining boundaries

This does not close OI-G. Size-16 nonzero `memory.fill` remains a known parity gap pending arbitrary repeated-byte SIMD constant materialization. Zero-size `memory.fill`, nonconstant-size fills, non-local wider fill values beyond the documented byte-fill exceptions, and broader load/store canonicalization remain as documented OI-G boundaries.
