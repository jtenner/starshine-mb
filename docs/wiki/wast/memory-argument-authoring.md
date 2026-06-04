---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md
  - ../raw/wasm/2026-05-19-wast-memory-argument-sources.md
  - ../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md
  - ../raw/wasm/2026-05-20-resource-section-validation-refresh.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/lib/eq.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/gen_valid.mbt
related:
  - ./memory-instruction-authoring.md
  - ./data-segment-authoring.md
  - ./resource-declaration-authoring.md
  - ../binary/instruction-and-expression-encoding.md
  - ../binary/data-element-and-datacount-sections.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../validate/module-validation-phases.md
  - ../validate/resource-sections-and-limits.md
  - ../fuzzing/generator-coverage-ledger.md
  - ./simd-authoring.md
---

# WAST Memory Argument Authoring

## Overview

Use this page when writing, reviewing, or widening WAST fixtures that need memory `offset=`, `align=`, selected-memory, or memory32/memory64 address-width guidance. For active/passive `(data ...)` fields, string payloads, and data-segment initialization offsets, use [`data-segment-authoring.md`](data-segment-authoring.md). For runtime stack shapes and side-effect/trap behavior of scalar loads/stores, `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, `memory.init`, and `data.drop`, use [`memory-instruction-authoring.md`](memory-instruction-authoring.md). For `(memory ...)` declarations, imports, exports, and the current WAST limit-syntax caveats, use [`resource-declaration-authoring.md`](resource-declaration-authoring.md). For validator-side memory limit ranges, memory64 declaration validity, and shared-memory maximum policy, use [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md).

A WebAssembly memory instruction has two different address components:

1. a **dynamic address** on the operand stack, typed as `i32` for memory32 or `i64` for memory64; and
2. a **static `offset=` immediate** stored in the instruction's memory argument.

It may also have an **alignment hint** and, in multi-memory contexts, a **selected memory index**. Starshine has all of those concepts in the core/binary/validator layers, but its current WAST text lowering only preserves `offset=` and `align=` for ordinary scalar/SIMD load/store memory arguments. Explicit nonzero memory indices in text memory instructions are a known fixture-readiness gap.

The current source manifest is [`../raw/wasm/2026-05-19-wast-memory-argument-sources.md`](../raw/wasm/2026-05-19-wast-memory-argument-sources.md). It checks the official WebAssembly 3.0 text, binary, validation, and PDF sources plus the multi-memory and memory64 proposal surfaces and the Starshine parser, lowerer, printer, binary codec, typechecker, equality, and generator code. The 2026-06-04 address-width refresh in [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md) is the current source for the positional memory/table instruction width split used by this page.

## Mental Model

```text
WAST text                    Starshine lowering                 Validation / binary
---------                    ------------------                 -------------------
i32.load offset=8 align=4 -> MemArg(align_pow=2, mem=None, offset=8)
                              dynamic address still on stack -> selected memory defaults to 0

binary explicit memidx    -> MemArg(align_pow, Some(memidx), offset)
                              preserved by codec           -> nonzero memidx remains observable

memory64 memory           -> dynamic address is i64          -> static offset must fit addr width
memory32 memory           -> dynamic address is i32          -> offset >= 2^32 is invalid
```

Keep these three names separate:

- **text alignment**: the byte value written as `align=1`, `align=2`, `align=4`, etc.;
- **core alignment**: the exponent stored in [`MemArg(U32, MemIdx?, U64)`](../../../src/lib/types.mbt), so `align=4` lowers to `U32(2)`;
- **access width**: the load/store width used by validation to reject over-aligned memory arguments.

## Authoring Rules And Examples

### Scalar load/store memargs

```wat
(module
  (memory 1)
  (func (param i32) (result i32)
    local.get 0
    i32.load offset=8 align=4)
  (func (param i32 i64)
    local.get 0
    local.get 1
    i64.store offset=16 align=8))
```

Starshine parses `offset=N` and `align=N` in either order in [`WastParser::parse_mem_arg(...)`](../../../src/wast/parser.mbt). If an immediate is omitted, the parser uses an instruction-specific default alignment and `offset=0`.

During lowering, [`wt_mem_arg(...)`](../../../src/wast/lower_to_lib.mbt) converts text byte alignment to the exponent form used by core IR. That conversion rejects `align=0`, non-power-of-two alignments such as `align=3`, and values that cannot be represented as a small exponent. Later validation checks whether the exponent is legal for the access width: `i32.load8_s align=4` is syntactically parsed but semantically invalid because an 8-bit access cannot claim four-byte alignment.

### `offset=` is not the address operand

```wat
(module
  (memory 1)
  (func (param i32) (result i32)
    local.get 0       ;; dynamic address
    i32.load offset=12)) ;; static immediate added to that address
