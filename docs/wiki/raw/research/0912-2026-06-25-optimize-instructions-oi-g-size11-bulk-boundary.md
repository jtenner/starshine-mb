# OptimizeInstructions OI-G size-11 bulk-memory boundary

Date: 2026-06-25

## Summary

This boundary/status slice locks the OI-G size-11 bulk-memory behavior for `memory.copy` and `memory.fill`.

Binaryen `version_130` keeps size-11 `memory.copy` and `memory.fill` as bulk-memory operations. It does not synthesize a mixed 8+2+1 load/store sequence, even though Starshine lowers exact 1/2/4/8/16 copies and exact 1/2/4/8/16 fills when their other preconditions hold.

Starshine now has public-pipeline coverage proving it keeps the size-11 bulk-memory spelling and does not accidentally generalize exact tiny lowering beyond the source-backed sizes.

This is boundary/status evidence, not a red-first implementation slice.

## Evidence

- Binaryen oracle probe: `.tmp/oi-g-memory-copy-size11-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size11-probe.wat -o -`
- Oracle result: Binaryen kept both `memory.copy(local.get $dst, local.get $src, i32.const 11)` and `memory.fill(local.get $dst, local.get $value, i32.const 11)`.
- Starshine test: `src/passes/optimize_instructions_test.mbt`, public-pipeline test `optimize-instructions keeps size-11 bulk-memory outside exact lowering boundary`
- Focused validation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*size-11 bulk-memory*'` passed `1/1`.

## Status

- Counted as the fifty-fourth OI-G memory/load-store sub-slice.
- Remaining OI-G work includes broader source-backed `optimizeStoredValue` shapes, non-flat effect/control `memory.copy` localization, raw-gate escapes beyond current exact stack shapes, broader load/store canonicalization decisions, and zero-size bulk cleanup pending trap-relaxed/TNH/IIT support.
