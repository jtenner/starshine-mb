---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../../../raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md
  - ../../../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./static-offsets-dynamic-operands-and-grow-repair.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Starshine port-readiness and validation plan for `memory64-lowering`

## Current local truth

Starshine does not currently implement or register Binaryen's `memory64-lowering` or `table64-lowering` pass names.
Requests for either name are unknown-pass behavior today, not honest boundary-only rejection.

The local code has enough wasm64/table64 representation to plan a port, but not enough complete table typing to advertise both siblings as ready:

- `src/passes/optimize.mbt:127` starts the boundary-only registry list; neither name appears there.
- `src/passes/optimize.mbt:144` starts the removed-name registry list; neither name appears there.
- `src/passes/optimize.mbt:156` starts active registry entries; neither name appears there.
- `src/lib/types.mbt:162` through `:177` define `Limits`, `MemType`, and `TableType`, including `I64Limits`.
- `src/lib/types.mbt:1263` maps limits to address value types, and `src/lib/types.mbt:1366` models mixed-width copy length selection.
- `src/validate/typecheck.mbt:1538` through `:1577` already rejects high static memory-operation `offset=` immediates for i32 memories.
- `src/validate/typecheck.mbt:2408` through `:2498` derives memory `size`, `grow`, `init`, and `copy` stack types from memory limits.
- `src/validate/typecheck.mbt:2502` derives `memory.fill` destination width from memory limits but still hard-codes the length operand to `i32`; the focused refresh in [`../../../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md`](../../../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md) records this local/spec divergence.
- `src/validate/typecheck.mbt` still hard-codes `i32` for `table.get`, `table.set`, `table.size`, `table.grow`, `call_indirect`, and `return_call_indirect` table index/result positions; `table.fill` is only partially widened locally because its destination/start operand uses the table limit width but its length operand remains `i32`. [`../../../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md`](../../../raw/wasm/2026-05-20-table64-table-instruction-validation-refresh.md) records this local/spec divergence.

## Port goal

A faithful Starshine port should turn a wasm64 memory module into a wasm32 memory module while preserving validation and runtime behavior for the representable 32-bit address space.
A later table64 sibling should do the same for table indexes after table typechecking is made coherent.

This is a module pass because it must rewrite declarations, active segments, function bodies, and feature metadata together.

## Recommended implementation ladder

### Slice 0: registry honesty and no-op analyzer

- Decide whether to add both names as `BoundaryOnly` while planning, or keep them unknown until implementation starts.
- Add a no-op module analyzer that reports:
  - memories with `I64Limits`;
  - tables with `I64Limits`;
  - active data and element offsets typed by those declarations;
  - memory/table instructions whose operand or result type changes after declaration lowering.
- Validate that no-op mode preserves binary output exactly.

Exit criteria:

- CLI/pass registry tests prove the chosen status for both public names.
- Analyzer fixtures cover declaration-only memory64, active data, one scalar load, `memory.size`, `memory.grow`, and one table64 declaration without mutating output.

### Slice 1: memory declaration and active data offsets

- Rewrite `MemType(I64Limits(...), shared)` to `MemType(I32Limits(...), shared)`.
- Clamp or reject maximum limits according to the local policy chosen from the Binaryen source caveat.
- Lower active data offset expressions from former memory64 address type to i32 expression form.
- Clear or update memory64 feature metadata only when the whole module no longer uses memory64.

Exit criteria:

- Declaration-only modules lower to memory32.
- Active data offset fixtures validate after lowering.
- Impossible minimum-limit policy is tested as either a clear error or a documented assertion/precondition, not an accidental panic.

### Slice 2: scalar load/store body lowering

- For dynamic former-i64 address operands, insert `i32.wrap_i64` before the lowered load/store.
- Preserve syntactic `i64.const` operands as dynamic stack expressions that still wrap.
- For static `MemArg.offset >= 2^32`, replace the memory operation with `unreachable` while preserving child effects.
- Reuse Starshine's existing `MemArg` validation intuition from `src/validate/typecheck.mbt:1538` through `:1577`.