```

For pass and validator work, do not treat `offset=12` as a stack value. It is an instruction immediate. The actual stack operand is still the selected memory's address type. This distinction matters when lowering memory64, folding address arithmetic, or comparing Binaryen behavior: `i32.load offset=12 (i32.add ...)` and `i32.load (i32.add ... (i32.const 12))` are related but not the same representation.

### Memory64 changes the dynamic address width

The selected memory's limits determine the address type. [`TcState::mem_at_of(...)`](../../../src/validate/typecheck.mbt) and [`memarg_check(...)`](../../../src/validate/typecheck.mbt) route memory64 memory accesses through `i64` address operands. `memory.size` and `memory.grow` also use the selected memory's address type for their result and grow-delta operand.

However, current Starshine WAST memory declarations do not author memory64 resources directly: [`parse_limits(...)`](../../../src/wast/parser.mbt) parses natural min/max limits, and [`wt_limits(...)`](../../../src/wast/lower_to_lib.mbt) lowers them to `@lib.Limits::i32(...)`. Use a direct core or binary fixture when a test must prove memory64 address typing today. Use [`resource-declaration-authoring.md`](resource-declaration-authoring.md) for the WAST declaration caveat and [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md) for the core validator limit contract.

The static offset still has an address-width rule once the selected core/binary memory is memory64: an i32 memory rejects offsets at or above `2^32`, while local i64 memory offsets can use the full `UInt64` immediate range. The focused Binaryen lowering caveat for large static offsets lives in [`../binaryen/passes/memory64-lowering/static-offsets-dynamic-operands-and-grow-repair.md`](../binaryen/passes/memory64-lowering/static-offsets-dynamic-operands-and-grow-repair.md); this page covers Starshine's WAST/core validation model without implying that current WAST declarations can spell every core memory type.

### Multi-memory instruction indices are a current WAST gap

The core representation can distinguish default memory `0` from explicit nonzero memories:

```text
MemArg(U32(2), None, U64(8))              ;; default memory, equal to explicit memory 0
MemArg(U32(2), Some(MemIdx(0)), U64(8))   ;; explicit memory 0, equality treats as same
MemArg(U32(2), Some(MemIdx(1)), U64(8))   ;; explicit memory 1, distinct
```

Binary decode/encode preserves explicit memory indices through the local `align + 64` memory-argument encoding convention in [`src/binary/decode.mbt`](../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../src/binary/encode.mbt). The equality rule in [`src/lib/eq.mbt`](../../../src/lib/eq.mbt) intentionally treats `None` and `Some(MemIdx(0))` as equivalent but keeps `Some(MemIdx(1))` distinct.

Current WAST does not expose that full surface for ordinary memory instructions. [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) has a WAST-local `MemArg` with only `align` and `offset`, and [`wt_mem_arg(...)`](../../../src/wast/lower_to_lib.mbt) lowers it to `@lib.MemArg::new(..., None, ...)`. The same lowering file currently emits memory `0` for WAST `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, and `memory.init` instruction forms.

Implication: if a test must prove nonzero memory-index behavior today, use a direct core/binary fixture or first widen the WAST AST/lowering path. Do not infer that Starshine lacks multi-memory validation just because WAST text cannot author every indexed instruction form yet.

### Bulk memory and active data offsets are adjacent, not identical

Bulk-memory instructions carry resource indices separately from scalar/SIMD `MemArg`. Their stack operand widths are also positional, not family-wide; the focused 2026-06-04 refresh in [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md) records the current official matrix and Starshine code-map split. In short, `memory.init` keeps data-segment source offset and length as `i32`, mixed-width `memory.copy` uses the minimum address type for length, and `memory.fill` should use the selected memory address type for both destination and length even though current Starshine still hard-codes the length slot to `i32`.

```wat
(module
  (memory 1)
  (data $payload "hello")
  (func
    i32.const 0  ;; destination address
    i32.const 0  ;; source offset within data segment
    i32.const 5  ;; length
    memory.init $payload
    data.drop $payload))
```

In Starshine core, `memory.init` is [`Instruction::MemoryInit(DataIdx, MemIdx)`](../../../src/lib/types.mbt), and `memory.copy` is [`Instruction::MemoryCopy(MemIdx, MemIdx)`](../../../src/lib/types.mbt). Validation stack-types their destination/source/length positions separately in [`typecheck_memory_init(...)`](../../../src/validate/typecheck.mbt) and [`typecheck_memory_copy(...)`](../../../src/validate/typecheck.mbt). WAST lowering currently defaults the memory index to `0` for these instruction forms.

Active data-segment offsets are another nearby concept. An active data segment has a parent `MemIdx` plus a constant offset expression, documented for text fixtures in [`data-segment-authoring.md`](data-segment-authoring.md) and for binary/core headers in [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md). That offset expression is module initialization data, not a function-body `MemArg.offset` immediate.

## Starshine Code Map

