---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-wast-parametric-select-current-refresh.md
  - ../raw/wasm/2026-05-20-wast-parametric-select-sources.md
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/wast/arbitrary.mbt
related:
  - control-flow-authoring.md
  - ../validate/stack-polymorphism-and-bottom.md
  - variable-instruction-authoring.md
  - numeric-instruction-authoring.md
  - reference-instruction-authoring.md
  - gc-type-authoring.md
  - ../validate/module-validation-phases.md
  - ../binary/instruction-and-expression-encoding.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST Parametric Instruction Authoring

## Overview

Use this page when writing, reducing, or reviewing WAST fixtures that use WebAssembly's **parametric instructions**: `drop`, untyped `select`, and typed `select (result ...)`.

These instructions are "parametric" because their core behavior is about stack values rather than a fixed numeric, memory, table, or reference operation:

- `drop` consumes one stack value of any value type and produces no value;
- untyped `select` consumes two candidate values plus an `i32` condition and produces one selected value;
- typed `select (result t)` carries an explicit result type annotation, which is required for some reference-typed cases and is the safest form for new fixtures.

Ordinary control-flow labels, `br_if` fallthrough payloads, loop parameters, and `br_table` stay in [`control-flow-authoring.md`](control-flow-authoring.md). The validator-side bottom-value contract for unreachable-code stack polymorphism lives in [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md). This page focuses on the parametric stack shapes and the places where Starshine's current implementation is wider than the current official validation text.

The latest primary-source and local-code refresh is [`../raw/wasm/2026-06-04-wast-parametric-select-current-refresh.md`](../raw/wasm/2026-06-04-wast-parametric-select-current-refresh.md), which rechecked the official WebAssembly 3.0 pages dated 2026-06-03. The earlier May 20 manifest remains useful provenance for the original page split: [`../raw/wasm/2026-05-20-wast-parametric-select-sources.md`](../raw/wasm/2026-05-20-wast-parametric-select-sources.md).

## Beginner Mental Model

Think of the operand stack just before each parametric instruction:

```text
(value) drop
  consumes value
  leaves nothing

(value_if_false) (value_if_true) (i32_condition) select
  consumes all three values
  pushes one candidate value
```

The condition is an `i32`. A nonzero condition chooses the first candidate; zero chooses the second. Validation does not evaluate the condition, so both candidates must already be type-correct before runtime.

Typed `select` makes the candidate type explicit in the instruction:

```wasm
(select (result externref)
  (ref.null extern)
  (ref.null extern)
  (local.get 0))
```

That shape is easier for readers and validators than relying on an untyped select to infer a reference type.

## Layer Model

| Layer | Owner | Parametric facts to remember |
| --- | --- | --- |
| WAST keywords/parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Registers `drop` and `select`; parses optional `select (result ...)` annotations by looking for a folded `(result ...)` immediately after `select`. |
| WAST lowerer/printer | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Converts WAST value types to core `ValType`s and prints typed select as `select (result ...)`; folded operands are still ordinary preceding stack expressions. |
| Core instruction model | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Represents `Drop` and `Select(Array[ValType]?)`; the optional array is `None` for untyped select and `Some(...)` for typed select. |
| Binary bytes | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Encodes `drop` as `0x1A`, untyped `select` as `0x1B`, and typed `select` as `0x1C` plus a vector of value types. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/match.mbt`](../../../src/validate/match.mbt) | `drop` pops one value; untyped select currently requires mutual type matching between the two candidates; typed select validates the annotation and pops two annotated value vectors plus the `i32` condition. |
| Generator / WAST arbitrary | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt) | `[FZG]003` counts typed select in the valid-generator core-control surface; WAST arbitrary emits representative typed select text but is a parser/printer surface, not a full typed-validity oracle. |

## Text Shapes And Stack Rules

| WAST shape | Stack before | Stack after | Portability profile | Notes |
| --- | --- | --- | --- | --- |
| `drop` | `t` | empty | Portable core WebAssembly | Works for any concrete value type and for stack-polymorphic bottom in unreachable code. |
| `select` | `t`, `t`, `i32` | `t` | Portable when `t` is numeric or vector | Official untyped validation is narrower than Starshine's current local implementation; prefer typed select for reference fixtures. |
| `select (result t)` | `t`, `t`, `i32` | `t` | Portable typed-select form | The explicit result type is validated before stack popping. Actual operands may match the expected type by Starshine's `Match::matches(...)` relation. |
| `select (result t1 t2 ...)` | `t1 t2 ...`, `t1 t2 ...`, `i32` | `t1 t2 ...` | Starshine-local regression surface | Locally representable, encodable, and typechecked by Starshine, but the current official validation text still frames typed select as single-value with a note about possible future multi-value select. Treat this as a Starshine-local surface until the conformance target is clarified. |

## Concrete Examples

### Plain `drop`

```wasm
(module
  (func
    (i64.const 42)
    drop))
