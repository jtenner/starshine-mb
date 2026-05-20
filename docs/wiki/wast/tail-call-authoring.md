---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-20-call-ref-source-refresh.md
  - ../raw/wasm/2026-05-19-wast-tail-call-sources.md
  - ../raw/wasm/2026-05-19-tail-call-control-flow-sources.md
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/ir/hot_flags.mbt
  - ../../../src/ir/cfg.mbt
related:
  - function-call-and-module-authoring.md
  - table-instruction-authoring.md
  - gc-type-authoring.md
  - exception-tag-authoring.md
  - reference-instruction-authoring.md
  - ../ir2/cfg-contract.md
  - ../binary/instruction-and-expression-encoding.md
  - ../binary/function-import-export-and-code-sections.md
  - ../validate/module-validation-phases.md
  - ../validate/stack-polymorphism-and-bottom.md
  - ../fuzzing/generator-coverage-ledger.md
---

# WAST Tail-Call Authoring

## Overview

Use this page when writing, debugging, or widening WAST fixtures that contain WebAssembly tail calls:

- `return_call` for a direct function-index tail call;
- `return_call_indirect` for a table-mediated tail call;
- `return_call_ref` for a reference-call tail call.

The beginner mental model is: **a tail call is still a call, but it is also a return from the current function.** The callee receives parameters like an ordinary call. If the callee finishes normally, control returns to the caller of the current function, not to the instruction after the tail call. That means Starshine must treat tail calls as call-family use sites for indices, types, traps, and effects, while treating them as return-family terminators for validation and CFG flow. The non-tail function/import/export/start and direct-`call` authoring contract lives in [`function-call-and-module-authoring.md`](function-call-and-module-authoring.md); shared WAST type-use and rec-group flat-index rules live in [`gc-type-authoring.md`](gc-type-authoring.md).

The focused `call_ref` / `return_call_ref` split is refreshed in [`../raw/wasm/2026-05-20-call-ref-source-refresh.md`](../raw/wasm/2026-05-20-call-ref-source-refresh.md). The broader tail-call primary-source and local-code manifest remains [`../raw/wasm/2026-05-19-wast-tail-call-sources.md`](../raw/wasm/2026-05-19-wast-tail-call-sources.md), and the narrower CFG-only source snapshot remains [`../raw/wasm/2026-05-19-tail-call-control-flow-sources.md`](../raw/wasm/2026-05-19-tail-call-control-flow-sources.md).

## Layer Model

| Layer | Owner | Tail-call facts to remember |
| --- | --- | --- |
| WAST keywords/parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | `return_call` requires a function index. `return_call_indirect` accepts an optional table index before its type use and defaults omitted table to `0`. `return_call_ref` takes a type use. |
| WAST lowerer/printer | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | `$` ids and type uses resolve to numeric `FuncIdx`, `TableIdx`, and `TypeIdx`. Printer emits explicit resolved indices, so default-table input may roundtrip less tersely. Type-use details are centralized in [`gc-type-authoring.md`](gc-type-authoring.md). |
| Core instruction model | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Distinct `Instruction::ReturnCall`, `ReturnCallIndirect`, and `ReturnCallRef` variants keep direct, table-mediated, and reference-call carriers visible to passes. |
| Binary bytes | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Direct, indirect, and reference tail calls encode as `0x12`, `0x13`, and `0x15`. `return_call_indirect` encodes type index before table index, matching the ordinary `call_indirect` binary order. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) | The selected callee results must match the current function return type. On success, the state becomes unreachable/stack-polymorphic for local continuation; the general bottom-value model lives in [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md). |
| IR2 CFG | [`src/ir/hot_flags.mbt`](../../../src/ir/hot_flags.mbt), [`src/ir/cfg.mbt`](../../../src/ir/cfg.mbt) | Tail-call HOT ops are calls, side-effecting/trapping, and terminators. The concrete CFG builder routes them to the synthetic normal exit with `ReturnEdge`; see [`../ir2/cfg-contract.md`](../ir2/cfg-contract.md) for the current helper-test gap. |

