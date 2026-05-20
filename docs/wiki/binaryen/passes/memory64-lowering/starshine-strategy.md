---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md
  - ../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md
  - ../../../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./static-offsets-dynamic-operands-and-grow-repair.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
---

# Starshine strategy for `memory64-lowering`

## Current status

Starshine does **not** currently implement Binaryen's `memory64-lowering` or `table64-lowering` pass.

The local status is stronger than “not yet ported”:

- `src/passes/optimize.mbt` contains no registry entry for either pass name;
- the pass is therefore not `HotPass`, `ModulePass`, `Removed`, or `BoundaryOnly` in the current registry vocabulary;
- no owner file, dispatch case, preset slot, parity page, or active backlog slice was found in this run.

So today's correct user-facing description is:

> Starshine can model several memory64/table64 surfaces, but it has no wasm64-to-wasm32 lowering pass today.

The concrete future implementation ladder now lives in [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md): registry honesty, a no-op analyzer, memory declaration/data-offset lowering, scalar body lowering, size/grow repair, bulk/SIMD/atomic memory coverage, and a later table64 sibling after table typing cleanup.

## Relevant local surfaces

### Registry and request behavior

- `src/passes/optimize.mbt:127` starts `pass_registry_boundary_only_names()`; neither `memory64-lowering` nor `table64-lowering` appears in that list.
- `src/passes/optimize.mbt:144` starts `pass_registry_removed_names()`; neither pass appears there either.
- `src/passes/optimize.mbt:156` starts `pass_registry_entries()`; the active hot/module/preset entries do not include either pass.

Together these exact locations make current request behavior an unknown-pass case, not an honest boundary-only rejection.

### Shared IR model

- `src/lib/types.mbt:162` defines `Limits::I32Limits` and `Limits::I64Limits`.
- `src/lib/types.mbt:174` defines `MemType` as the memory-level carrier of `Limits` plus sharedness.
- `src/lib/types.mbt:177` defines `TableType` as the table-level carrier of element reference type plus `Limits`.
- `src/lib/types.mbt:1263` defines `Limits::addr_valtype(...)`, mapping `I32Limits` to `i32` and `I64Limits` to `i64`.
- `src/lib/types.mbt:1366` defines `min_addr_valtype(...)`, the mixed-width helper shape a future memory/table copy lowering would need.

### Binary format

- `src/binary/decode.mbt`
  - decodes generic `Limits` with 32-bit and 64-bit forms;
  - decodes `MemType` memory64/shared-memory forms with bytes `0x04` through `0x07`;
  - decodes `TableType` through `RefType` plus `Limits`.
- `src/binary/encode.mbt`
  - encodes 32-bit and 64-bit `Limits`;
  - encodes memory64 `MemType` variants.

### Validation and typechecking

- `src/validate/validate.mbt:895` validates `MemType`; lines `902`-`905` select `65536` pages for `I32Limits` and the much larger `UInt64` page cap for `I64Limits`.
- `src/validate/typecheck.mbt:371` defines `TcState::mem_at_of(...)`, which derives memory address/result value type from each memory's `Limits`.
- `src/validate/typecheck.mbt:1538` defines `memarg_check(...)`; lines `1570`-`1577` reject a static memarg offset at or above `2^32` for i32 memories.
- `src/validate/typecheck.mbt:1591` / `1610` feed `memarg_check(...)` into scalar load/store address typing; the same pattern appears for atomics and SIMD memory helpers.
- `src/validate/typecheck.mbt:2408` and `2417` derive `memory.size` and `memory.grow` types from `mem_at_of(...)`.
- `src/validate/typecheck.mbt:2433` derives `memory.init` destination width from the selected memory while keeping passive-data source and length as `i32`.
- `src/validate/typecheck.mbt:2468` derives `memory.copy` destination, source, and length widths from the participating memories.
- `src/validate/typecheck.mbt:2502` derives the `memory.fill` destination width from the selected memory but still hard-codes the length operand to `i32`; [`../../../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md`](../../../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md) records this local/spec divergence.
- `src/validate/typecheck.mbt:1437`, `1470`, and `1501` use table limits for `table.copy`, `table.init`, and `table.fill`.
- `src/validate/typecheck.mbt:587`, `602`, `625`, and `635` still hard-code `i32` for `table.get`, `table.set`, `table.size`, and `table.grow`, so table64 support is not coherent enough to advertise a faithful `table64-lowering` port yet.

## Future implementation shape

A faithful Starshine port should be a **module pass**, not a HOT-only pass, because declarations and active segments must change alongside function bodies.

