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
  - ./starshine-strategy.md
  - ../memory64-lowering/index.md
  - ../llvm-memory-copy-fill-lowering/index.md
  - ../memory-packing/index.md
---

# Starshine port readiness for `multi-memory-lowering`

## Current verdict

Do **not** treat `multi-memory-lowering` as a small memory-instruction peephole. A faithful Starshine port is a whole-module feature-lowering pass.

Today both upstream names are still unknown to Starshine:

- `multi-memory-lowering`
- `multi-memory-lowering-with-bounds-checks`

That is accurate until a real implementation exists. Starshine can represent, encode, decode, and typecheck several indexed-memory surfaces, but it does not yet lower many memories into one combined memory.

## Why this pass deserves a staged port

The pass touches every layer of module state that makes multi-memory observable:

| Layer | Binaryen behavior | Starshine implication |
| --- | --- | --- |
| Memory declarations | Replace many memories with one combined memory. | Needs module-section mutation, not HOT-only rewrite. |
| Base offsets | Add mutable globals for original memories after memory `0`. | Needs generated global names/types/init expressions. |
| Active data | Retarget segments to the combined memory and shift constant offsets. | Needs data-segment rewrite helpers and tests for non-constant-offset rejection. |
| Function bodies | Retarget indexed memory ops to memory `0`; add base offsets to addresses. | Needs full body rewrite across scalar, bulk, SIMD, and atomic families. |
| `memory.size` | Replace with virtual per-original-memory helper calls. | Needs helper function generation and call-site typing. |
| `memory.grow` | Replace with helpers; non-last grow moves later byte ranges and updates offset globals. | Needs careful ordering, temporary locals, `memory.copy`, and failure-sentinel handling. |
| Checked sibling | Insert explicit traps before out-of-virtual-memory accesses. | Should wait until unchecked lowering is oracle-stable. |
| Feature metadata | Disable Binaryen's MultiMemory feature. | Needs a local feature/custom-section cleanup decision before claiming parity. |

## Exact local code locations to inspect

### Registry truth

- `src/passes/optimize.mbt:126-153` - boundary-only names; neither sibling appears.
- `src/passes/optimize.mbt:156-267` - active hot/module/preset entries; neither sibling appears.
- `src/passes/optimize.mbt:446-489` - request expansion and unknown-pass rejection path.

### Existing memory model and instruction carriers

- `src/lib/types.mbt:174` - `MemType` declaration carrier.
- `src/lib/types.mbt:439` - `MemSec`, the module memory-section carrier.
- `src/lib/types.mbt:475` - `MemArg(U32, MemIdx?, U64)`, the ordinary memory-operation side table.
- `src/lib/types.mbt:543-565` - scalar load/store instruction families carrying `MemArg`.
- `src/lib/types.mbt:568-604` - atomic memory instruction families carrying `MemArg`.
- `src/lib/types.mbt:1263-1270` - address value-type derivation from memory limits.
- `src/lib/types.mbt:1366-1371` - mixed-width address type choice for copy-like operations.

### WAT, binary, and validation seams

