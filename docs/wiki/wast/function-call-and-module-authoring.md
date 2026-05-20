---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-20-call-ref-source-refresh.md
  - ../raw/wasm/2026-05-19-wast-call-and-function-sources.md
  - ../raw/wasm/2026-05-13-function-import-export-section-sources.md
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
  - index.md
  - table-instruction-authoring.md
  - tail-call-authoring.md
  - reference-instruction-authoring.md
  - gc-type-authoring.md
  - identifier-name-and-annotation-authoring.md
  - ../binary/function-import-export-and-code-sections.md
  - ../validate/ref-func-declarations.md
  - ../validate/module-validation-phases.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST Function, Call, Import, Export, And Start Authoring

## Overview

Use this page when writing or debugging WAST fixtures that define functions, import or export functions, choose a start function, or call another function. It owns the WAST authoring surface for:

- `(func ...)` definitions, parameters, locals, inline exports, and inline function imports;
- `(import "m" "f" (func ...))`, `(export "name" (func ...))`, and `(start ...)` fields;
- direct `call` instructions;
- the function/type side of `call_indirect`;
- the current ordinary `call_ref` split: core/binary/validator/generator support exists, while high-level WAST text support does not yet.

Neighbor pages own the parts that are easy to conflate with this topic:

- [`table-instruction-authoring.md`](table-instruction-authoring.md) owns table-index defaults, `call_indirect` table compatibility, table64 caveats, and runtime table instructions.
- [`tail-call-authoring.md`](tail-call-authoring.md) owns `return_call`, `return_call_indirect`, and `return_call_ref` because tail calls are also return-family terminators.
- [`gc-type-authoring.md`](gc-type-authoring.md) owns WAST type definitions, rec groups, subtypes, and shared type-use rules for `(type $sig)` and inline `(param ...)` / `(result ...)` signatures.
- [`reference-instruction-authoring.md`](reference-instruction-authoring.md) and [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md) own `ref.func`, declaration sources, and the current start-section declaration divergence.
- [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md) owns binary section ids, imported-prefix function index spaces, `FuncSec`/`CodeSec` parallelism, and module-pass remap checklists.

The current primary-source and local-code manifest for the ordinary reference-call split is [`../raw/wasm/2026-05-20-call-ref-source-refresh.md`](../raw/wasm/2026-05-20-call-ref-source-refresh.md). The broader WAST function/import/export/start source snapshot remains [`../raw/wasm/2026-05-19-wast-call-and-function-sources.md`](../raw/wasm/2026-05-19-wast-call-and-function-sources.md), narrowing the binary-section baseline in [`../raw/wasm/2026-05-13-function-import-export-section-sources.md`](../raw/wasm/2026-05-13-function-import-export-section-sources.md).

## Beginner Model: Names Become Absolute Function Indices

In WAST, `$` identifiers make examples readable:

```wat
(module
  (type $unary (func (param i32) (result i32)))
  (import "env" "host" (func $host (type $unary))) ;; absolute FuncIdx 0
  (func $add1 (type $unary)                         ;; absolute FuncIdx 1
    (i32.add (local.get 0) (i32.const 1)))
  (func (export "run") (param i32) (result i32)     ;; absolute FuncIdx 2
    (call $add1 (local.get 0))))
```

After lowering, Starshine does not keep `call $add1` as a symbolic call. [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) resolves `$add1` to `FuncIdx(1)` and stores an ordinary core [`Instruction::Call`](../../../src/lib/types.mbt). The imported function takes index `0`, and defined functions come after all function imports. This is the same imported-prefix model used by binary decode, validation, `ref.func`, exports, starts, element payloads, names, and function-rewriting passes.

## Layer Model

| Layer | Owner | What to remember |
| --- | --- | --- |
| WAST keywords/parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Registers and parses `func`, `import`, `export`, `start`, `call`, `call_indirect`, and tail-call keywords. `call_indirect` accepts an optional table index that defaults to `0`. Ordinary `call_ref` is not currently a WAST keyword. |
| WAST lowerer | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) | Resolves `$` and numeric indices to imported-prefix `FuncIdx`, `TypeIdx`, and `TableIdx`; turns inline exports into ordinary export entries; turns inline function imports into ordinary import entries. Type-use details and rec-group flat-index caveats live in [`gc-type-authoring.md`](gc-type-authoring.md). |
| WAST printer | [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Prints resolved indices for call-family instructions, so shorthand/default-table input can roundtrip as a more explicit numeric form. |
| Core model | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Stores `ImportSec`, `FuncSec`, `ExportSec`, `StartSec`, `CodeSec`, `FuncIdx`, and distinct `Call`, `CallIndirect`, `ReturnCall*`, `CallRef`, and `ReturnCallRef` instruction variants. |
| Binary bytes | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Roundtrips ordinary `call_ref` as opcode `0x14` and `return_call_ref` as opcode `0x15`, each with a `TypeIdx` immediate. Binary support does not imply WAST keyword support. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) | Typechecks direct, table-mediated, and reference-call stack effects; validates function/import/export/start/code sections; rejects duplicate export names; and checks code bodies after all signatures are known. |
| Generator / WAST arbitrary | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt) | Valid generator tracks ordinary calls, indirect calls, tail calls, start sections, and import/export topology. WAST arbitrary mirrors parser/printer shapes and is not a typed-validity oracle. |

