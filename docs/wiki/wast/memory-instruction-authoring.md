---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-19-wast-memory-instruction-sources.md
  - ../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md
  - ../raw/wasm/2026-05-20-atomic-memory-instruction-sources.md
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/wast/arbitrary.mbt
related:
  - ./memory-argument-authoring.md
  - ./atomic-memory-instruction-authoring.md
  - ./data-segment-authoring.md
  - ./resource-declaration-authoring.md
  - ./simd-authoring.md
  - ./table-instruction-authoring.md
  - ./gc-aggregate-instruction-authoring.md
  - ../binary/instruction-and-expression-encoding.md
  - ../binary/data-element-and-datacount-sections.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../validate/module-validation-phases.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST Memory Instruction Authoring

## Overview

Use this page when writing or reviewing WAST fixtures, validator tests, or optimizer rewrites that execute linear-memory operations:

- scalar loads and stores such as `i32.load`, `i64.load8_u`, `f32.store`, and `i64.store32`;
- `memory.size` and `memory.grow`;
- bulk-memory instructions `memory.fill`, `memory.copy`, `memory.init`, and `data.drop`.

Atomic memory instructions are deliberately routed to [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md): Starshine core/binary/validator/generator supports them, but current WAST keywords and parser cases do not expose atomic text syntax. The companion page [`memory-argument-authoring.md`](memory-argument-authoring.md) owns `offset=`, `align=`, default memory `0`, memory32/memory64 address widths, and the current WAST gap around explicit nonzero memory indices. [`resource-declaration-authoring.md`](resource-declaration-authoring.md) owns `(memory ...)` declarations, imports, exports, and the current text-surface caveat that WAST memory declarations lower through the `i32` limits path. This page owns the **instruction stack shapes**, **resource-index relationships**, **data-count requirement**, **side-effect/trap behavior**, and **Starshine layer map**.

The broad source manifest is [`../raw/wasm/2026-05-19-wast-memory-instruction-sources.md`](../raw/wasm/2026-05-19-wast-memory-instruction-sources.md). It checks current official WebAssembly text/syntax/binary/validation/module sources plus Starshine WAST parser/lowerer/printer, core instruction, binary codec, validator, generator, arbitrary WAST, and HOT-IR effect surfaces. The targeted 2026-05-20 refresh in [`../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md`](../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md) rechecks the memory64 bulk-memory operand matrix and supersedes any broad wording that implied Starshine already threads the selected memory address type through every `memory.fill` operand.

## Beginner Model

A memory instruction is not just a keyword. It combines a selected memory, zero or more immediates, and a stack effect:

```text
instruction family      immediate carrier              stack values
------------------      -----------------              ------------
load/store              MemArg(align, mem?, offset)    address; stores also take value
memory.size/grow        MemIdx                         grow takes page delta
memory.fill             MemIdx                         dst, byte value, length
memory.copy             dst MemIdx + src MemIdx         dst, src, length
memory.init             DataIdx + MemIdx               dst, data offset, length
data.drop               DataIdx                        no stack values
```

Execution can still trap even when validation succeeds. For example, `i32.load` can trap on out-of-bounds access, `memory.grow` can fail at runtime and return `-1`, and bulk-memory ranges can trap if their source/destination ranges exceed the selected memory or data segment. Optimizer passes must therefore preserve both stack typing and trap order.

### Bulk-memory operand-width matrix

The memory64 rule is positional. Do not summarize bulk-memory typing as "all `i64`" or "all `i32`" once memory64 or multi-memory enters the test case.

| Instruction | Operand roles in source order | Official width rule | Current Starshine status |
| --- | --- | --- | --- |
| `memory.init data, mem` | destination address, data-segment source offset, length | destination uses selected memory `at`; source and length are `i32` because they index the passive data segment. | Matches locally for the destination plus `i32` source/length. |
| `memory.copy dst, src` | destination address, source address, length | destination uses `dst` memory `at1`; source uses `src` memory `at2`; length uses the minimum address type for the two memories. | Matches locally through `min_addr_valtype(...)`. |
| `memory.fill mem` | destination address, byte value, length | destination and length both use selected memory `at`; byte value is `i32`. | Destination matches locally, but length is still hard-coded to `i32`; see the caveat below. |

This matrix is the main reason future memory64 validator or lowering work needs direct core/binary fixtures. Current WAST text lowering defaults the memory immediates to `MemIdx(0)`, and current WAST declarations do not directly author memory64 memories.

## WAST Shapes And Stack Effects

### Scalar loads and stores

```wat
(module
  (memory 1)
  (func (param $p i32) (result i32)
    local.get $p
    i32.load offset=8 align=4)
  (func (param $p i32) (param $x i64)
    local.get $p
    local.get $x
    i64.store32))
```

