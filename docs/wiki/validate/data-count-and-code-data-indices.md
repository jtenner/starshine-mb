---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md
  - ../raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md
  - ../../../src/lib/types.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
  - ../../../src/validate/gen_valid.mbt
related:
  - module-validation-phases.md
  - resource-sections-and-limits.md
  - diagnostics-and-invalid-repro.md
  - ../binary/data-element-and-datacount-sections.md
  - ../wast/data-segment-authoring.md
  - ../wast/memory-instruction-authoring.md
  - ../wast/gc-aggregate-instruction-authoring.md
  - ../fuzzing/generator-coverage-ledger.md
---

# Data-Count And Code Data-Index Users

## Overview

Use this page when changing validation, fuzzing, binary decoding, WAST lowering, a printer, or an optimizer pass that touches **data-count** or instructions that carry a **data index**.

Data-count is easy to misread because it has two different jobs:

1. **Count equality:** when the data-count section is present, its count must equal the number of data segments.
2. **Early availability for code validation:** when a code body contains a data-index instruction, the binary module needs a data-count section before the code section so validators can know the data-index range before the later data section is decoded.

The current primary-source recheck is [`../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md`](../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md). It confirms that the explanatory bulk-memory note still talks about `memory.init` / `data.drop`, but the enclosing official binary-module rule is broader: **any data index in the code section** requires data-count. In Starshine's core instruction model, the four code-section data-index carriers are `MemoryInit`, `DataDrop`, `ArrayNewData`, and `ArrayInitData` in [`src/lib/types.mbt`](../../../src/lib/types.mbt). The older and broader data-segment refresh remains [`../raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md`](../raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md).

## Beginner Model

A data segment is a module-level byte blob. A function body can later refer to a segment by number:

```wat
(module
  (memory 1)
  (data $payload "hello")
  (func
    i32.const 0  ;; destination memory address
    i32.const 0  ;; byte offset inside data segment
    i32.const 5  ;; byte length
    memory.init $payload
    data.drop $payload))
```

A valid binary for that shape needs `DataCntSec(1)`. Without it, Starshine reports a body-level validation error before ordinary code typechecking. That early error is not about whether data segment `0` eventually exists; it is about the module promising the data-index range before validating bodies.

GC array data instructions use the same data-index space even though current Starshine WAST text cannot author them directly:

```text
ArrayNewData(typeidx, dataidx)   ;; creates an array from bytes in a data segment
ArrayInitData(typeidx, dataidx)  ;; writes bytes from a data segment into an array
```

Those core/binary/generated fixtures should be treated as code-section data-index users too.

## Official Rule Versus Local Implementation

| Surface | Official WebAssembly 3.0 model | Current Starshine behavior | Maintenance status |
| --- | --- | --- | --- |
| Data-count equality | `DataCntSec(n)` must match the number of data segments. | [`validate_datacnt(...)`](../../../src/validate/validate.mbt) accepts absent data-count, accepts present `0` without data, rejects nonzero count without data, and rejects mismatched counts. | Aligned. |
| Missing data-count requirement | Data-count is required when any data index occurs in code. | [`validate_bulk_memory_data_count_requirement(...)`](../../../src/validate/validate.mbt) reports `FunctionBody("data count section required")` when its scanner finds a covered data-index user and no `DataCntSec`. | Diagnostic split is deliberate and useful. |
| Covered leaves in the pre-code scanner | `memory.init`, `data.drop`, `array.new_data`, and `array.init_data` are data-index instruction families. | [`instr_uses_bulk_memory_data_count(...)`](../../../src/validate/validate.mbt) currently returns true for `MemoryInit` and `DataDrop` only, while still recursing through `block`, `loop`, `if`, and `try_table` bodies. | Local/spec gap for direct core/binary GC array data users. |
| Ordinary instruction typecheck | Each data-index instruction validates its selected data segment and its own stack/type constraints. | [`typecheck_memory_init(...)`](../../../src/validate/typecheck.mbt), [`typecheck_data_drop(...)`](../../../src/validate/typecheck.mbt), [`typecheck_array_new_data(...)`](../../../src/validate/typecheck.mbt), and [`typecheck_array_init_data(...)`](../../../src/validate/typecheck.mbt) all check `DataIdx` existence during body typechecking. | Aligned for index existence; not a substitute for the pre-code data-count requirement. |
| Invalid-fuzzer coverage | A complete local invalid-AST matrix should have a stable family for every intentionally enforced public rule. | [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt) covers missing count through `memory.init` and `data.drop`, plus stack/data-index errors for GC array data instructions, but not missing count through `array.new_data` / `array.init_data`. | Add when the scanner widens. |