## Function And Module Field Shapes

### Defined function

```wat
(func $id
  (export "optional-inline-name")
  (type $sig)
  (param $x i32)
  (local $tmp i32)
  (call $some_func (local.get $x)))
```

Starshine's parser accepts an optional function id, any inline exports, a type use or inline signature, local declarations, and then instructions. Lowering records a defined-function signature in `FuncSec` and the body in `CodeSec`. The function id can also be lowered into `NameSec.func_names`; debug/source-name behavior is covered by [`identifier-name-and-annotation-authoring.md`](identifier-name-and-annotation-authoring.md).

### Explicit function import

```wat
(import "env" "host" (func $host (param i32) (result i32)))
```

A function import contributes a function signature and consumes the next absolute function index, but it does not create a code body. Calls, exports, starts, element segments, and `ref.func` can still target imported functions if the relevant validation rules are satisfied.

### Inline function import shorthand

```wat
(func $host (import "env" "host") (param i32) (result i32))
```

Starshine lowers this to the same import-section shape as the explicit form. Current local parser behavior deliberately rejects inline exports on this shorthand:

```wat
(func $host (export "host") (import "env" "host") (param i32)) ;; local parser error
```

Use a separate field instead:

```wat
(func $host (import "env" "host") (param i32))
(export "host" (func $host))
```

This is a Starshine authoring caveat, not a binary-module limitation: the lowered core module can represent an imported function and an export targeting that imported `FuncIdx`.

### Function export

```wat
(export "run" (func $run))
```

Exports target absolute function indices and have globally unique export names at validation time. Inline function exports and explicit function export fields lower to the same [`ExportSec`](../../../src/lib/types.mbt) shape. Function exports also count as `ref.func` declaration sources in Starshine's whole-module declaration scan; see [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md).

### Start function

```wat
(start $init)
```

A start function must exist and have no parameters and no results. Current WAST lowering stores the last parsed start field as the module `StartSec`; validation still rejects invalid start signatures. Do not use start as a stand-in for a `ref.func` declaration source in current Starshine: the official module-validation rule includes start in the `refs` set, but Starshine intentionally does not yet treat start-only references as declared, as documented in [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md).

## Call Instruction Shapes

| Instruction | Text immediates | Stack before | Stack after | Main authoring rule |
| --- | --- | --- | --- | --- |
| `call` | `funcidx` | callee params | callee results | The function index must exist; stack operands must match the target function type. |
| `call_indirect` | optional `tableidx`, then `typeuse` | call params..., table element index | function type results | The type index must resolve to a function type, and the selected table must be function-reference-compatible. Table index defaults and table64 caveats live in [`table-instruction-authoring.md`](table-instruction-authoring.md). |
| `call_ref` | `typeidx` / type use in official text; not Starshine WAST text today | call params..., function reference | function type results | Core/binary/validator/generator-visible ordinary reference call. Use non-WAST fixtures until Starshine adds parser/lowerer/printer support. |
| `return_call` | `funcidx` | callee params | unreachable | Shares function-index resolution with `call`, but result validation and CFG behavior live in [`tail-call-authoring.md`](tail-call-authoring.md). |
| `return_call_indirect` | optional `tableidx`, then `typeuse` | call params..., table element index | unreachable | Shares indirect-call resolution but is a tail call; see both [`table-instruction-authoring.md`](table-instruction-authoring.md) and [`tail-call-authoring.md`](tail-call-authoring.md). |
| `return_call_ref` | `typeuse` | call params..., function reference | unreachable | WAST-supported reference tail-call form; ordinary non-tail `call_ref` is currently not exposed as WAST text. |

### Direct call example

```wat
(module
  (func $double (param i32) (result i32)
    (i32.mul (local.get 0) (i32.const 2)))

  (func (export "run") (param i32) (result i32)
    (call $double (local.get 0))))
```

The direct call consumes the argument produced by `local.get` and pushes the `i32` result from `$double`.

### Indirect call example

```wat
(module
  (type $sig (func (param i32) (result i32)))
  (table $tab 1 funcref)
  (elem (i32.const 0) func $double)
  (func $double (type $sig)
    (i32.mul (local.get 0) (i32.const 2)))

  (func (export "run") (param i32 i32) (result i32)
    (local.get 0) ;; callee param
    (local.get 1) ;; table element index
    (call_indirect $tab (type $sig))))
```