## Instruction Families And Stack Shapes

The official validation model is easiest to remember as “ordinary call inputs, current-function return output.” The continuation after a valid tail call is unreachable, so later instructions do not receive ordinary results from the tail call.

| WAST instruction | Text immediates | Stack before | Local continuation | Starshine notes |
| --- | --- | --- | --- | --- |
| `return_call` | `funcidx` | callee params | unreachable | Resolves to `FuncIdx`; callee results must equal current function returns. |
| `return_call_indirect` | optional `tableidx`, then `typeuse` | callee params..., table element index | unreachable | Resolves `typeuse` to `TypeIdx` and table to `TableIdx`; table must be function-reference-compatible; current table64 caveat is shared with [`table-instruction-authoring.md`](table-instruction-authoring.md). |
| `return_call_ref` | `typeuse` | callee params..., function reference | unreachable | Resolves `typeuse` to a function type; consumes a reference to that function type. It shares the target/reference shape with ordinary `call_ref`, but exits instead of pushing results. |

### Why “unreachable” is not “no validation”

After a tail call validates, following code is stack-polymorphic because it is unreachable. The tail-call instruction itself still has strict checks; use [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md) for the shared bottom-value and concrete-stack-junk boundary:

1. target function/type/table indices must exist;
2. the operand stack must provide the callee parameters, plus a table index or function reference for indirect/reference forms;
3. the target result list must match the current function return list;
4. table-mediated forms must use a compatible function-reference table.

This is why a malformed `return_call_indirect` fixture can fail before the unreachable continuation matters.

## Concrete WAST Shapes

### Direct tail call

```wasm
(module
  (func $callee (param i32) (result i64)
    (i64.extend_i32_s (local.get 0)))

  (func (export "run") (param i32) (result i64)
    (local.get 0)
    (return_call $callee)))
```

`$callee` consumes one `i32` and returns one `i64`. The caller also returns `i64`, so the target results match the current function return type.

### Return-type mismatch negative

```wasm
(module
  (func $callee (result i64)
    (i64.const 1))

  (func (export "bad") (result i32)
    (return_call $callee)))
```

This should be an invalid fixture: the callee returns `i64`, but the current function promises `i32`. Do not “fix” it by adding an `i32.wrap_i64` after the tail call; there is no ordinary local continuation where that conversion could run.

### Indirect tail call with default table

```wasm
(module
  (type $sig (func (param i32) (result i32)))
  (table 1 funcref)
  (elem (i32.const 0) func $callee)
  (func $callee (param i32) (result i32)
    (local.get 0))

  (func (export "run") (param i32 i32) (result i32)
    (local.get 0) ;; callee param
    (local.get 1) ;; table element index
    (return_call_indirect (type $sig))))
```

The omitted table index means table `0`. Starshine's WAST parser accepts that shorthand, while the lowerer stores the resolved `TableIdx`. For explicit multi-table tests, prefer spelling the table to avoid hiding remap bugs:

```wasm
(return_call_indirect $table1 (type $sig)
  (local.get 0)
  (local.get 1))
```

### Reference tail call

```wasm
(module
  (type $sig (func (param i32) (result i32)))
  (func (export "run") (param i32) (param (ref $sig)) (result i32)
    (local.get 0)
    (local.get 1)
    (return_call_ref (type $sig))))
```

`return_call_ref` is not a `ref.func` declaration source by itself. If a fixture materializes the function reference with `ref.func`, the instruction's text/core stack shape lives in [`reference-instruction-authoring.md`](reference-instruction-authoring.md), and the declaration-source rules still live in [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md). For the non-tail sibling, use [`function-call-and-module-authoring.md`](function-call-and-module-authoring.md): ordinary `call_ref` is currently a core/binary/validator/generator surface, not Starshine WAST text.

### Tail call inside `try_table`

