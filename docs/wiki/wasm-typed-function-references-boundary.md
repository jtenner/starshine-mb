---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md
  - raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md
  - raw/wasm/2026-05-20-call-ref-source-refresh.md
  - raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md
  - ../../src/lib/types.mbt
  - ../../src/wast/keywords.mbt
  - ../../src/wast/parser.mbt
  - ../../src/wast/lower_to_lib.mbt
  - ../../src/wast/module_wast.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/validate/validate.mbt
  - ../../src/validate/gen_valid.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wasm-gc-core-boundary.md
  - wast/function-call-and-module-authoring.md
  - wast/reference-instruction-authoring.md
  - wast/tail-call-authoring.md
  - wast/text-surface-gap-ledger.md
  - validate/ref-func-declarations.md
  - binary/function-import-export-and-code-sections.md
  - fuzzing/generator-coverage-ledger.md
---

# Typed Function References And `call_ref` Boundary

## Overview

Use this page when a claim involves **first-class function references** or `call_ref` / `return_call_ref`. It separates four facts that are easy to conflate:

1. **Standards status:** typed function references and `call_ref` are Core WebAssembly 3.0 / finished WebAssembly behavior, not an active proposal gap.
2. **Starshine core support:** Starshine models, encodes, decodes, validates, and generates ordinary `call_ref` and tail `return_call_ref` instructions.
3. **Starshine WAST support:** high-level Starshine WAST text currently exposes `return_call_ref` and `ref.func`, but not ordinary non-tail `call_ref` text.
4. **Declaration rules:** `ref.func` needs a module-level declaration source; `call_ref` consumes a function reference and does not declare one.

The current source bridge is [`raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md`](raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md). It rechecked the current WebAssembly Core 3.0 syntax/text/binary/validation pages, official Wasm 3.0 completion routing, historical function-references validation pages used as teaching aids, and current Starshine WAST/core/binary/validator/generator sources.

## Beginner Model

A direct call names a function index:

```wat
(call $f (i32.const 7))
```

A reference call calls through a **value** whose type says it points at a function signature:

```text
callee argument(s), then function reference, then call_ref type
```

For a function type `(func (param i32) (result i64))`, the stack intuition is:

```text
... i32 (ref null $sig)  -- call_ref $sig -->  ... i64
```

The function reference may come from `ref.func`, a table read, a global, a block result, or another expression that produces a compatible function reference. When it comes from `ref.func`, the target function must still be declared as referenceable by an export, global/table initializer, element payload/expression, or another current Starshine declaration source; see [`validate/ref-func-declarations.md`](validate/ref-func-declarations.md).

## Current Starshine Layer Map