Exit criteria:

- Dynamic local and dynamic constant address cases match Binaryen.
- Static high-`offset=` cases trap/validate like Binaryen.
- Child-effect preservation tests include a side-effecting address expression.

### Slice 3: size and grow result repair

- Lower `memory.size` to the memory32 operation plus `i64.extend_i32_u` when the surrounding former type expects i64.
- Lower `memory.grow` by wrapping the delta operand and repairing the result with wasm64 failure-sentinel semantics.
- Keep grow separate from size in tests; grow is not just unsigned extension because failure returns `-1`.

Exit criteria:

- Successful `memory.grow` result is zero-extended.
- Failed grow returns the wasm64 sentinel expected by the original type.
- The lowered output validates under Starshine and matches Binaryen normalized WAT for representative fixtures.

### Slice 4: bulk memory, SIMD, and atomics

- Lower `memory.init`, `memory.fill`, and `memory.copy` operands positionally.
- Preserve the official `memory.init` split: destination follows the selected memory address type, while passive-data source offset and length stay `i32`.
- Preserve the Binaryen rule that copy length becomes i64 only when both participating memories are 64-bit before lowering; mixed-width cases are positional.
- Treat `memory.fill` as destination `at`, byte value `i32`, length `at`; fix the current local validator length caveat before using Starshine validation as positive evidence for memory64 `memory.fill`.
- Add SIMD and atomic address operand wrapping after scalar memory tests are green.

Exit criteria:

- Mixed memory32/memory64 copy fixtures match Binaryen.
- Memory64 `memory.init` and `memory.fill` fixtures prove destination/source/value/length positions independently.
- SIMD and atomic fixtures prove address-width changes do not accidentally rewrite payload/result vector or integer types.
- Existing memory-packing / instrument-memory tests still validate after the new pass is registered.

### Slice 5: table64 sibling after typechecker cleanup

- First fix table typing so table operations use `TableType` limits consistently rather than hard-coded `i32`.
- Include the targeted `table.fill` cleanup: destination/start and length must both follow the selected table address type, while the reference value stays at the table element type.
- Then add declaration, active element offset, `table.get`, `table.set`, `table.size`, `table.grow`, and table bulk-operation lowering.

Exit criteria:

- Table64 fixtures validate before and after lowering.
- `table.grow` has the same failure-sentinel repair discipline as `memory.grow`.
- The sibling status is explicit: implemented, boundary-only, or intentionally omitted.

## Binaryen oracle lanes

Use official Binaryen as the oracle in three lanes:

1. `wasm-opt --memory64-lowering` on memory-only fixtures.
2. `wasm-opt --table64-lowering` on table-only fixtures.
3. Combined memory/table fixtures only after both local siblings are real.

Mirror the official lit intent from:

- `test/lit/passes/memory64-lowering.wast`
- `test/lit/passes/table64-lowering.wast`

For every Starshine fixture, compare:

- validation before and after lowering;
- normalized WAT shape;
- binary re-encode/decode roundtrip;
- pass registry behavior for unsupported sibling names.

## Non-goals for the first port

- Do not optimize address arithmetic.
- Do not infer dynamic in-range facts.
- Do not fold dynamic `i64.const` address operands into static high-offset traps; Binaryen's corrected contract wraps stack operands and reserves the high-offset trap family for static `MemArg.offset` immediates.
- Do not advertise full local memory64 bulk-memory validation until the `memory.fill` length caveat is resolved.
- Do not advertise table64 parity until table operation typechecking is coherent, including the `table.fill` length rule.

## Open questions

- Should impossible lowered minimum limits be a graceful Starshine error, a validation precondition, or a Binaryen-parity assertion-like internal failure? The current wiki records the source caveat but leaves local policy open.
- Should Starshine register `memory64-lowering` as boundary-only before the no-op analyzer lands, or keep unknown-pass behavior until there is at least a tested module-pass skeleton?
- Should feature-section cleanup happen in the first declaration slice or only after function/segment lowering is complete?
