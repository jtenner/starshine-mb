# OptimizeInstructions OI-G local size-16 `memory.fill` boundary

Date: 2026-06-25

## Summary

This boundary slice extends the OI-G non-local/wider `memory.fill` evidence to a direct `local.get` value at SIMD width. Binaryen `version_130` keeps:

```wat
local.get $dst
local.get $value
i32.const 16
memory.fill
```

rather than materializing a repeated-byte `v128.const` / `v128.store` from the local value. Starshine now has public-pipeline coverage locking the same keep-spelling behavior.

This is coverage/status evidence, not a red-first implementation slice. It prevents over-generalizing the covered constant size-16 `memory.fill` lowering and the covered direct-local size-2/4/8 materialization to a local-backed SIMD-width fill that Binaryen keeps.

## Evidence

- Binaryen oracle probe: `.tmp/oi-g-local-v128-memory-fill-boundary-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-local-v128-memory-fill-boundary-probe.wat -o -`
- Oracle result: Binaryen kept `memory.fill` with `local.get $dst`, `local.get $value`, and `i32.const 16`; no `v128.store` was introduced.
- Starshine test: `src/passes/optimize_instructions_test.mbt`, public-pipeline test `optimize-instructions intentionally keeps non-local wider memory.fill values`
- Focused validation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*non-local wider memory.fill values*'` passed `1/1`.

## Status

- Counted as the forty-seventh OI-G memory/load-store sub-slice.
- Boundary remains narrow: constants at size 16 still lower to `v128.const` / `v128.store`; direct local.get values at sizes 2/4/8 still materialize repeated-byte stores; this note only covers local-backed size-16 fill values.
- Broader OI-G work remains open for source-backed `optimizeStoredValue` shapes, non-flat/effectful control in bulk-memory localization, and broader raw-gate escapes.
