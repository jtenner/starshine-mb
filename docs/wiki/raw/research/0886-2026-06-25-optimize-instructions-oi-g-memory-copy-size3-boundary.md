# OptimizeInstructions OI-G size-3 `memory.copy` boundary

Date: 2026-06-25

## Summary

This boundary/status slice makes the non-power-of-two tiny `memory.copy` edge explicit. Binaryen `version_130` keeps:

```wat
local.get $dst
local.get $src
i32.const 3
memory.copy
```

rather than lowering the three-byte copy to a sequence of narrow loads/stores. Starshine's public-pipeline boundary test now locks the same keep-spelling behavior alongside the existing zero-size, oversized, and dynamic-size `memory.copy` boundaries.

This is coverage/status evidence, not a red-first implementation slice. It prevents over-generalizing the exact `1`/`2`/`4`/`8`/`16` one-load/one-store lowering to a size that would need either multiple stores or trap-relaxed reasoning not covered by the current OI implementation.

## Evidence

- Binaryen oracle probe: `.tmp/oi-g-memory-copy-size3-boundary-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size3-boundary-probe.wat -o -`
- Oracle result: Binaryen kept `memory.copy` with `local.get $dst`, `local.get $src`, and `i32.const 3`; no `i32.load8u`, `i32.load16u`, `i32.store8`, or `i32.store16` sequence was introduced.
- Starshine test: `src/passes/optimize_instructions_test.mbt`, public-pipeline test `optimize-instructions keeps memory.copy outside exact tiny lowering boundary`
- Focused validation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.copy outside exact tiny lowering boundary*'` passed `2/2`.

## Status

- Counted as the forty-eighth OI-G memory/load-store sub-slice.
- Boundary remains narrow: size `1`/`2`/`4`/`8`/`16` constant copies still lower to one exact load/store pair; this note only covers the non-power-of-two size-3 spelling.
- Broader OI-G work remains open for source-backed `optimizeStoredValue` shapes, non-flat/effect/control bulk-memory localization, raw-gate escapes beyond current exact stack shapes, and broader load/store canonicalization decisions.
