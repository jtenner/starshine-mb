---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-multi-memory-lowering-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-multi-memory-lowering-primary-sources.md
  - ../../../raw/research/0393-2026-04-26-multi-memory-lowering-port-readiness.md
  - ../../../raw/research/0370-2026-04-25-multi-memory-lowering-source-dossier.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./memory-layout-bounds-and-growth.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../memory64-lowering/index.md
  - ../memory-packing/index.md
---

# Starshine strategy for `multi-memory-lowering`

## Current status

Starshine does **not** currently implement Binaryen's `multi-memory-lowering` or `multi-memory-lowering-with-bounds-checks`.

The current status is stronger than generic “not ported”:

- `src/passes/optimize.mbt` has no active registry entry for either pass;
- neither name appears in `pass_registry_boundary_only_names()`;
- neither name appears in `pass_registry_removed_names()`;
- no owner file, dispatcher case, preset slot, parity page, or active backlog slice was found for either sibling.

So today's correct user-facing description is:

> Starshine can represent and validate several indexed-memory surfaces, but it has no pass that lowers many memories into one combined memory.

## Exact local code locations to read first

### Registry and request behavior

- `src/passes/optimize.mbt:126-153`
  - boundary-only and removed compatibility-name lists; neither `multi-memory-lowering` nor `multi-memory-lowering-with-bounds-checks` appears.
- `src/passes/optimize.mbt:156-267`
  - active hot/module/preset registry construction; neither pass appears.
- `src/passes/optimize.mbt:363-367`
  - registry category lookup used by public request handling.
- `src/passes/optimize.mbt:446-489`
  - request expansion and rejection path; these pass names would fail as unknown before reaching boundary-only or removed guards.

### Local memory representation

- `src/lib/types.mbt:174`
  - `MemType`, the memory declaration carrier.
- `src/lib/types.mbt:475`
  - `MemArg(U32, MemIdx?, U64)`, the memory operand side table for ordinary memory instructions.
- `src/lib/types.mbt:1263-1270`
  - `Limits::addr_valtype(...)`, mapping memory limits to address value type.
- `src/lib/types.mbt:1366-1371`
  - `min_addr_valtype(...)`, used for mixed-width copy-like typing.

### WAT and binary surfaces

- `src/wast/lower_to_lib.mbt:2298-2310`
  - current WAT lowering for `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, and `memory.init` defaults memory operands to index `0` in this path. This is a frontend gap for multi-memory text fixtures.
- `src/binary/decode.mbt:3238-3242`
  - binary decoding preserves both memory indexes for `memory.copy`.
- `src/binary/encode.mbt:3034-3074`
  - binary encoding writes memory indexes for `memory.init`, `memory.copy`, and `memory.fill`.

### Validation and typechecking

- `src/validate/typecheck.mbt:371-376`
  - `TcState::mem_at_of(...)`, deriving an address type from the selected memory's limits.
- `src/validate/typecheck.mbt:2408-2424`
  - `memory.size` / `memory.grow` typing from the selected memory.
- `src/validate/typecheck.mbt:2427-2454`
  - `memory.init` typing from the selected memory.
- `src/validate/typecheck.mbt:2468-2495`
  - `memory.copy` typing with destination/source memory address widths plus mixed-width length selection.
- `src/validate/typecheck.mbt:2499-2521`
  - `memory.fill` typing from the selected memory.

## Why a local port must be a module pass

A HOT-only pass would miss essential state:

- the memory section has to shrink to one combined memory, following the parent memory-index contract in [`../../../binary/type-table-memory-global-tag-sections.md`](../../../binary/type-table-memory-global-tag-sections.md);
- data segments have to be retargeted and shifted;
- memory exports may need repair;
- helper globals must be added;
- `memory.size` and `memory.grow` helper functions must be generated;
- memory indexes in all surviving code must be remapped;
- feature/custom-section state must stop advertising multi-memory once the output is single-memory.

That makes this closer to [`../memory64-lowering/index.md`](../memory64-lowering/index.md), [`../memory-packing/index.md`](../memory-packing/index.md), or other module-owned rewrites than to HOT address peepholes.

## Future implementation shape

A faithful Starshine port should start with a module pass behind an explicit registry decision. The dedicated port-readiness bridge gives the full staged plan and validation order: [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).

Recommended phases:

1. **Registry decision**
   - Decide whether to register both upstream names or leave them unknown until a real port exists.
   - Keep the checked sibling separate if behavior diverges.
2. **Frontend readiness**
   - Add WAT support for indexed/named memory operands if local fixtures need text roundtrips.
   - Ensure binary and validation fixtures can exercise nonzero memory indexes without relying only on hand-built IR.
3. **Narrow unchecked first slice**
   - Start with two unshared memory32 memories, no imports/exports, constant active offsets, scalar load/store, and simple bulk-memory retargeting.
   - Leave `memory.size`, `memory.grow`, SIMD, atomics, and checked traps out until declaration/data/body repair is green.
4. **Module legality analysis**
   - Match Binaryen's accepted family: same address type, same sharedness, same page size, and only first-memory import/export preservation.
   - Decide local diagnostics for unsupported shapes.
5. **Combined-memory rewrite**
   - Replace multiple memories with one combined memory.
   - Add mutable offset globals for original memories after the first.
   - Retarget active data segments and shift constant offsets.
6. **Function-body rewrite**
   - Retarget all memory operations to memory `0`.
   - Add offset globals to address operands for nonzero original memories.
   - Cover scalar, SIMD, atomic, and bulk-memory forms.
7. **Helper generation**
   - Generate virtual `memory.size` and `memory.grow` helpers.
   - Pay special attention to non-last memory growth, which must move later ranges and update offset globals.
8. **Checked sibling**
   - Add optional explicit trap checks only after unchecked lowering is correct.
   - Preserve Binaryen's documented overflow-imprecision caveat unless a deliberate local divergence is chosen and tested.
9. **Feature cleanup**
   - Decide how Starshine represents Binaryen's MultiMemory feature disablement after lowering: IR feature state, custom-section mutation, or both.

## Validation checklist for a future Starshine port

- Explicit pass request is accepted only once the transform is real.
- Zero- and one-memory modules are no-ops.
- Multi-memory modules lower to one memory plus offset globals.
- Active data segments retarget to the combined memory.
- Load/store/SIMD/atomic operations add the selected memory's base offset.
- `memory.init`, `memory.copy`, and `memory.fill` retarget correctly.
- `memory.size` uses virtual per-memory helper logic.
- `memory.grow` on a non-last memory moves later memory ranges and updates offsets.
- Unsupported import/export/mixed-property shapes are either rejected clearly or matched to Binaryen diagnostics.
- The checked sibling traps on out-of-virtual-memory accesses.
- Feature/custom-section cleanup is tested.

## Current uncertainty

- Starshine's WAT lowering currently defaults several memory operations to memory `0`, so multi-memory WAT fixture support may need work before a convenient source-level test suite exists.
- Binaryen's source has TODO/assertion behavior around non-constant active data offsets; the local port should recheck current upstream before choosing either a diagnostic or a supported rewrite.
- Starshine does not yet expose a Binaryen-like feature-set toggling contract for removing the MultiMemory feature from output metadata.