| Layer | Files | What to inspect |
| --- | --- | --- |
| WAST keyword recognition | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt) | Memory opcode spellings such as scalar load/store, `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, and `memory.init`. |
| WAST parsing | [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | WAST-local `MemArg`, `parse_mem_arg(...)`, scalar/SIMD memory instruction parsing, and the current absence of a text memory-index field in ordinary memargs. |
| WAST lowering | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) | `wt_align_pow_from_text_align(...)`, `wt_mem_arg(...)`, `wt_load_store(...)`, SIMD memory lowering, and memory-instruction defaulting to `MemIdx(0)`. |
| WAST printing | [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | `render_memarg(...)` and memory instruction printing. |
| Core IR | [`src/lib/types.mbt`](../../../src/lib/types.mbt), [`src/lib/eq.mbt`](../../../src/lib/eq.mbt) | Core `MemArg(U32, MemIdx?, U64)`, memory instruction variants, and equality for default versus explicit memory `0`. |
| Binary codec | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`src/binary/tests.mbt`](../../../src/binary/tests.mbt) | Explicit-memory-index memarg encoding/decoding, bulk-memory immediates, malformed memarg errors, and roundtrip coverage. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md) | `memarg_check(...)`, selected-memory address typing, offset-width checks, memory limit validation, `memory.copy` mixed-width typing, and data-count preconditions; section-level memory limit and shared-memory rules are centralized in the resource guide. |
| Generator/fuzz | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md) | `[FZG]005` nonzero memarg/width coverage, `[FZG]006` memory limit/proposal coverage routed through [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md), `[FZG]017` atomic memargs through [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md), and invalid memory64/shared cases. |

## Validation And Signoff Guidance

When changing memory-argument text, binary, or validation behavior:

1. **Start with the layer that owns the behavior.** WAST alignment syntax belongs in [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt); binary immediate preservation belongs in [`src/binary/tests.mbt`](../../../src/binary/tests.mbt); address-width stack typing belongs in [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt).
2. **Test defaults and explicit forms separately.** `None` and `Some(MemIdx(0))` may compare equal, but nonzero memory indices must roundtrip and validate distinctly.
3. **Include memory32 and memory64 fixtures at the right layer.** Memory64 changes the stack address type and `memory.size` / `memory.grow` widths; current WAST declarations only cover the memory32 limit path, so memory64 declaration evidence needs direct core/binary fixtures or new text-surface work first. i32 memories still need offset-range rejection tests, and memory declaration limit validity should be checked against [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md).
4. **Do not conflate `MemArg.offset` with active-segment offsets.** If a pass changes data segment layout, update [`data-segment-authoring.md`](data-segment-authoring.md), [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md), and any memory-packing or memory64-lowering pages rather than only this WAST page.
5. **Use direct core/binary fixtures for nonzero memory indices until WAST is widened.** If WAST grows explicit memory-index syntax, add parser/lowerer/printer tests first, then route the change through this page, [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md), and [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md). Atomic fixtures should also follow [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md) because `[FZG]017` currently proves core/binary/generator behavior, not WAST text parsing.

## Current Gaps And Caveats

- WAST memory arguments currently preserve `align` and `offset`, not explicit nonzero memory indices.
- WAST `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, and `memory.init` currently lower to memory `0` for the memory operand(s), even though core/binary instructions can carry `MemIdx` values; see [`memory-instruction-authoring.md`](memory-instruction-authoring.md) for the stack-shape and data-count side of that caveat.
- WAST printing emits `align=` in byte-alignment form and does not show explicit memory indices for ordinary memory arguments.
- Generator and binary coverage are broader than WAST text coverage for multi-memory. Keep those layers distinct when writing signoff claims, and route declaration-level memory64/shared-memory validity through [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md).
- `memory.copy` length typing uses the minimum address type of the two memories locally. Mixed memory32/memory64 fixtures are therefore better validator tests than simple one-memory examples.
- Current Starshine validation still types `memory.fill` length as `i32` for memory64; [`memory-instruction-authoring.md`](memory-instruction-authoring.md) and [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md) record this as a local/spec divergence rather than an intended long-term contract.

## Sources

- Primary-source manifest: [`../raw/wasm/2026-05-19-wast-memory-argument-sources.md`](../raw/wasm/2026-05-19-wast-memory-argument-sources.md)
- Current memory/table address-width refresh: [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md)
- Memory64 bulk-memory validation refresh: [`../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md`](../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md)
- Resource-section validation refresh: [`../raw/wasm/2026-05-20-resource-section-validation-refresh.md`](../raw/wasm/2026-05-20-resource-section-validation-refresh.md), [`../validate/resource-sections-and-limits.md`](../validate/resource-sections-and-limits.md)
- Official WebAssembly sources: <https://webassembly.github.io/spec/core/text/instructions.html>, <https://webassembly.github.io/spec/core/binary/instructions.html>, <https://webassembly.github.io/spec/core/valid/instructions.html>, <https://webassembly.github.io/spec/core/_download/WebAssembly.pdf>
- Official proposal surfaces checked for non-MVP shape: <https://webassembly.github.io/multi-memory/core/text/modules.html>, <https://webassembly.github.io/memory64/core/>
- Starshine implementation: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/lib/eq.mbt`](../../../src/lib/eq.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt)