`call_indirect` crosses three index spaces: the table index, the type index, and the dynamic table element index on the operand stack. The source text spells table then type; Starshine lowers to the core `Instruction::call_indirect(TypeIdx, TableIdx)` order. If the type use names a signature after a `rec` group or relies on an inline signature, apply the flat-index and implicit-function-type rules in [`gc-type-authoring.md`](gc-type-authoring.md).

### Ordinary `call_ref` core/binary route

Official WebAssembly treats ordinary `call_ref` as a call-family instruction with a function type immediate. The caller places the callee parameters first, then the function reference. If the immediate type is `(func (param i32) (result i64))`, the stack intuition is:

```text
... i32 (ref null $sig)  -- call_ref $sig -->  ... i64
```

Starshine's core model, binary codec, validator, and valid generator know about this shape: [`Instruction::CallRef(TypeIdx)`](../../../src/lib/types.mbt), opcodes `0x14` / `0x15` in [`src/binary/decode.mbt`](../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`typecheck_call_ref`](../../../src/validate/typecheck.mbt), and the natural `ref.func` + `call_ref` generator path in [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt). Current high-level WAST text still does **not** register a `call_ref` keyword, so WAST authors should not write direct text fixtures for ordinary `call_ref` until parser/lowerer/printer support exists. Use core builders, binary bytes, valid-generator seeds, or Binaryen oracle fixtures for that surface.

Do not confuse the function reference with a declaration source. A `ref.func $f` that feeds `call_ref` must still satisfy the module-level declaration rule in [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md); `call_ref` itself only consumes the reference and is not a new declaration source. Use `return_call_ref` only when the test is specifically about tail-call semantics, because it has the same reference-call target shape but exits the current function instead of pushing ordinary results.

## Validation And Signoff Guidance

- **Keep function existence separate from call stack typing.** A known `FuncIdx` can still fail if the operand stack does not match the target signature.
- **Keep direct calls separate from first-class function references.** `call $f` does not require `$f` to be in the `ref.func` declaration set; `ref.func $f` does, including when the resulting reference is immediately consumed by `call_ref`.
- **Treat function imports as ordinary function indices.** They can be called and exported, but they do not have `CodeSec` bodies.
- **Re-run full module validation after changing imports, signatures, calls, exports, starts, elements, or names.** The validator needs all signatures before code-body typechecking and needs all declaration sources before `ref.func` declaration checks.
- **For pass rewrites, use the binary checklist.** Any pass that deletes, reorders, merges, or appends functions must repair every `FuncIdx` carrier listed in [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md), not just visible `call` instructions.
- **For generator work, keep the ledgers linked.** Ordinary calls and indirect calls are broad generator counters, while `[FZG]020` covers import/export topology and `[FZG]004` covers tail calls. See [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md) and [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md).

## Common Mistakes

- **Mistake: “The first defined function is always `FuncIdx(0)`.** It is only `0` when there are no function imports. With imports, defined bodies start at `imported_func_count`.
- **Mistake: “Inline exports are source-only and can be ignored after parsing.”** They lower to ordinary export entries and affect duplicate-export validation and `ref.func` declaration coverage.
- **Mistake: “`call_indirect` belongs only to table docs.”** Table docs own table resource rules, but the instruction also depends on function types and call argument/result typing.
- **Mistake: “Start roots a `ref.func` use in Starshine.”** Not today. Start validates as an empty-signature function target, but start-only `ref.func` declaration remains a recorded local/spec divergence.
- **Mistake: “WAST arbitrary call text proves valid module typing.”** WAST arbitrary primarily exercises parser/printer roundtrips. Use `gen_valid` and module validation for typed-validity evidence.

## Sources

- Focused `call_ref` source refresh: [`../raw/wasm/2026-05-20-call-ref-source-refresh.md`](../raw/wasm/2026-05-20-call-ref-source-refresh.md)
- Focused function/import/export/start snapshot: [`../raw/wasm/2026-05-19-wast-call-and-function-sources.md`](../raw/wasm/2026-05-19-wast-call-and-function-sources.md)
- Broader function-section snapshot: [`../raw/wasm/2026-05-13-function-import-export-section-sources.md`](../raw/wasm/2026-05-13-function-import-export-section-sources.md)
- WAST parser/lowerer/printer: [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt)
- Core, binary, and validation: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt)
- Generation: [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../../../src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt)
- Related wiki pages: [`table-instruction-authoring.md`](table-instruction-authoring.md), [`tail-call-authoring.md`](tail-call-authoring.md), [`reference-instruction-authoring.md`](reference-instruction-authoring.md), [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md), [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md)
