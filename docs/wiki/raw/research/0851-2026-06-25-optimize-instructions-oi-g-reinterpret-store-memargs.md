# Optimize-instructions OI-G reinterpret-store memarg preservation

## Slice

Continue `[O4Z-AUDIT-OI-G]` by locking a stored-value detail for the already implemented representation-store rewrite: when a direct reinterpret child lets OI rewrite a store to the equivalent representation store, the original store offset/alignment memargs must be preserved.

## Binaryen oracle

Probe: `.tmp/oi-g-reinterpret-store-memarg-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-reinterpret-store-memarg-probe.wat -o -
```

Result: Binaryen `version_130` removes the reinterpret opcodes and preserves the original memargs:

- `f32.store offset=4 align=1 (f32.reinterpret_i32 v)` becomes `i32.store offset=4 align=1 v`.
- `f64.store offset=8 align=2 (f64.reinterpret_i64 v)` becomes `i64.store offset=8 align=2 v`.
- `i32.store offset=12 align=1 (i32.reinterpret_f32 v)` becomes `f32.store offset=12 align=1 v`.
- `i64.store offset=16 align=4 (i64.reinterpret_f64 v)` becomes `f64.store offset=16 align=4 v`.

## Starshine result

The existing Starshine implementation already copied the source memarg into the replacement store. Focused coverage now protects this so representation-store parity is not accidentally reduced to opcode-only rewriting.

## Test evidence

Added `src/passes/optimize_instructions_test.mbt` coverage:

- `optimize-instructions preserves memargs when rewriting reinterpret stores`

The first focused run failed because the assertion used WAT text-style `offset=4 align=1` strings, while Starshine's pretty-printer renders memargs as `align=U32(log2) offset=U64(n)`. After correcting the assertion to the local pretty format, the test passed without implementation changes. This was assertion-format red evidence, not a behavior failure.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-reinterpret-store-memarg-probe.wat -o -` passed and preserved offset/alignment while rewriting to representation stores.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memargs when rewriting reinterpret stores*'` passed `1/1` after assertion-format correction.

## Remaining OI-G risks

This only locks memarg preservation for direct one-use reinterpret stored-value rewrites. It does not widen local-carried/shared reinterpret-store forms, broader `optimizeStoredValue` families, raw-gate escapes, or zero-size bulk-memory cleanup.
