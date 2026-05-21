---
kind: concept
status: supported
last_reviewed: 2026-05-21
sources:
  - ../raw/wasm/2026-05-20-function-code-section-source-refresh.md
  - ../raw/wasm/2026-05-20-start-section-validation-sources.md
  - ../raw/wasm/2026-05-13-function-import-export-section-sources.md
  - ../../../src/lib/types.mbt
  - ../../../src/lib/module.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate_proof/func_index.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/binary/tests.mbt
  - ../../../src/fuzz/invalid_binary.mbt
  - ../../../src/fuzz/invalid_binary_wbtest.mbt
related:
  - module-section-map.md
  - custom-and-name-sections.md
  - data-element-and-datacount-sections.md
  - instruction-and-expression-encoding.md
  - type-table-memory-global-tag-sections.md
  - ../validation/moonbit-prove-strategy.md
  - ../validate/module-validation-phases.md
  - ../validate/import-export-and-external-type-matching.md
  - ../validate/start-section.md
  - ../validate/ref-func-declarations.md
  - ../wast/function-call-and-module-authoring.md
  - ../binaryen/passes/reorder-functions/index.md
  - ../binaryen/passes/remove-unused-module-elements/index.md
  - ../binaryen/passes/duplicate-function-elimination/index.md
---

# Binary Function, Import, Export, Start, And Code Sections

## Overview

This is the canonical Starshine wiki page for the function-index-bearing core module surface: imports, defined-function declarations, exports, start functions, and code bodies. It intentionally sits in `docs/wiki/binary/` rather than under a pass folder because many optimizers and validators need the same section contract. For the WAST authoring side of `(func ...)`, inline import/export forms, `(start ...)`, direct `call`, and the function/type side of `call_indirect`, see [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md). For the whole-module standard-section order, custom-section placement, and cross-section rewrite checklist, see [`module-section-map.md`](module-section-map.md).

The WebAssembly Core Specification models imports and definitions as shared index spaces. A function import is not a separate kind of function reference: it occupies the first entries of the function index space, and defined functions come after those imports. The same imported-prefix rule applies to tables, memories, globals, and tags; see [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md) for those non-function resource spaces. The binary format then splits defined functions across two parallel sections:

- the **function section** (`id = 3`) stores one type index per defined function;
- the **code section** (`id = 10`) stores the matching body for each defined function.