```

`drop` is useful in fixtures when a value-producing instruction is only being tested for parsing, encoding, validation, effects, or traps. Passes may remove a `drop` only when they have proved that the dropped expression itself can be removed or rewritten without changing effects, traps, or validation.

### Untyped numeric `select`

```wasm
(module
  (func (param i32) (result i32)
    (i32.const 10)
    (i32.const 20)
    (local.get 0)
    select))
```

This is the safest untyped form: both candidates are the same scalar numeric type, and the condition is `i32`.

Starshine's [`typecheck_select_untyped(...)`](../../../src/validate/typecheck.mbt) currently accepts two candidates when `Match::matches(t1, t2, env)` and `Match::matches(t2, t1, env)` both hold. It does **not** separately enforce the official untyped-select restriction to numeric/vector result types. Therefore, do not cite an accepted untyped reference select as WebAssembly conformance evidence without a focused validator decision or test update.

### Typed reference `select`

```wasm
(module
  (func (param i32) (result externref)
    (ref.null extern)
    (ref.null extern)
    (local.get 0)
    select (result externref)))
```

This is the preferred shape for reference-valued selection. The annotation records the intended result type in text and in binary (`0x1C` plus the value-type vector), and Starshine's typed path validates the annotation through `Validate::validate(ts, env)` before consuming operands.

### Multi-value typed select caveat

Starshine's core model and binary codec store typed-select annotations as `Array[ValType]`. The local typechecker pops two copies of that whole vector and pushes the same vector back:

```wasm
(module
  (func (param i32) (result i32 i64)
    (i32.const 1) (i64.const 2)
    (i32.const 3) (i64.const 4)
    (local.get 0)
    select (result i32 i64)))
```

This shape is useful as a local regression surface for Starshine's vector-valued `Select(Some(...))` plumbing, but it is not a safe portable WAST fixture today. The 2026-06-04 refresh confirms that the current official validation page still presents typed select as an optional single value type and notes that multi-value select may be allowed in the future, even though the binary/text representation carries a vector-like annotation. Keep that contradiction visible in docs and tests instead of silently treating local support as upstream-stable WebAssembly.

## Edge Cases And Rewrite Guidance

1. **Condition order matters.** The `i32` condition is on top of the two candidate values. Folded WAST may visually nest operands, but the core instruction still consumes stack values.
2. **Unreachable code can synthesize missing operands.** `drop` and `select` use the same bottom-value stack-polymorphism model as other instructions; the focused validator contract is [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md). Concrete values pushed after an unreachable point still need to be consumed correctly before block/function end checks.
3. **Typed select is the reference-safe authoring form.** Prefer `select (result <ref-type>)` for `externref`, `funcref`, GC refs, exact refs, or descriptor-related refs. Route reference-type syntax and exactness questions through [`reference-instruction-authoring.md`](reference-instruction-authoring.md), [`gc-type-authoring.md`](gc-type-authoring.md), and the custom-descriptor pages.
4. **Do not collapse typed and untyped select in passes.** Rewriting `select (result t)` to untyped `select` can change validity for reference operands and can erase an intentional local multi-value annotation.
5. **Treat local multi-value typed select as a caveat.** It may be the right Starshine regression case, but portable WebAssembly signoff should use single-result typed select unless the validator/conformance target is updated.
6. **Choose the right profile before adding fixtures.** Use untyped `select` for numeric/vector basics, single-result typed `select` for reference or exact-type portability, and multi-value typed select only when the test explicitly targets Starshine's local vector-valued plumbing.
7. **Validate after mutation.** Any pass that changes select operands, result types, or surrounding stack shape must rerun module validation. For optimizer work, also follow [`../tooling/validation-gates.md`](../tooling/validation-gates.md) and the relevant Binaryen oracle lane.

## Source Map

- Current primary-source and local-code refresh: [`../raw/wasm/2026-06-04-wast-parametric-select-current-refresh.md`](../raw/wasm/2026-06-04-wast-parametric-select-current-refresh.md)
- Original primary-source and local-code manifest: [`../raw/wasm/2026-05-20-wast-parametric-select-sources.md`](../raw/wasm/2026-05-20-wast-parametric-select-sources.md)
- WAST keyword/parser/printer/lowerer: [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Core model and binary codec: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
- Validation and matching: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt), [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md), [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md)
- Generator and WAST arbitrary: [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../../../src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md), [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md)
