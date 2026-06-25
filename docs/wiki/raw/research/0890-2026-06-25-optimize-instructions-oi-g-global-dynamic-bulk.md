# OptimizeInstructions OI-G global dynamic-size bulk-memory boundary

Date: 2026-06-25

## Summary

This boundary/status slice extends the dynamic-size bulk-memory matrix to a public-pipeline function where `memory.copy` and `memory.fill` use a mutable `global.get` for the size operand.

Binaryen `version_130` keeps both bulk-memory operations in this shape:

1. `memory.copy(local.get $dst, local.get $src, global.get $n)` remains `memory.copy`;
2. `memory.fill(local.get $dst, local.get $val, global.get $n)` remains `memory.fill`.

Starshine now has matching public-pipeline coverage proving it preserves the dynamic bulk operations and the local/global operand order instead of treating a global-backed size as one of the exact constant tiny lowering cases.

This is coverage/status evidence, not a red-first implementation slice. It narrows the OI-G dynamic-size boundary after the local-size and effectful-call dynamic-size probes without claiming zero-size cleanup, broader load/call raw-gate escapes, or additional `optimizeStoredValue` shapes.

## Evidence

- Binaryen oracle probe: `.tmp/oi-g-global-dynamic-bulk-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-global-dynamic-bulk-probe.wat -o -`
- Oracle result: Binaryen kept `local.get $dst; local.get $src; global.get $n; memory.copy` and `local.get $dst; local.get $val; global.get $n; memory.fill`.
- Starshine test: `src/passes/optimize_instructions_test.mbt`, public-pipeline test `optimize-instructions keeps global dynamic-size bulk-memory`
- Focused validation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*global dynamic-size bulk-memory*'` passed `1/1`.

## Status

- Counted as the fiftieth OI-G memory/load-store sub-slice.
- Remaining OI-G work includes broader source-backed `optimizeStoredValue` shapes, non-flat effect/control `memory.copy` localization, raw-gate escapes beyond current exact stack shapes, broader load/store canonicalization decisions, and zero-size bulk cleanup pending trap-relaxed/TNH/IIT support.