Starshine mirrors that split in [`Module`](../../../src/lib/types.mbt#L351-L377): `import_sec`, `func_sec`, `export_sec`, `start_sec`, and `code_sec` are separate optional fields, while [`FuncIdx`](../../../src/lib/types.mbt#L104) is the absolute index used by calls, `ref.func`, exports, starts, element payloads, names, and pass rewrite maps. For the byte-level instruction/expression contract inside each code body, see [`instruction-and-expression-encoding.md`](instruction-and-expression-encoding.md). For the separate module-level declaration set that makes `ref.func` values legal, see [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md).

## Section Shapes

| Section | Binary id | Starshine representation | Main invariant |
| --- | ---: | --- | --- |
| Import | `2` | [`ImportSec(Array[Import])`](../../../src/lib/types.mbt#L430) where each import has module name, field name, and [`ExternType`](../../../src/lib/types.mbt#L180-L187). | Imported functions/tables/memories/globals/tags extend the same index spaces as local definitions, before local definitions. |
| Function | `3` | [`FuncSec(Array[TypeIdx])`](../../../src/lib/types.mbt#L433). | One function type index for each **defined** function body, not for imports. |
| Export | `7` | [`ExportSec(Array[Export])`](../../../src/lib/types.mbt#L460) with [`ExternIdx`](../../../src/lib/types.mbt#L189-L196). | Export names are unique and each index resolves in the target index space. |
| Start | `8` | [`StartSec(FuncIdx)`](../../../src/lib/types.mbt#L463). | Target function exists and has no params/results. |
| Code | `10` | [`CodeSec(Array[Func])`](../../../src/lib/types.mbt#L493). | Body vector length equals `FuncSec` length; body ordinal `i` belongs to absolute function index `imported_func_count + i`; each body is locals plus an expression whose binary instruction details are covered in [`instruction-and-expression-encoding.md`](instruction-and-expression-encoding.md). |

The current source refresh in [`../raw/wasm/2026-05-20-function-code-section-source-refresh.md`](../raw/wasm/2026-05-20-function-code-section-source-refresh.md) rechecks the official WebAssembly 3.0 module, binary, validation, and text sources behind this table. The earlier broader snapshot [`../raw/wasm/2026-05-13-function-import-export-section-sources.md`](../raw/wasm/2026-05-13-function-import-export-section-sources.md) remains the surrounding function/import/export/start context.

## Imported-Prefix Function Index Model

A beginner-friendly way to read Starshine `FuncIdx` values is:

```text
absolute FuncIdx space

0 .. imported_func_count - 1                 imported function declarations
imported_func_count .. total_func_count - 1  defined function declarations/bodies
```

For example, a module with one imported function and two defined functions has:

```wat
(module
  (type $v (func))
  (import "env" "host" (func $host (type $v))) ;; FuncIdx(0)
  (func $a (type $v))                         ;; FuncIdx(1), code body 0
  (func $b (type $v) (call $a))               ;; FuncIdx(2), code body 1
  (export "run" (func $b))
  (start $a))
```

After WAST lowering, `$a` and `$b` are not stored as symbolic references in the core module. [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt#L2893-L3531) resolves imports first, then defined functions, then exports and start declarations. The resulting body for `$b` contains `Instruction::Call(FuncIdx(1))`, and the start section contains `StartSec(FuncIdx(1))`.

Starshine keeps the mapping explicit in the validator proof sidecar:

- [`defined_func_body_index(imported_func_count, func_idx)`](../../../src/validate_proof/func_index.mbt#L2-L17) maps an absolute function index to a defined-body ordinal, returning `None` for imports.
- [`defined_func_absolute_index(imported_func_count, body_idx)`](../../../src/validate_proof/func_index.mbt#L19-L31) maps a body ordinal back to the absolute function index.
- [`defined_body_func_index(imported_func_count, body_count, body_idx)`](../../../src/validate_proof/func_index.mbt#L33-L47) checks a body ordinal and returns the absolute function index when in range.

These helpers matter for diagnostics and pass writeback. A failure in defined body `0` is reported as `FuncIdx(imported_func_count)`, not as `FuncIdx(0)`, when imports precede it.

## Decode And Encode Flow

| Stage | Starshine behavior | Evidence |
| --- | --- | --- |
| Decode imports | [`Decode for ImportSec`](../../../src/binary/decode.mbt#L2109-L2115) reads section `2` as a vector of imports. [`Decode for ExternType`](../../../src/binary/decode.mbt#L2061-L2105) maps external-kind bytes `0x00` through `0x04` to function/table/memory/global/tag types. | `src/binary/decode.mbt` |
| Decode function declarations | [`Decode for FuncSec`](../../../src/binary/decode.mbt#L2117-L2123) reads section `3` as a vector of type indices. | `src/binary/decode.mbt` |
| Decode exports/start/code | [`Decode for ExportSec`](../../../src/binary/decode.mbt#L2280-L2286), [`Decode for StartSec`](../../../src/binary/decode.mbt#L2288-L2298), and [`Decode for CodeSec`](../../../src/binary/decode.mbt#L1795-L1810) preserve the separate section surfaces. | `src/binary/decode.mbt` |
| Encode sections | [`Encode for ImportSec`](../../../src/binary/encode.mbt#L1151-L1153), [`FuncSec`](../../../src/binary/encode.mbt#L1307-L1309), [`ExportSec`](../../../src/binary/encode.mbt#L1351-L1353), [`StartSec`](../../../src/binary/encode.mbt#L1366-L1369), and [`CodeSec`](../../../src/binary/encode.mbt#L1474-L1488) write section ids `2`, `3`, `7`, `8`, and `10`. | `src/binary/encode.mbt` |
| Encode whole module | [`Encode for Module`](../../../src/binary/encode.mbt#L1651-L1727) emits the standard sections in canonical order, with import before function declarations and code after data-count/element handling. | `src/binary/encode.mbt` |
| Round-trip fuzz | [`run_binary_fuzz_with_state`](../../../src/binary/tests.mbt#L160-L240) includes independent arbitrary round-trips for `ImportSec`, `FuncSec`, `ExportSec`, `StartSec`, and `CodeSec`. Focused invalid-binary export descriptor byte carriers live in [`src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt) and [`src/fuzz/invalid_binary_wbtest.mbt`](../../../src/fuzz/invalid_binary_wbtest.mbt). | `src/binary/tests.mbt`; `src/fuzz/invalid_binary.mbt`; `src/fuzz/invalid_binary_wbtest.mbt` |

Starshine does not preserve a source-level interleaving of imports, functions, exports, and start declarations after lowering. The core module preserves the semantic section surfaces and index targets. The binary-invalid lane locks the export descriptor decode surface with `invalid-export-kind-byte`, malformed export index ULEB carriers (`malformed-export-func-index-uleb`, `malformed-export-table-index-uleb`, `malformed-export-memory-index-uleb`, `malformed-export-global-index-uleb`, `malformed-export-tag-index-uleb`), and overwide export index ULEB carriers (`overwide-export-func-index-uleb`, `overwide-export-table-index-uleb`, `overwide-export-memory-index-uleb`, `overwide-export-global-index-uleb`, `overwide-export-tag-index-uleb`).

## Code Body Local Model

The binary code section is easy to misread because the function type and the function body split the local environment across two sections:

```text
function type from TypeSec / FuncSec
  params: local indices 0 .. param_count - 1
  results: expected body result types

code entry from CodeSec
  u32 body_size
  compressed local runs for non-parameter locals
  expression ending in end
```

Starshine follows that split directly. [`FuncSec(Array[TypeIdx])`](../../../src/lib/types.mbt) stores each defined function's signature index, while each [`Func(Locals, Expr)`](../../../src/lib/types.mbt) stores only the body-local declarations and expression. The WAST lowerer assigns parameter ids first, computes the base local index from either the referenced type-use or inline parameter count, then assigns explicit `(local ...)` ids after that base before lowering instructions. The stored [`Locals`](../../../src/lib/types.mbt) are therefore **not** the full local index space; they are the non-parameter suffix that the code entry encodes.

For example:

```wat
(module
  (type $add1 (func (param i32) (result i32)))
  (func $f (type $add1) (local $tmp i32)
    local.get 0      ;; parameter from the function type
    i32.const 1
    i32.add
    local.tee $tmp   ;; explicit body local, absolute local index 1
    drop
    local.get $tmp))
```

Lowering resolves `$tmp` to absolute `LocalIdx(1)`, but the binary code entry encodes one `i32` local in the local-run vector. During encoding, [`Encode for Func`](../../../src/binary/encode.mbt) serializes the local runs and expression into a temporary body payload, prefixes that payload length, and writes the raw body bytes. During decoding, [`Decode for Func`](../../../src/binary/decode.mbt) reads that length-framed body, decodes local runs, rejects expanded local counts above `2^32 - 1`, rejects malformed local value-type bytes, then decodes the expression. The binary-invalid lane locks that decode-stage surface with `invalid-code-local-valtype-byte`, malformed local count ULEB carriers (`malformed-code-local-decl-count-uleb`, `malformed-code-local-run-count-uleb`), and overwide local count ULEB carriers (`overwide-code-local-decl-count-uleb`, `overwide-code-local-run-count-uleb`).

This distinction matters for rewrites:

- Changing a function signature changes the parameter prefix and can invalidate body `LocalIdx` uses even when the code-local vector is untouched.
- Adding, deleting, or reordering body locals changes the code entry and every instruction that uses affected local indices, but it does not change the `FuncSec` type index unless parameter/result types change.
- Body ordinal `i` still maps to absolute `FuncIdx(imported_func_count + i)`. Do not use a code-section array index as a module-wide function index without adding the imported-function prefix.

## Validation Contract

Validation is phased so every index space exists before function bodies are typechecked. [`validate/module-validation-phases.md`](../validate/module-validation-phases.md) owns the full phase contract; [`validate_module_impl`](../../../src/validate/validate.mbt#L2895-L3266) runs roughly:

1. types;
2. imports, extending function/table/memory/global/tag index spaces;
3. function declarations, extending the function index space with defined signatures;
4. tables/memories/tags/globals;
5. elements/data/data-count;
6. start section;
7. exports;
8. `ref.func` declaration check;
9. code bodies;
10. name section.

Important function-section rules:

- [`validate_importsec`](../../../src/validate/validate.mbt#L1816-L1852) resolves imported function type indices and appends imported signatures before defined signatures.
- [`validate_funcsec`](../../../src/validate/validate.mbt#L1569-L1590) requires each defined-function type index to resolve to a function type and appends it to the environment.
- [`validate_startsec`](../../../src/validate/validate.mbt#L1857-L1875) rejects an absent target, any parameter, or any result on the start function; the focused start-section guide is [`../validate/start-section.md`](../validate/start-section.md).
- [`validate_exportsec_unique`](../../../src/validate/validate.mbt#L2168-L2190) first validates export indices, then rejects duplicate export names. The focused import/export boundary page [`../validate/import-export-and-external-type-matching.md`](../validate/import-export-and-external-type-matching.md) owns the split between ordinary module validation and reusable host external-type matching rules.
- [`validate_codesec_diag`](../../../src/validate/validate.mbt#L1405-L1554) rejects mismatched `FuncSec`/`CodeSec` presence or length, maps code body ordinals to absolute function indices, then validates each body against its resolved signature.

The consequence for pass authors is simple: if a rewrite changes function count, function order, function signatures, or any absolute function index, it must repair every function-index carrier before the validator sees the module.

## Pass Rewrite Checklist

A pass that deletes, merges, reorders, or appends functions must audit all of these surfaces:

- `func_sec` and `code_sec` must remain parallel for defined functions.
- Function imports are part of the absolute `FuncIdx` space but have no code bodies.
- Function signature edits must distinguish parameter locals from encoded body locals; local-index repair often crosses both the type-use and code-entry layers.
- Body instructions include direct calls, tail calls, and `ref.func` through [`Instruction::Call`](../../../src/lib/types.mbt#L526), `ReturnCall`, and `RefFunc`.
- `start_sec` stores one `FuncIdx`.
- `export_sec` can store `FuncExternIdx` values.
- `elem_sec` can store legacy function-index payloads and expression payloads containing `ref.func`; see [`data-element-and-datacount-sections.md`](data-element-and-datacount-sections.md).
- Global and table initializer expressions can contain `ref.func` declarations that are checked before code validation.
- `name_sec` and `func_annotation_sec` may be keyed by function index; see [`custom-and-name-sections.md`](custom-and-name-sections.md) for name/custom metadata and [`../wast/code-metadata-and-function-annotations.md`](../wast/code-metadata-and-function-annotations.md) for Starshine's function/import annotation lane.
- Type, table, memory, global, tag, and local string literal pool changes have their own index-carrier checklist in [`type-table-memory-global-tag-sections.md`](type-table-memory-global-tag-sections.md).

Existing pass dossiers that depend on this checklist include:

- [`duplicate-function-elimination`](../binaryen/passes/duplicate-function-elimination/index.md), which merges defined functions and rewrites `FuncIdx` users;
- [`remove-unused-module-elements`](../binaryen/passes/remove-unused-module-elements/index.md), which removes unrooted imports/definitions and repairs module index spaces;
- [`reorder-functions`](../binaryen/passes/reorder-functions/index.md), whose future Starshine port is harder than Binaryen's declaration-list sort because Starshine stores numeric `FuncIdx` references;
- [`reorder-functions-by-name`](../binaryen/passes/reorder-functions-by-name/index.md), which shares the same future remap requirement.

## Edge Cases And Invariants

- **Empty `FuncSec`/`CodeSec` absence is equivalent.** Starshine validation accepts both sections absent, and also accepts a present empty side without a non-empty partner; a non-empty side without the other side is invalid.
- **Imports are bodyless functions.** Imported functions can be called, exported, named, and used as start targets if their signature is empty, but they do not have entries in `CodeSec`.
- **Export-name uniqueness is semantic in Starshine validation.** Import names do not need to be unique, but duplicate export names are rejected; see [`../validate/import-export-and-external-type-matching.md`](../validate/import-export-and-external-type-matching.md) for the `ExportSection` diagnostic and invalid-fuzzer strategy map.
- **Start does not by itself make `ref.func` declared in Starshine's current declaration check.** The focused start-section guide in [`../validate/start-section.md`](../validate/start-section.md) owns empty-signature validation, imported-start invalid matrices, and rewrite guidance; the declaration guide in [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md) records the current local/spec divergence. The current test suite includes a regression titled `validate_module does not treat start as a ref.func declaration source` in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt#L8032-L8060). If that policy changes, update this page, both validator guides, and the raw-source snapshots together.
- **Function body diagnostics use absolute indices.** A code-body ordinal is not a user-facing function index once imports exist.
- **Section order is canonical on encode.** WAST source order and custom-section gaps are normalized into the core section order; exact source layout is not a stable post-lowering property.

## Sources

- Current primary-source refresh: [`../raw/wasm/2026-05-20-function-code-section-source-refresh.md`](../raw/wasm/2026-05-20-function-code-section-source-refresh.md)
- Focused start-section refresh: [`../raw/wasm/2026-05-20-start-section-validation-sources.md`](../raw/wasm/2026-05-20-start-section-validation-sources.md)
- Broader primary-source snapshot: [`../raw/wasm/2026-05-13-function-import-export-section-sources.md`](../raw/wasm/2026-05-13-function-import-export-section-sources.md)
- Core representation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/lib/module.mbt`](../../../src/lib/module.mbt)
- Decode and encode: [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/binary/tests.mbt`](../../../src/binary/tests.mbt)
- Validation and proof helpers: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt), [`../../../src/validate_proof/func_index.mbt`](../../../src/validate_proof/func_index.mbt)
- WAST lowering and authoring: [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md)
- Related docs: [`custom-and-name-sections.md`](custom-and-name-sections.md), [`data-element-and-datacount-sections.md`](data-element-and-datacount-sections.md), [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md), [`../validate/import-export-and-external-type-matching.md`](../validate/import-export-and-external-type-matching.md), [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md), [`../validation/moonbit-prove-strategy.md`](../validation/moonbit-prove-strategy.md), [`../binaryen/passes/reorder-functions/index.md`](../binaryen/passes/reorder-functions/index.md), [`../binaryen/passes/remove-unused-module-elements/index.md`](../binaryen/passes/remove-unused-module-elements/index.md)
