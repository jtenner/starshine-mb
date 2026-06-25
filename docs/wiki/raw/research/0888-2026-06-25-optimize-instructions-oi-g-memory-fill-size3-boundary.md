# OptimizeInstructions OI-G size-3 `memory.fill` boundary

Date: 2026-06-25

## Summary

This boundary/status slice makes the non-power-of-two tiny `memory.fill` edge explicit. Binaryen `version_130` keeps:

```wat
local.get $dst
local.get $value
i32.const 3
memory.fill
```

rather than lowering the three-byte fill to a sequence of partial stores. Starshine's public-pipeline boundary test now locks the same keep-spelling behavior.

This is coverage/status evidence, not a red-first implementation slice. It prevents over-generalizing the exact `1`/`2`/`4`/`8`/`16` fill lowering set to a size that would need a multi-store materialization plan and stronger trap/effect proof than the current OI implementation claims.

## Evidence

- Binaryen oracle probe: `.tmp/oi-g-memory-fill-size3-boundary-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-fill-size3-boundary-probe.wat -o -`
- Oracle result: Binaryen kept `memory.fill` with `local.get $dst`, `local.get $value`, and `i32.const 3`; no `i32.store8`, `i32.store16`, `i32.store`, `i64.store`, or `v128.store` sequence was introduced.
- Starshine test: `src/passes/optimize_instructions_test.mbt`, public-pipeline test `optimize-instructions keeps size-3 memory.fill outside exact lowering boundary`
- Focused validation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*size-3 memory.fill*'` passed `1/1`.

## Status

- Counted as the forty-ninth OI-G memory/load-store sub-slice.
- Boundary remains narrow: size `1`/`2`/`4`/`8`/`16` fills still lower when the value shape is in the covered constant/direct-local subset; this note only covers the non-power-of-two size-3 spelling.
- Broader OI-G work remains open for source-backed `optimizeStoredValue` shapes, non-flat/effect/control bulk-memory localization, raw-gate escapes beyond current exact stack shapes, and broader load/store canonicalization decisions.