- `src/wast/lower_to_lib.mbt:2293-2312` - current text lowering defaults `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, and `memory.init` to memory `0` in this path; this is a fixture-readiness gap for multi-memory WAT tests.
- `src/binary/decode.mbt:3238-3242` - binary decoding preserves both memory indexes for `memory.copy`.
- `src/binary/encode.mbt:3034-3074` - binary encoding writes memory indexes for `memory.init`, `memory.copy`, and `memory.fill`.
- `src/validate/typecheck.mbt:371-376` - `TcState::mem_at_of(...)`, the selected-memory address-type lookup.
- `src/validate/typecheck.mbt:2408-2521` - `memory.size`, `memory.grow`, `memory.init`, `memory.copy`, and `memory.fill` typing through selected memories.
- `src/validate/typecheck.mbt:3129-3138` - instruction dispatcher cases for those memory operators.

## Recommended implementation ladder

### Slice 0: registry honesty and fixture decision

Keep both pass names unknown unless the project wants clearer unsupported-pass diagnostics. If they are added as boundary-only names, document that this is a UX choice and not implementation progress.

Choose test input strategy before coding:

- add WAT indexed-memory syntax support for readable fixtures; or
- use binary/IR fixtures for the first pass tests and leave WAT ergonomics as a separate frontend task.

### Slice 1: unchecked structural lowering

Start with a deliberately narrow positive family:

- exactly two memories;
- memory32 only;
- unshared memories;
- no imports or exports;
- constant active data offsets only;
- scalar load/store plus simple `memory.init`, `memory.copy`, and `memory.fill` retargeting.

Expected output:

- one combined memory;
- one mutable offset global for memory `1`;
- active data for memory `1` retargeted with a shifted constant offset;
- body memory operations retargeted to memory `0` with address addition for original memory `1`.

### Slice 2: helper calls for virtual sizes

Add `memory.size` helper generation only after slice 1 is green. This keeps declaration/data/body repair separate from function-creation and call-site typing.

### Slice 3: last-memory grow

Handle `memory.grow` for the last original memory. It still needs a helper and virtual-size return behavior, but it does not need to move later ranges.

### Slice 4: non-last grow movement

Add the hard case:

- grow the combined memory;
- move later memory ranges upward with `memory.copy`;
- update every later base-offset global;
- preserve the old virtual size or `-1` failure result.

This slice is the main correctness cliff and should get focused reduced tests before broader fuzzing.

### Slice 5: full memory-op surface

Extend address repair to the remaining Binaryen-covered families:

- SIMD memory loads/stores that Starshine represents;
- atomics;
- all bulk-memory forms and mixed source/destination memory indexes;
- memory64-compatible typing only if the pass explicitly supports same-address-type memory64 input.

### Slice 6: checked sibling

Only after unchecked parity is stable, add `multi-memory-lowering-with-bounds-checks`.

Keep Binaryen's caveat visible: the owner comments record an effective-address overflow imprecision in the inserted checks, so local parity tests should not claim a stronger checked semantics unless Starshine deliberately diverges and documents that divergence.

### Slice 7: feature cleanup

Decide how Starshine should stop advertising multi-memory after lowering. The Binaryen strategy disables the feature set; Starshine needs an explicit equivalent before the dossier can claim parity.

## Validation ladder

Use this sequence for a future implementation:

1. Unknown or boundary-only request behavior is tested before implementation.
2. Zero- and one-memory modules are no-ops.
3. Two-memory structural lowering rewrites memory declarations and adds offset globals.
4. Constant active data offsets are shifted.
5. Scalar load/store on memory `1` adds the base offset.
6. `memory.copy` repairs destination and source independently.
7. `memory.init` and `memory.fill` retarget to the combined memory.
8. `memory.size` helper returns virtual per-memory sizes.
9. Last-memory `memory.grow` helper returns the old virtual size or `-1`.
10. Non-last `memory.grow` moves later bytes and updates later offset globals.
11. Unsupported imported/exported/mismatched-memory-property shapes fail deliberately.
12. Checked sibling traps when an access exceeds the virtual memory range.
13. MultiMemory feature/custom-section cleanup is asserted.
14. Binaryen oracle comparison runs against `wasm-opt --multi-memory-lowering` and then `--multi-memory-lowering-with-bounds-checks`.

## Cross-links for follow-along reading

- [`binaryen-strategy.md`](binaryen-strategy.md) - upstream algorithm and caveats.
- [`memory-layout-bounds-and-growth.md`](memory-layout-bounds-and-growth.md) - layout and non-last-grow mechanics.
- [`wat-shapes.md`](wat-shapes.md) - concrete before/after shapes to turn into tests.
- [`starshine-strategy.md`](starshine-strategy.md) - current local status and broader code map.
- [`../memory64-lowering/index.md`](../memory64-lowering/index.md) - address-width lowering, which should not be conflated with memory-count lowering.
- [`../llvm-memory-copy-fill-lowering/index.md`](../llvm-memory-copy-fill-lowering/index.md) - bulk-memory compatibility lowering, which should not be conflated with indexed-memory retargeting inside this pass.
- [`../memory-packing/index.md`](../memory-packing/index.md) - data-layout size optimization, not virtual multi-memory preservation.

## Open questions

- Should Starshine add boundary-only entries for clearer CLI diagnostics, or leave both names unknown until implementation?
- Should first tests be readable WAT fixtures or direct binary/IR fixtures?
- Should unsupported Binaryen assertion/fatal families become polished Starshine diagnostics?
- Should Starshine model feature cleanup as an IR feature toggle, custom-section mutation, or both?