Loads consume the selected memory's address type and push a result. Stores consume an address and a value. In folded text, the address appears before the value, but the typechecker pops the top value first and then the address. Narrow signed/unsigned loads still push the full result type: `i32.load8_s` and `i32.load8_u` both produce `i32`; `i64.load32_s` and `i64.load32_u` both produce `i64`. Narrow stores consume the full source value type and store only the low-width lane.

Starshine recognizes scalar memory keywords in [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), parses them in [`src/wast/parser.mbt`](../../../src/wast/parser.mbt), lowers them through [`wt_load_store(...)`](../../../src/wast/lower_to_lib.mbt), represents them as `Instruction::*Load(MemArg)` / `Instruction::*Store(MemArg)` in [`src/lib/types.mbt`](../../../src/lib/types.mbt), and validates them through [`typecheck_load(...)`](../../../src/validate/typecheck.mbt) / [`typecheck_store(...)`](../../../src/validate/typecheck.mbt).

### `memory.size` and `memory.grow`

```wat
(module
  (memory 2 4)
  (func (result i32)
    memory.size)
  (func (param $pages i32) (result i32)
    local.get $pages
    memory.grow))
```

`memory.size` pushes the current size in pages. `memory.grow` consumes a page delta and pushes the previous size, or a failure sentinel at runtime. For memory64, Starshine's validator uses the selected memory's address type for both the `memory.size` result and `memory.grow` operand/result via [`typecheck_memory_size(...)`](../../../src/validate/typecheck.mbt) and [`typecheck_memory_grow(...)`](../../../src/validate/typecheck.mbt).

Current WAST lowering emits `MemorySize(MemIdx(0))` and `MemoryGrow(MemIdx(0))`; direct core/binary fixtures are required for nonzero memory-index coverage until the WAST surface grows explicit memory-index syntax.

### `memory.fill`

```wat
(module
  (memory 1)
  (func (param $dst i32) (param $byte i32) (param $len i32)
    local.get $dst
    local.get $byte
    local.get $len
    memory.fill))
```

`memory.fill` writes `len` bytes of the low eight bits of the `i32` byte value starting at `dst`. It is side-effecting and trap-sensitive. The official validation rule uses the selected memory address type for the destination and length operands and `i32` for the byte value.

**Current Starshine caveat:** [`typecheck_memory_fill(...)`](../../../src/validate/typecheck.mbt) currently pops `len:i32`, `val:i32`, and `dst:at`. That accepts the ordinary memory32 shape and still uses the selected memory address type for the destination, but it rejects the official memory64 positive shape where `len` is `i64`. Keep this visible as a validator follow-up and do not cite current Starshine behavior as the intended WebAssembly memory64 contract.

### `memory.copy`

```wat
(module
  (memory 1)
  (func (param $dst i32) (param $src i32) (param $len i32)
    local.get $dst
    local.get $src
    local.get $len
    memory.copy))
```

`memory.copy` copies bytes between a destination memory and a source memory. The source and destination ranges may overlap. Starshine core represents this as [`Instruction::MemoryCopy(MemIdx, MemIdx)`](../../../src/lib/types.mbt), preserving the two memory indices separately in core and binary.

Validation in [`typecheck_memory_copy(...)`](../../../src/validate/typecheck.mbt) checks both memory indices, consumes destination address using the destination memory address type, consumes source address using the source memory address type, and consumes length using the smaller address type when the two memories have different address widths. Current WAST lowering defaults both memory indices to `0`.

### `memory.init` and `data.drop`

```wat
(module
  (memory 1)
  (data $payload "hello")
  (func
    i32.const 0  ;; destination memory address
    i32.const 0  ;; source offset inside the data segment
    i32.const 5  ;; byte length
    memory.init $payload
    data.drop $payload))
```

`memory.init` copies from a passive data segment into a memory. It carries a data index plus a memory index. Validation checks the data segment exists, the memory exists, the destination uses the selected memory address type, and the source offset plus length are `i32`. `data.drop` carries only a data index and consumes no stack values.

The data-count rule is easy to miss: function bodies that use `memory.init` or `data.drop` require a data-count section. Starshine makes that user-visible with a separate [`datacnt_requirement`](../../../src/validate/validate.mbt) phase before code body typechecking. WAST data authoring, active/passive mode selection, string payloads, and current printer/abbreviation caveats are covered in [`data-segment-authoring.md`](data-segment-authoring.md); segment headers and data-count binary layout are covered in [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md). Data-backed GC array forms (`array.new_data`, `array.init_data`) share the data-segment index space but are not current WAST text; fixture-format guidance for those core/binary instructions lives in [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md).

## Layer Map