| Layer | Current status | Evidence and guidance |
| --- | --- | --- |
| Standards / Core | `call_ref` and `return_call_ref` are Core 3.0 call-family instructions with function-type immediates. | Use the raw bridge and official Core pages linked from it for standards-status claims. The historical function-references proposal pages remain useful teaching aids, not active-status authority. |
| WAST keywords/parser | `return_call_ref` is registered; ordinary `call_ref` is not. | [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt) registers `return_call_ref`, `ref.func`, `call`, and `call_indirect`; docs and tests should not use human-authored Starshine WAST `call_ref` until keyword/parser/lowerer/printer support lands. |
| WAST lowerer/printer | Lowers and prints `return_call_ref` plus `ref.func`; does not lower or print ordinary `call_ref` text. | [`src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../src/wast/module_wast.mbt). |
| Core AST | Separate ordinary and tail reference-call variants. | [`Instruction::CallRef(TypeIdx)`](../../src/lib/types.mbt) pushes results; `ReturnCallRef(TypeIdx)` is tail-call control flow. |
| Binary codec | Opcode `0x14` decodes/encodes `call_ref`; opcode `0x15` decodes/encodes `return_call_ref`. | [`src/binary/decode.mbt`](../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../src/binary/encode.mbt). |
| Validation | The immediate must resolve to a function type. Starshine pops a nullable reference to that function heap type after the callee parameters. `return_call_ref` also checks that the callee results match the current function results and then makes the continuation unreachable. | [`typecheck_call_ref(...)`](../../src/validate/typecheck.mbt), [`typecheck_return_call_ref(...)`](../../src/validate/typecheck.mbt), [`validate/ref-func-declarations.md`](validate/ref-func-declarations.md). |
| Generator/fuzz | Valid generation can produce natural and coverage-forced reference-call flows. | [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt), [`src/validate/gen_valid_tests.mbt`](../../src/validate/gen_valid_tests.mbt), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md). |

## Concrete Shapes

### Ordinary `call_ref` with a local reference source

Use core/binary/generator fixtures for this in Starshine today because high-level WAST `call_ref` is not exposed:

```text
TypeSec:   $sig = func(i32) -> i64
Func body: ref.func $target
           local.set $callee
           i32.const 7
           local.get $callee
           CallRef($sig)
```

Validation checks the `i32` argument, then the nullable function reference of heap type `$sig`, then pushes the `i64` result. A pass that rewrites `$target`, `$sig`, or locals must repair the function index, type index, local types, and the `ref.func` declaration source together.

### `return_call_ref` as WAST-supported tail-call text

`return_call_ref` is the WAST-visible sibling, but it is a tail call:

```wat
(module
  (type $sig (func (param i32) (result i32)))
  (func $target (export "target") (type $sig)
    (local.get 0))
  (func (param i32) (result i32)
    (local.get 0)
    (ref.func $target)
    (return_call_ref (type $sig))))
```

The `ref.func` declaration rule still applies because `ref.func $target` creates the function reference. The `return_call_ref` instruction only consumes it and exits the current function after result compatibility is proven.

### Table/global/block reference sources

Starshine's generator coverage intentionally exercises more than immediate `ref.func` feeds: local, block-result, global, and table sources can all produce the function reference consumed by `CallRef`. That is useful for validator and pass signoff, but it is still **core/generator evidence**, not human-authored WAST `call_ref` parser support.

## Correctness And Rewrite Invariants

- **Keep type and value separate.** The `TypeIdx` immediate names the expected function signature. The operand stack still needs a runtime function reference value.
- **Keep declaration coverage separate.** `ref.func` targets must be declared referenceable. `call_ref` and `return_call_ref` do not add declaration sources.
- **Keep ordinary and tail control flow separate.** `CallRef` pushes results and continues; `ReturnCallRef` has return-family CFG behavior and should be routed through [`wast/tail-call-authoring.md`](wast/tail-call-authoring.md) for tail-call validation and IR2 terminator guidance.
- **Use the right fixture layer.** Use WAST for `return_call_ref` and `ref.func` tests; use core builders, binary bytes, `gen_valid`, or Binaryen oracle fixtures for ordinary `call_ref` until Starshine WAST support lands.
- **Repair all remap carriers.** Function and type rewrites must update `CallRef`, `ReturnCallRef`, `RefFunc`, direct and indirect calls, starts, exports, element payloads, function/type/name metadata, and any pass-local call summaries.

## Common Mistakes

- “`call_ref` is still an active proposal.” It is Core 3.0 / finished behavior for standards-status claims; Starshine's ordinary WAST gap is local.
- “The Core text page lacks a `call_ref` subsection, so WAT cannot spell it.” The current text page routes many control instructions through a generic verbatim-control rule; Starshine WAST is narrower for local parser/printer reasons.
- “`return_call_ref` proves ordinary `call_ref` text support.” It proves the tail-call WAST lane only.
- “A `call_ref` use declares its target.” Only the expression producing the reference, commonly `ref.func`, participates in declaration-source checks.
- “Binary decode support proves authoring support.” Binary `0x14` support is real, but high-level WAST fixtures still need a parser/lowerer/printer slice.

## Future Implementation Checklist For WAST `call_ref`

If ordinary WAST `call_ref` is added:

1. Add the keyword/parser arm and decide whether the immediate spelling follows a type use, a raw type index, or both.
2. Lower the type use through the same flat type-index rules as `call_indirect` / `return_call_ref`.
3. Print a stable accepted spelling.
4. Add parser, lowerer, printer, validator, arbitrary-WAST, and text-differential coverage.
5. Update [`wast/function-call-and-module-authoring.md`](wast/function-call-and-module-authoring.md), [`wast/reference-instruction-authoring.md`](wast/reference-instruction-authoring.md), [`wast/text-surface-gap-ledger.md`](wast/text-surface-gap-ledger.md), [`fuzzing/wast-arbitrary-parity-plan.md`](fuzzing/wast-arbitrary-parity-plan.md), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md), and this page in the same change.

## Sources

- Current focused bridge: [`raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md`](raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md)
- Current reference-call/cast refresh: [`raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md`](raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md)
- Detailed `call_ref` stack-shape note: [`raw/wasm/2026-05-20-call-ref-source-refresh.md`](raw/wasm/2026-05-20-call-ref-source-refresh.md)
- `ref.func` declaration-source guide: [`validate/ref-func-declarations.md`](validate/ref-func-declarations.md)
- WAST call guide: [`wast/function-call-and-module-authoring.md`](wast/function-call-and-module-authoring.md)
- Reference instruction guide: [`wast/reference-instruction-authoring.md`](wast/reference-instruction-authoring.md)
- Tail-call guide: [`wast/tail-call-authoring.md`](wast/tail-call-authoring.md)
- Function/index binary guide: [`binary/function-import-export-and-code-sections.md`](binary/function-import-export-and-code-sections.md)
