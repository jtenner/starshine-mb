---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md
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
  - ./wat-shapes.md
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

## Relevant local surfaces

### Registry and request behavior

- `src/passes/optimize.mbt`
  - source of truth for registered pass names;
  - no `memory64-lowering` or `table64-lowering` entry was found.

### Shared IR model

- `src/lib/types.mbt`
  - `Limits` has both `I32Limits` and `I64Limits` variants;
  - `MemType` stores a `Limits` plus sharedness;
  - `TableType` stores a reference type plus `Limits`;
  - `Limits::addr_valtype(...)` maps limit width to `i32` or `i64` address value type;
  - `min_addr_valtype(...)` / `min_addr(...)` provide the mixed-width helper shape a future copy lowering would need.

### Binary format

- `src/binary/decode.mbt`
  - decodes generic `Limits` with 32-bit and 64-bit forms;
  - decodes `MemType` memory64/shared-memory forms with bytes `0x04` through `0x07`;
  - decodes `TableType` through `RefType` plus `Limits`.
- `src/binary/encode.mbt`
  - encodes 32-bit and 64-bit `Limits`;
  - encodes memory64 `MemType` variants.

### Validation and typechecking

- `src/validate/validate.mbt`
  - validates `MemType` with a much larger page cap for `I64Limits` than for `I32Limits`;
  - validates active data offsets against each memory's `addr_valtype()`.
- `src/validate/typecheck.mbt`
  - derives `memory.size` and `memory.grow` types from `mem_at_of(...)`;
  - checks load/store/SIMD/atomic memory addresses through `memarg_check(...)` and each memory's limits;
  - derives `memory.copy` destination/source/length widths from the participating memories;
  - uses table limits for `table.copy`, `table.init`, and `table.fill`;
  - still hard-codes `i32` for `table.get`, `table.set`, `table.size`, and `table.grow`, so table64 support is not coherent enough to advertise a faithful `table64-lowering` port yet.

## Future implementation shape

A faithful Starshine port should be a **module pass**, not a HOT-only pass, because declarations and active segments must change alongside function bodies.

Recommended implementation phases:

1. **Registry decision**
   - Decide whether to register both upstream names exactly.
   - If Starshine keeps one implementation, expose aliases or document why one sibling is intentionally omitted.
2. **Module declaration rewrite**
   - Rewrite memory/table `I64Limits` to `I32Limits`.
   - Source-confirm Binaryen's exact out-of-range behavior before choosing whether to assert, reject, clamp, or wrap impossible limits.
3. **Segment rewrite**
   - Lower active data offsets.
   - Lower active element offsets for table64.
4. **Function-body rewrite**
   - Insert `i32.wrap_i64` around former memory/table address operands.
   - Insert `i64.extend_i32_u` around former size/grow results.
   - Handle scalar, SIMD, atomic, bulk-memory, and table instructions.
5. **Mixed-width copy/fill/init tests**
   - Copy operations need independent destination, source, and length rules.
6. **Validation cleanup**
   - Audit table64 typechecking first, especially the hard-coded `i32` table operations.

## Why not implement this as a HOT peephole?

A HOT-only pass would miss:

- memory/table section declarations;
- active data segment offsets;
- active element segment offsets;
- binary encoding consequences of limit-width changes;
- validation behavior after lowering.

That makes the pass closer to `memory-packing`, `reorder-locals`, or other module-owned rewrites than to local arithmetic peepholes such as `optimize-instructions`.

## Validation checklist for a future Starshine port

- `memory64-lowering` request is accepted only once the pass is real.
- Memory declarations are converted to 32-bit limits.
- Active data offsets become `i32` expressions.
- Load/store/SIMD/atomic address operands receive `i32.wrap_i64` exactly where needed.
- `memory.size` and `memory.grow` receive unsigned result repair.
- `memory.copy` mixed-width cases match Binaryen.
- `table64-lowering` is either implemented or explicitly rejected with a clear sibling-status message.
- Table64 typechecking is made coherent before table lowering is advertised.
- Binaryen lit files are mirrored as local fixtures or pass-fuzz seeds.

## Current uncertainty

- The exact Binaryen policy for 64-bit limits or active offsets that cannot fit the lowered 32-bit output was not fully proved from the reviewed tests.
- Starshine's table64 model exists at the `TableType` level, but table instruction typechecking is partly hard-coded to `i32`, so a table64-lowering port has a prerequisite validation cleanup.

## Sources

- [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md)
- [`../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md`](../../../raw/research/0315-2026-04-24-memory64-lowering-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/validate/validate.mbt`](../../../../../src/validate/validate.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