| Layer | Files | Current behavior |
| --- | --- | --- |
| WAST keywords | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt) | Recognizes scalar load/store names, `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, `memory.init`, and `data.drop`; atomic text keywords are a separate current gap documented in [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md). |
| WAST parsing | [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Parses scalar memargs, size/grow/fill/copy/init/drop text shapes, and has focused parser tests for the basic families. |
| WAST lowering | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) | Lowers scalar loads/stores through `wt_load_store(...)`; defaults `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, and `memory.init` memory operands to `MemIdx(0)`; resolves data identifiers for `memory.init` / `data.drop`. |
| WAST printing | [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Prints runtime memory instruction keywords and data indices, but does not print explicit memory indices for these forms. |
| Core IR | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Stores `MemArg` on scalar loads/stores and explicit `MemIdx` / `DataIdx` immediates on size/grow/fill/copy/init/drop. |
| Binary codec | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Encodes/decodes scalar opcodes, one-byte `memory.size` / `memory.grow`, and `0xFC` subcodes `8..11` for bulk memory. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) | Stack-types memory instructions, checks selected resources, enforces the data-count requirement, matches the positional memory64 rules for `memory.init` and `memory.copy`, and currently has the `memory.fill` memory64 length caveat described above. |
| Generator / WAST arbitrary | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt) | Valid generator covers scalar memory widths, nonzero memargs, memory-limit variants, bulk-memory bodies, and atomics; [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md) keeps the `[FZG]017` core/binary/generator evidence separate from WAST text support. WAST arbitrary has representative parser/printer bulk-memory text, not full typed-validity coverage. |
| HOT IR and passes | [`src/ir/hot_lift.mbt`](../../../src/ir/hot_lift.mbt), [`src/ir/hot_lower.mbt`](../../../src/ir/hot_lower.mbt), [`src/ir/hot_flags.mbt`](../../../src/ir/hot_flags.mbt), [`src/ir/effects.mbt`](../../../src/ir/effects.mbt) | Carries memory operations into HOT form, marks memory effects/traps, and lowers memory immediates back to core instructions. |

## Strategy Notes For Pass Authors

1. **Preserve traps and effect order.** Loads, stores, grow, fill, copy, and init can trap or mutate state. Do not move them across other effects unless the pass has a real alias/effect proof.
2. **Keep immediates and stack operands separate.** `offset=` and memory/data indices are instruction immediates; destination/source/length values are stack operands. See [`memory-argument-authoring.md`](memory-argument-authoring.md) for the `offset=` split.
3. **After memory-index rewrites, validate.** A pass that deletes or remaps memories must update scalar `MemArg` carriers, `MemorySize`, `MemoryGrow`, `MemoryFill`, both `MemoryCopy` indices, and the memory half of `MemoryInit`.
4. **After data-segment rewrites, validate data-count and data users.** A pass that deletes or remaps data segments must update `MemoryInit`, `DataDrop`, active data modes, and `DataCntSec` together; use [`data-segment-authoring.md`](data-segment-authoring.md) for the full segment rewrite checklist.
5. **Do not overclaim WAST text support.** Core/binary/generator support is broader than WAST text for nonzero memory indices and atomics. Use direct core or binary fixtures when testing those surfaces today, and use [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md) for atomic stack/effect/signoff rules.
6. **For memory64, test more than loads.** Include `memory.size`, `memory.grow`, `memory.init`, mixed-width `memory.copy`, and the known `memory.fill` length caveat when changing address-width logic. The official width matrix is positional, so a pass or validator fix needs separate assertions for destination, source, value, and length roles.

## Current Gaps And Caveats

- Current WAST text lowering defaults runtime memory instruction memory operands to memory `0`; nonzero memory-index behavior belongs in direct core/binary fixtures until WAST syntax and printer support are widened.
- Current Starshine validation types `memory.fill` length as `i32` even for memory64; official validation uses the selected memory address type for that length operand. The 2026-05-20 refresh in [`../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md`](../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md) is the focused source for this divergence.
- Atomic memory instructions are present in core/binary/typecheck/generator surfaces, but current WAST keyword/parser evidence does not expose them as WAST text syntax. Keep `[FZG]017` claims scoped to generator/core/binary evidence and route atomic stack/effect details through [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md).
- WAST arbitrary bulk-memory coverage is representative parser/printer coverage; typed-validity and memory64/multi-memory coverage belong to `gen_valid`, binary tests, or validator tests.

## Sources

- Source manifest: [`../raw/wasm/2026-05-19-wast-memory-instruction-sources.md`](../raw/wasm/2026-05-19-wast-memory-instruction-sources.md)
- Memory64 bulk-memory refresh: [`../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md`](../raw/wasm/2026-05-20-memory64-bulk-memory-validation-refresh.md)
- Atomic companion manifest: [`../raw/wasm/2026-05-20-atomic-memory-instruction-sources.md`](../raw/wasm/2026-05-20-atomic-memory-instruction-sources.md), [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md)
- Official WebAssembly sources: <https://webassembly.github.io/spec/core/text/instructions.html>, <https://webassembly.github.io/spec/core/syntax/instructions.html>, <https://webassembly.github.io/spec/core/binary/instructions.html>, <https://webassembly.github.io/spec/core/valid/instructions.html>, <https://webassembly.github.io/spec/core/valid/modules.html>
- Starshine implementation: [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt)
