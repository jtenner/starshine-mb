---
kind: concept
status: supported
last_reviewed: 2026-05-19
sources:
  - ../raw/wasm/2026-05-19-wast-data-segment-sources.md
  - ../raw/wasm/2026-05-13-data-element-and-datacount-sources.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/wast/arbitrary.mbt
related:
  - ./memory-instruction-authoring.md
  - ./memory-argument-authoring.md
  - ./resource-declaration-authoring.md
  - ./gc-aggregate-instruction-authoring.md
  - ./element-segment-authoring.md
  - ../binary/data-element-and-datacount-sections.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../validate/module-validation-phases.md
  - ../validate/diagnostics-and-invalid-repro.md
  - ../fuzzing/generator-coverage-ledger.md
---

# WAST Data Segment Authoring

## Overview

Use this page when writing or reviewing WAST module fields that introduce **data segments**: byte payloads that either initialize a memory at instantiation time or remain passive for later `memory.init`, `data.drop`, `array.new_data`, or `array.init_data` users.

This page owns the text shapes, Starshine WAST parser/lowerer behavior, data-count interactions, and rewrite checklist for `(data ...)` fields. Use [`memory-instruction-authoring.md`](memory-instruction-authoring.md) for the runtime stack effects and traps of `memory.init` / `data.drop`, [`memory-argument-authoring.md`](memory-argument-authoring.md) for load/store `offset=` and `align=` immediates, and [`resource-declaration-authoring.md`](resource-declaration-authoring.md) for `(memory ...)` declarations. The binary section and on-wire header map remains [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md).

The current source manifest is [`../raw/wasm/2026-05-19-wast-data-segment-sources.md`](../raw/wasm/2026-05-19-wast-data-segment-sources.md). It checks current official WebAssembly text/syntax/binary/validation sources plus Starshine WAST parser, lowerer, printer, core model, binary codec, validator, generator, and WAST arbitrary evidence.

## Beginner Model

A data segment is a named-or-numbered module resource containing raw bytes:

```wat
(module
  (memory 1)
  (data $active (i32.const 8) "abc" "def") ;; writes abcdef at memory[8] during instantiation
  (data $passive "payload")                ;; waits for memory.init / data.drop
  (func
    i32.const 0
    i32.const 0
    i32.const 7
    memory.init $passive
    data.drop $passive))
```

The bytes are not instructions. Multiple string literals concatenate into one byte payload. The offset on active data is a module-initialization constant expression, not the same thing as a function-body load/store `offset=` immediate.

## Text Shapes

### Active data for default memory `0`

```wat
(module
  (memory 1)
  (data (i32.const 16) "hello"))
```

Official text allows the memory use to be omitted; active data then targets memory `0`. Starshine's parser stores the omitted memory as `Index::Num(0)` in [`DataSegment.memory_index`](../../../src/wast/parser.mbt). Lowering emits `DataMode::active(MemIdx(0), Expr([i32.const 16]))`.

### Active data with `(offset ...)`

```wat
(module
  (memory 1)
  (data $banner (offset (i32.const 4)) "OK"))
```

The `(offset ...)` wrapper is syntactic sugar around the same offset-expression slot. [`parse_data(...)`](../../../src/wast/parser.mbt) accepts both wrapped and unwrapped offset expressions, and [`validate_datasec(...)`](../../../src/validate/validate.mbt) later requires active offsets to be constant expressions of the selected memory's address type.

### Active data for an explicit memory

```wat
(module
  (memory $m0 1)
  (memory $m1 1)
  (data $payload $m1 (i32.const 0) "x"))
```

Named and numeric memory uses are resolved only for active data. [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) calls the same named-or-numbered resolver used for other resource references, so imported memories still occupy the prefix of the memory index space. Current WAST memory declarations are memory32-only; use direct core/binary fixtures for memory64 data-offset evidence until text declarations are widened.

### Passive data

```wat
(module
  (memory 1)
  (data $payload "hello"))
```

Passive data has no parent memory and no offset expression. Starshine lowering treats `offset.length() == 0` as `DataMode::passive()`. `memory.init $payload` and `data.drop $payload` can later name the segment by the same data index space; see [`memory-instruction-authoring.md`](memory-instruction-authoring.md).

### String payloads and escapes

```wat
(module
  (memory 1)
  (data (i32.const 0) "hello" " " "world\0a" "\00"))
```

[`parse_data_strings(...)`](../../../src/wast/parser.mbt) decodes each text token and appends the resulting bytes. This means split strings, escaped bytes, and printable text all become one `Bytes` payload in [`Data`](../../../src/lib/types.mbt).

### Inline memory-data abbreviation caveat

Official text also has a memory-field abbreviation where data can be written inline with a memory declaration. Treat that as **not current Starshine WAST fixture syntax** today:

```wat
;; Official abbreviation, not current Starshine WAST parser evidence:
(memory 1 (data "hello"))
```

Use a separate memory field plus data field instead:

```wat
(memory 1)
(data (i32.const 0) "hello")
```

If Starshine adds the abbreviation later, update this page and [`resource-declaration-authoring.md`](resource-declaration-authoring.md) together because the feature spans memory declarations and data segments.

## Data Count And Instruction Users

A data segment can be valid even when the module has no `memory.init` or `data.drop`. Data-count is a separate section whose count must match the number of data segments when present. It is also required before code when a function body contains `memory.init` or `data.drop`.