## Validation Flow In Starshine

[`validate_module_impl(...)`](../../../src/validate/validate.mbt) runs these data-count phases before code bodies:

```text
datasec             validate data modes and append Env.datas
datacnt             validate DataCntSec count equality
datacnt_requirement reject covered data-index code users when DataCntSec is absent
...
codesec             validate FuncSec/CodeSec pairing and typecheck each body
```

The split matters for diagnostics:

- a bad `DataCntSec` value is a [`DataCountSection`](diagnostics-and-invalid-repro.md) issue;
- a missing required `DataCntSec` is a [`FunctionBody`](diagnostics-and-invalid-repro.md) issue carrying the absolute `FuncIdx` of the first body that needs it;
- an out-of-range `DataIdx` in an otherwise count-present module is an ordinary function-body typecheck failure.

The absolute function index uses the imported-prefix model from [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md): body ordinal `0` is not necessarily `FuncIdx(0)` when function imports precede defined bodies.

## Concrete Shapes

### Count equality is section-level

```text
DataSec:    two segments
DataCntSec: 1
```

This fails even if no function body mentions data at all, because the count does not equal the data-section length. It should stay a data-count-section diagnostic rather than a body diagnostic.

### Missing data-count through bulk memory is enforced today

```wat
(module
  (memory 1)
  (data "x")
  (func
    i32.const 0
    i32.const 0
    i32.const 1
    memory.init 0))
```

If the same core module has `data_sec` but no `data_cnt_sec`, Starshine's pre-code scanner rejects it before the body stack checker can treat `memory.init` as just another instruction.

### Missing data-count through GC array data users is the documented gap

```text
DataSec: one passive data segment
Code body: ArrayNewData(TypeIdx(0), DataIdx(0))
DataCntSec: absent
```

Current Starshine can validate `DataIdx(0)` during `typecheck_array_new_data(...)`, but the earlier `datacnt_requirement` phase does not yet scan this instruction as a data-count trigger. Treat such direct core/binary cases as local validator-gap evidence, not as portable positive examples.

## Rewrite And Signoff Checklist

When data sections, data-count, or data-index instructions change:

1. **Repair all data-index carriers:** `MemoryInit`, `DataDrop`, `ArrayNewData`, `ArrayInitData`, data name maps, and pass-local metadata.
2. **Keep equality separate from requirement:** changing segment count affects `DataCntSec`; changing body instructions affects the requirement scan.
3. **Do not elide data-count from a module merely because bulk-memory instructions disappeared.** Prove that no `ArrayNewData` or `ArrayInitData` survives either.
4. **Preserve diagnostic families deliberately.** If the pre-code scanner widens to GC array data users, add focused tests and invalid-fuzzer strategies before updating docs.
5. **Use the right fixture layer.** WAST is currently good for `memory.init` / `data.drop`; direct core, binary, or generator fixtures are required for `array.new_data` / `array.init_data` until WAST aggregate text support lands.
6. **Rerun module validation after pass rewrites.** Ordinary typecheck success for a data-index instruction does not prove the module-level data-count precondition.

## Source Map

- Current focused primary-source recheck: [`../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md`](../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md)
- Broader data/data-count source refresh: [`../raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md`](../raw/wasm/2026-06-04-data-segment-datacount-current-refresh.md)
- Binary segment map: [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md)
- Data WAST authoring: [`../wast/data-segment-authoring.md`](../wast/data-segment-authoring.md)
- Runtime memory instruction authoring: [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md)
- GC aggregate instruction authoring: [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md)
- Starshine core carriers: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt)
- Starshine validation phases: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt)
- Starshine instruction typechecking: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt)
- Invalid and valid generation: [`../../../src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt)