```wasm
(module
  (func $callee (result i32) (i32.const 7))
  (func (export "run") (result i32)
    (block $exit (result i32)
      (try_table (result i32) (catch_all $exit)
        (return_call $callee)))))
```

A tail call in a protected region is still a return-position transfer for normal completion, while exceptions/traps still follow the surrounding exception policy. Use [`exception-tag-authoring.md`](exception-tag-authoring.md) for catch-list payload and label rules, and [`../ir2/cfg-contract.md`](../ir2/cfg-contract.md) for CFG edge expectations.

## Rewrite And Validation Guidance

When a pass, generator, or fixture change touches tail calls, use this checklist:

1. **Function remaps:** update direct `FuncIdx` carriers in `return_call` along with `call`, `ref.func`, start, exports, element payloads, function names, and function annotations. The full function-index map lives in [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md).
2. **Type remaps:** update `TypeIdx` carriers in `return_call_indirect` and `return_call_ref` when rewriting function types, rec groups, or signature tables. For WAST-origin fixtures, also keep named and inline type-use behavior aligned with [`gc-type-authoring.md`](gc-type-authoring.md).
3. **Table remaps:** update the `TableIdx` carrier in `return_call_indirect`; the table side of this contract is shared with [`table-instruction-authoring.md`](table-instruction-authoring.md).
4. **Signature rewrites:** if a pass changes callee parameter or result types, revalidate all tail callsites. Dropping or changing a result is more constrained than for ordinary calls because the target results must equal the current function returns.
5. **CFG/analysis:** treat tail calls as calls for effect, escape, and target-use analysis, but as terminators for block splitting, dominance, liveness, and local SSA continuation.
6. **Inlining and DAE:** never lower a nested `return_call*` as an ordinary `call` unless the transform has a source-backed repair strategy. Several Binaryen parity pages keep tail calls as explicit bailouts or guarded subsets for this reason.
7. **Fuzz evidence:** WAST arbitrary and valid-generator work should test direct, indirect, and reference tail forms separately because each has a different index/type/table surface.

## Common Mistakes

- **Mistake: “`return_call` pushes the callee results.”** It does not push results for the current local continuation. It exits the current function, so following code is unreachable.
- **Mistake: “`return_call_indirect` is covered by table docs only.”** It is both a table instruction and a tail-call instruction. Table docs cover table indices and table64 caveats; this page covers return-type and terminator semantics.
- **Mistake: “A tail call declares `ref.func`.”** Direct calls, ordinary `call_ref`, and tail calls consume existing function indices or references but are not `ref.func` declaration sources.
- **Mistake: “Proposal text can override the current spec.”** The tail-call proposal repository is historical. Use the current WebAssembly core draft/W3C pages for syntax and validation, and use the proposal only for rationale.

## Source Map

- Focused reference-call source refresh: [`../raw/wasm/2026-05-20-call-ref-source-refresh.md`](../raw/wasm/2026-05-20-call-ref-source-refresh.md)
- Primary-source and local-code manifest: [`../raw/wasm/2026-05-19-wast-tail-call-sources.md`](../raw/wasm/2026-05-19-wast-tail-call-sources.md)
- CFG-only tail-call source manifest: [`../raw/wasm/2026-05-19-tail-call-control-flow-sources.md`](../raw/wasm/2026-05-19-tail-call-control-flow-sources.md)
- WAST keyword/parser/printer/lowerer: [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Core model and binary codec: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
- Validation and CFG: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/ir/hot_flags.mbt`](../../../src/ir/hot_flags.mbt), [`../../../src/ir/cfg.mbt`](../../../src/ir/cfg.mbt), [`../ir2/cfg-contract.md`](../ir2/cfg-contract.md)
- Related WAST guides: [`function-call-and-module-authoring.md`](function-call-and-module-authoring.md), [`table-instruction-authoring.md`](table-instruction-authoring.md), [`gc-type-authoring.md`](gc-type-authoring.md), [`exception-tag-authoring.md`](exception-tag-authoring.md), [`reference-instruction-authoring.md`](reference-instruction-authoring.md), [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md)
