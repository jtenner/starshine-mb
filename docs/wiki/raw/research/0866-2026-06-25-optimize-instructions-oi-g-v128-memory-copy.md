# Optimize-instructions OI-G v128 memory.copy lowering

Date: 2026-06-25

## Scope

This OI-G slice extends the exact constant-size `memory.copy` lowering from sizes `1`/`2`/`4`/`8` to size `16`.

Binaryen `version_130` lowers a size-16 copy to one `v128.load` followed by one `v128.store`, which is overlap-safe for the same reason as the existing scalar tiny-copy lowerings: the full source value is loaded before the destination store executes.

## Binaryen oracle

Probe: `.tmp/oi-g-memory-copy-16-probe.wat`

`wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-16-probe.wat -o -` rewrites:

- `memory.copy(dst, src, i32.const 16)`

into:

- `v128.store(dst, v128.load(src))` with alignment `1`.

## Starshine change

`src/passes/optimize_instructions.mbt` now maps constant copy size `16` to:

- load type `v128`;
- exact load instruction `v128.load`;
- exact store instruction `v128.store`.

`src/passes/pass_manager.mbt` also admits size `16` in the tiny bulk-memory raw-gate size predicate so flat stack-carried size-16 copy forms can reach HOT instead of being skipped before lowering.

## Test coverage

`src/passes/optimize_instructions_test.mbt` extends `optimize-instructions expands wider tiny memory.copy to exact load/store` to include a public-pipeline size-16 copy and assert that `memory.copy` disappears in favor of `v128.load` / `v128.store`.

The focused test failed before implementation with the size-16 `memory.copy` still present, then passed after adding the v128 lowering and raw-gate size admission.

## Validation

- Binaryen oracle probe above passed.
- Red-first focused test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*wider tiny memory.copy*'` failed before implementation and passed after implementation.

## Remaining boundaries

This supersedes the old size-16 keep-spelling boundary from `docs/wiki/raw/research/0738-2026-06-19-optimize-instructions-oi-g-memory-copy-boundaries.md` for the direct one-load/one-store SIMD case. Zero-size, nonconstant-size, larger-than-16, and any future multi-store `memory.copy` lowering remain open or boundary-tested until there is source-backed evidence and an overlap-safe proof.