Recommended implementation phases:

1. **Registry decision**
   - Decide whether to register both upstream names exactly.
   - If Starshine keeps one implementation, expose aliases or document why one sibling is intentionally omitted.
2. **Module declaration rewrite**
   - Rewrite memory/table `I64Limits` to `I32Limits`.
   - Match Binaryen's source-confirmed max-limit clamp.
   - Decide a local user-facing policy for impossible min limits, because the reviewed Binaryen source asserts that lowered minimums fit rather than documenting a friendly diagnostic.
3. **Segment rewrite**
   - Lower active data offsets to the new address type.
   - Lower active element offsets for table64 to the new address type.
   - Keep active offsets separate from static memory-access `offset=` immediates; the reviewed source does not prove a high-active-offset `unreachable` special case.
4. **Function-body rewrite**
   - Insert `i32.wrap_i64` around dynamic former memory/table address operands, including operand expressions that are syntactically `i64.const`.
   - Turn statically out-of-range `MemArg.offset` immediates into `unreachable` while preserving children/effects.
   - Insert `i64.extend_i32_u` around former size results.
   - Add failure-aware repair for `memory.grow` / `table.grow` so wasm32 `-1` maps back to the wasm64 failure sentinel.
   - Handle scalar, SIMD, atomic, bulk-memory, and table instructions.
5. **Mixed-width copy/fill/init tests**
   - Copy operations need independent destination, source, and length rules.
   - `memory.init` keeps passive-data source offset and length as `i32`, even when the destination memory is memory64.
   - `memory.fill` needs independent destination/value/length assertions: destination and length are selected-memory address width, while the byte value is `i32`. Current Starshine validation still needs a memory64-length fix before local positive tests can prove the full rule.
6. **Validation cleanup**
   - Audit table64 typechecking first, especially the hard-coded `i32` table operations.

## Why not implement this as a HOT peephole?

A HOT-only pass would miss:

- memory/table section declarations, with the shared resource-index rules in [`../../../binary/type-table-memory-global-tag-sections.md`](../../../binary/type-table-memory-global-tag-sections.md);
- active data segment offsets;
- active element segment offsets;
- binary encoding consequences of limit-width changes;
- validation behavior after lowering.

That makes the pass closer to `memory-packing`, `reorder-locals`, or other module-owned rewrites than to local arithmetic peepholes such as `optimize-instructions`.

## Validation checklist for a future Starshine port

Use [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) as the detailed validation ladder. The compact checklist here is the contract summary:

- `memory64-lowering` request is accepted only once the pass is real.
- Memory declarations are converted to 32-bit limits.
- Active data offsets become lowered address-type expressions.
- Dynamic load/store/SIMD/atomic address operands receive `i32.wrap_i64` exactly where needed, including syntactic `i64.const` operands.
- Static high `offset=` immediates become `unreachable` with child/effect preservation.
- `memory.size` receives unsigned result repair.
- `memory.grow` receives delta lowering plus failure-sentinel-aware result repair.
- `memory.init` destination versus data-offset/length widths are tested.
- `memory.copy` mixed-width cases match Binaryen.
- `memory.fill` destination/value/length rules match the official memory64 matrix after the local validator length caveat is resolved.
- `table64-lowering` is either implemented or explicitly rejected with a clear sibling-status message.
- Table64 typechecking is made coherent before table lowering is advertised.
- Binaryen lit files are mirrored as local fixtures or pass-fuzz seeds.

## Current uncertainty

- The 2026-04-25 static-offset correction narrowed earlier wording: static high `offset=` immediates are the clear high-offset `unreachable` family, while dynamic operand constants wrap, active offsets lower as expressions, and grow deltas are handled through lowered-grow result repair. Impossible min-limit behavior is still a source-level assertion rather than a documented user-facing diagnostic contract.
- The 2026-05-20 memory64 bulk-memory refresh narrows local-readiness wording: Starshine already has the representation and most validation helpers for memory64 bulk memory, but `memory.fill` length is still locally typed as `i32`; do not claim full memory64 `memory.fill` validation until that is fixed.
- Starshine's table64 model exists at the `TableType` level, but table instruction typechecking is partly hard-coded to `i32`, so a table64-lowering port has a prerequisite validation cleanup.

## Sources

- [`../../../raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md)
- [`../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md`](../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md)
- [`../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md`](../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md)
- [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md)
- [`../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md)
- [`../../../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md`](../../../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/validate/validate.mbt`](../../../../../src/validate/validate.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