GC array instructions add a second kind of data-index user. Starshine core/binary/validator surfaces support `array.new_data` and `array.init_data`, but the current high-level WAST text path does not expose official `array.*` instruction keywords, and current Starshine constant expressions do not admit official array constructor forms. Route aggregate fixture-format decisions through [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md) and initializer eligibility through [`../validate/constant-expressions.md`](../validate/constant-expressions.md).

Starshine keeps those checks separate in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt):

1. [`validate_datasec(...)`](../../../src/validate/validate.mbt) validates active data modes and pushes data entries into the validation environment.
2. [`validate_datacnt(...)`](../../../src/validate/validate.mbt) accepts absent data count, rejects count/data mismatches, accepts `DataCntSec(0)` without a data section, and rejects nonzero data count with no data section.
3. `validate_bulk_memory_data_count_requirement(...)` rejects code that uses `memory.init` or `data.drop` without a data-count section and reports the issue against the affected function body.

[`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) currently emits `DataCntSec` whenever WAST lowering emits any data segments. That is conservative for passive-only or active-only text modules, but it makes the common text-to-binary path ready for bulk-memory users.

## Layer Map

| Layer | Files | Current behavior |
| --- | --- | --- |
| WAST AST | [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Stores `DataSegment { id, memory_index, offset, data }`; defaults memory use to `0`; uses empty offset for passive data. |
| String decoding | [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Decodes one or more text string literals and concatenates them into bytes. |
| WAST lowering | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) | Resolves active memory indices, lowers active/passive modes, emits `DataSec`, and emits matching `DataCntSec` when data exists. |
| WAST printing | [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Prints `(data ...)` fields, explicit memory index text, optional `(offset ...)`, and quoted bytes. Current printer is accepted locally but is not the most concise official passive-data spelling. |
| Core model | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Represents `DataMode::active(MemIdx, Expr)`, `DataMode::passive()`, `Data`, `DataSec`, `DataCntSec`, and `DataIdx`. |
| Binary codec | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Preserves data headers `0`, `1`, and `2`, data-section id `11`, and data-count section id `12`. |
| Validation | [`src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) | Validates active offsets and data-count rules; typechecks `memory.init`, `data.drop`, `array.new_data`, and `array.init_data` data-index users. |
| Generator/fuzz | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt) | Covers data/data-count presence, data segment range coverage, non-constant data offset invalids, count mismatch invalids, and representative WAST data fields. |

## Rewrite And Signoff Guidance

When a pass, fixture generator, or printer changes data segments:

1. **Repair all data-index users.** Update `MemoryInit`, `DataDrop`, `array.new_data`, `array.init_data`, data name maps, and any pass-local metadata whenever data indices are deleted or permuted.
2. **Keep active modes tied to memories.** Memory reordering must update active `DataMode::active(memidx, offset)` modes as well as runtime memory instructions; imported memories are part of the same index space.
3. **Do not move active data offsets like load/store offsets.** Active data offsets are constant expressions evaluated during instantiation; function-body `MemArg.offset` is an instruction immediate documented in [`memory-argument-authoring.md`](memory-argument-authoring.md).
4. **Preserve startup traps and side effects.** Active data can trap during instantiation if its range is out of bounds. A shrink pass that deletes, folds, or splits active data needs the same startup-effect care described for [`memory-packing`](../binaryen/passes/memory-packing/index.md) and [`remove-unused-module-elements`](../binaryen/passes/remove-unused-module-elements/index.md).
5. **Keep data-count in sync.** If any data segment count changes, update `DataCntSec` when present. If a rewrite introduces or removes `memory.init` / `data.drop`, validate the data-count requirement again.
6. **Use the right fixture layer.** WAST is good for ordinary active/passive memory32 data. Use direct core/binary/generator fixtures for memory64 offsets, nonzero memory-index binary header edge cases, and data-backed GC array instructions until the text surface covers those fully.

## Common Mistakes

- Treating `(data $d "x")` as active data at offset `0`. In Starshine lowering, no offset means passive.
- Forgetting that multiple strings concatenate before validation and encoding.
- Confusing active data's initialization offset with `i32.load offset=N` / `i64.store offset=N`.
- Removing passive data without rewriting `memory.init`, `data.drop`, `array.new_data`, and `array.init_data` users.
- Using current WAST memory declarations as evidence for memory64 data offset behavior.
- Assuming data-count absence is always invalid. It is invalid only when the data-count equality rule is violated or code/data-index users require the section.

## Sources

- Source manifest: [`../raw/wasm/2026-05-19-wast-data-segment-sources.md`](../raw/wasm/2026-05-19-wast-data-segment-sources.md)
- Aggregate/initializer boundary: [`../raw/wasm/2026-05-20-gc-aggregate-constant-expression-refresh.md`](../raw/wasm/2026-05-20-gc-aggregate-constant-expression-refresh.md), [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md), [`../validate/constant-expressions.md`](../validate/constant-expressions.md)
- Broader segment/data-count manifest: [`../raw/wasm/2026-05-13-data-element-and-datacount-sources.md`](../raw/wasm/2026-05-13-data-element-and-datacount-sources.md)
- Official WebAssembly sources checked: <https://webassembly.github.io/spec/core/text/modules.html>, <https://webassembly.github.io/spec/core/syntax/modules.html>, <https://webassembly.github.io/spec/core/binary/modules.html>, <https://webassembly.github.io/spec/core/valid/modules.html>, <https://webassembly.github.io/spec/core/valid/instructions.html>
- Starshine implementation: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt)
