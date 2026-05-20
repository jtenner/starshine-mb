---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-19-wast-control-flow-sources.md
  - ../raw/wasm/2026-05-20-wast-parametric-select-sources.md
  - ../raw/wasm/2026-05-19-wast-reference-instruction-sources.md
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/wast/arbitrary.mbt
  - ../../../src/validate/gen_valid.mbt
related:
  - index.md
  - tail-call-authoring.md
  - exception-tag-authoring.md
  - reference-instruction-authoring.md
  - parametric-instruction-authoring.md
  - table-instruction-authoring.md
  - gc-type-authoring.md
  - ../validate/module-validation-phases.md
  - ../binary/instruction-and-expression-encoding.md
  - ../ir2/cfg-contract.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST Control-Flow Authoring

## Overview

Use this page when writing, reducing, or widening WAST fixtures that use ordinary WebAssembly control flow:

- structured control: `block`, `loop`, and `if`;
- branches: `br`, `br_if`, and `br_table`;
- terminators: `return` and `unreachable`;
- nearby parametric control value selection: untyped and typed `select`.

Tail-call control (`return_call*`) is documented separately in [`tail-call-authoring.md`](tail-call-authoring.md). Exception control (`throw`, `throw_ref`, and `try_table`) is documented separately in [`exception-tag-authoring.md`](exception-tag-authoring.md). Shared `(type $sig)` and inline function-signature type-use rules for block types live in [`gc-type-authoring.md`](gc-type-authoring.md). Detailed `drop`, untyped `select`, typed `select (result ...)`, reference-select, and local multi-value typed-select caveats live in [`parametric-instruction-authoring.md`](parametric-instruction-authoring.md). This page focuses on the label stack, branch payloads, fallthrough, and stack-polymorphic unreachable code shared by the ordinary control family.

The primary-source and local-code manifest is [`../raw/wasm/2026-05-19-wast-control-flow-sources.md`](../raw/wasm/2026-05-19-wast-control-flow-sources.md).

## Beginner Mental Model

WebAssembly is a typed stack machine with structured control. A `block`, `loop`, or `if` creates a **label** that a branch can target. The label has a type: it says which values must be supplied when control reaches that label.

```text
outer stack values
  -> enter structured control
  -> child instructions transform their own stack slice
  -> branch instructions jump to labels with typed payloads
  -> successful fallthrough pushes the structured control results
```

The key distinction is:

- a branch to a `block` or `if` label exits that construct and supplies its **results**;
- a branch to a `loop` label continues/restarts the loop and supplies its **parameters**.

Starshine mirrors that split in [`typecheck_block(...)`](../../../src/validate/typecheck.mbt), [`typecheck_if(...)`](../../../src/validate/typecheck.mbt), and [`typecheck_loop(...)`](../../../src/validate/typecheck.mbt): blocks and ifs install result-shaped labels, while loops install parameter-shaped labels.

## Layer Model

| Layer | Owner | Control-flow facts to remember |
| --- | --- | --- |
| WAST keywords/parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Recognizes ordinary control keywords, optional `$` labels, block-type syntax, `br_table` target lists, and folded `if` condition operands. |
| WAST lowerer/printer | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Resolves `$` labels to numeric `LabelIdx` depths. Prints structured control with explicit `end`; prints `br_table` targets followed by default. |
| Core instruction model | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Keeps `Block`, `Loop`, `If`, `Br`, `BrIf`, `BrTable`, `Return`, `Unreachable`, and `Select` as explicit variants. |
| Binary bytes | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Structured frames own `end`/`else` nesting. Binary well-formedness is separate from stack typing. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) | Expands block types, installs labels, checks branch payloads, treats `br_table`/`return`/`unreachable` as nonfallthrough, and applies unreachable-code stack polymorphism. |
| CFG / passes | [`src/ir/cfg.mbt`](../../../src/ir/cfg.mbt), [`../ir2/cfg-contract.md`](../ir2/cfg-contract.md) | Uses structured-control and terminator policy to split blocks and edge kinds. Passes that move or rewrite control must revalidate. |
| Fuzz / WAST arbitrary | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt) | `[FZG]003` valid-generator evidence covers typed control shapes. WAST arbitrary mirrors text syntax but is not a typed validity oracle. |

## Text Shapes And Stack Rules

| WAST shape | Stack before | Fallthrough / continuation | Branch or result rule |
| --- | --- | --- | --- |
| `block` | block params, if any | pushes block results if reachable | label expects block results. |
| `loop` | loop params, if any | pushes loop results if the loop reaches its merge | label expects loop params, not loop results. |
| `if` | optional block params plus `i32` condition | pushes results if either branch reaches merge | both branches must satisfy the same result type; an omitted `else` behaves as an empty else. |
| `br l` | target label payload | no local fallthrough | consumes payload and jumps. |
| `br_if l` | target payload plus `i32` condition | not-taken path continues with payload still on stack | validates payload availability but always pops only the condition on fallthrough. |
| `br_table l* ldefault` | target payload plus `i32` selector | no local fallthrough | every table target and default target must have equivalent payload types; final text label is the default. |
| `return` | function result payload | no local fallthrough | consumes current function results and exits. |
| `unreachable` | none | following code is stack-polymorphic | marks the local continuation unreachable. |
| `select` | `v1`, `v2`, `i32` condition | pushes selected value(s) | use [`parametric-instruction-authoring.md`](parametric-instruction-authoring.md) for typed-vs-untyped, reference-type, and local multi-value typed-select caveats. |

### `br_if` does not consume branch values on fallthrough

A common fixture bug is to write a branch payload and expect `br_if` to remove it even when the branch is not taken:

```wasm
(module
  (func (param i32) (result i32)
    (block $exit (result i32)
      (i32.const 7)   ;; payload for $exit if the branch is taken
      (local.get 0)   ;; condition
      (br_if $exit)   ;; fallthrough keeps i32.const 7 on the stack
      ;; fallthrough must now account for that still-present i32
    )))
```

Starshine's [`typecheck_br_if(...)`](../../../src/validate/typecheck.mbt) checks that the `$exit` payload is present, but it intentionally returns the state after popping only the `i32` condition. If the fallthrough path wants no payload, it must consume or structure it explicitly.

### `br_table` uses the last text label as the default

```wasm
(module
  (func (param i32) (result i32)
    (block $a (result i32)
      (block $b (result i32)
        (i32.const 11) ;; branch payload
        (local.get 0)  ;; selector
        (br_table $a $b $a)))))
```

The table targets are `$a`, `$b`; the final `$a` is the default. All possible targets must accept the same payload type. Starshine enforces that in [`typecheck_br_table(...)`](../../../src/validate/typecheck.mbt) and the parser rejects a `br_table` with no label at all.

### Loop labels carry parameters

```wasm
(module
  (func (param i32) (result i32)
    (local.get 0) ;; initial loop parameter
    (loop $again (param i32) (result i32)
      (local.get 0) ;; condition; carried loop payload is already on stack
      (br_if $again) ;; branch payload must match loop params
      drop           ;; fallthrough still has the carried payload
      (i32.const 0))))
```

For a `loop`, the label represents a jump back to the loop header. That is why the branch payload type is the loop's parameter list. A block or if label would instead use its result list. The `drop` in this example is part of the same `br_if` fallthrough rule described above: when the branch is not taken, the carried payload is still present.

## Block Types And Labels

Starshine's WAST parser accepts the same practical block-type families fixture authors usually need:

```wasm
(block)                         ;; no params/results
(block $exit (result i32) ...)  ;; optional label plus result
(block (type $sig) ...)         ;; type use; see gc-type-authoring.md
(block i32 ...)                 ;; single-result shorthand
(loop $again (param i32) (result i32) ...)
(if (result i32) ...)
```

During lowering, labels become numeric depths. The innermost label is depth `0`; each enclosing control label increments the depth. Prefer `$` labels in handwritten fixtures because they survive refactors better than numeric depths, but remember that passes and the core representation operate on `LabelIdx` values.

## `if` Syntax Caveats

Starshine supports folded and flat `if` shapes. In folded form, condition operands before `(then ...)` are emitted before the core `If` instruction because the core model is stack-based:

```wasm
(if (result i32)
  (i32.eqz (local.get 0))
  (then (i32.const 1))
  (else (i32.const 0)))
```

The lowerer stores the condition as preceding instructions plus `Instruction::If(...)`. The printer emits explicit structured `if ... else ... end` text. Do not assume the condition is a child field of the core `If` variant when writing passes; it is a stack input.

If an `if` has a result type, both branches must produce compatible results unless a branch is nonfallthrough/unreachable. An omitted `else` is an empty else path, so resultful `if` fixtures usually need an explicit `else` or a proof that the missing branch cannot fall through.

## Unreachable Code Is Polymorphic, But Not Free

After `unreachable`, `br`, `br_table`, `return`, `return_call*`, or a throwing instruction, local continuation is unreachable. In unreachable code, the validator can synthesize missing operands as bottom values. That is why a fixture can typecheck impossible-looking code after a terminator.

However, values pushed after an unreachable point are still concrete values. End-of-body and block-result checks still reject concrete stack junk that remains after the declared results are accounted for. Use [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md) for the broader body-validation contract and [`tail-call-authoring.md`](tail-call-authoring.md) for the tail-call-specific unreachable continuation.

## Current Local Gap: WAST `br_on_*` Text Surface

Starshine's core instruction model, binary codec, validator, and valid generator know about reference-branch instructions such as `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail`. The WAST keyword table and parser do not currently expose text keywords for those forms.

Implication: if a test must prove reference-branch semantics today, use a core/binary fixture or first add WAST parser/lowerer/printer coverage. Do not treat WAST's inability to author `br_on_*` as evidence that Starshine lacks the core instruction or validation rule. The reference-specific stack refinements, cast hierarchy rules, branch-label versus fallthrough type split, and WAST text-surface matrix live in [`reference-instruction-authoring.md`](reference-instruction-authoring.md), refreshed by [`../raw/wasm/2026-05-20-reference-branch-validation-refresh.md`](../raw/wasm/2026-05-20-reference-branch-validation-refresh.md); this page remains canonical for ordinary label-depth and branch-payload mechanics. The valid-generator side of this surface is tracked under `[FZG]009` in [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md).

## Rewrite And Validation Checklist

When a pass, generator, or fixture change touches ordinary control flow:

1. **Preserve label meaning.** Moving a branch across `block`, `loop`, `if`, or `try_table` scopes can change `LabelIdx` depth even if the numeric immediate still exists.
2. **Respect loop-vs-block payloads.** Loop branches target parameters; block/if branches target results.
3. **Recheck `br_if` fallthrough.** Payload values stay on the not-taken path; movement or cleanup must not silently drop them.
4. **Recheck every `br_table` target.** All table/default labels must accept equivalent payload types after any type or block-type rewrite.
5. **Handle condition stack inputs.** `if` conditions are preceding stack values, not a child expression field in the core `If` node.
6. **Keep binary and WAST layers separate.** Binary `end`/`else` frames are codec structure; passes should rewrite `Instruction` trees, not raw terminator tokens.
7. **Validate after mutation.** Run the module validator after changing block types, branch payloads, function results, or structured-control nesting. For pass work, also follow [`../tooling/validation-gates.md`](../tooling/validation-gates.md) and the relevant Binaryen oracle lane.
8. **Keep generators honest.** If WAST arbitrary mirrors a new control surface, update [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md) and make clear whether the evidence is parser/printer-only or typed-valid generation.

## Source Map

- Primary-source and local-code manifests: [`../raw/wasm/2026-05-19-wast-control-flow-sources.md`](../raw/wasm/2026-05-19-wast-control-flow-sources.md), [`../raw/wasm/2026-05-20-wast-parametric-select-sources.md`](../raw/wasm/2026-05-20-wast-parametric-select-sources.md), [`../raw/wasm/2026-05-20-reference-branch-validation-refresh.md`](../raw/wasm/2026-05-20-reference-branch-validation-refresh.md)
- WAST keyword/parser/printer/lowerer: [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Core model and binary codec: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
- Validation and CFG: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md), [`../ir2/cfg-contract.md`](../ir2/cfg-contract.md)
- Generator and WAST arbitrary: [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../../../src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md), [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md)
- Related WAST guides: [`tail-call-authoring.md`](tail-call-authoring.md), [`exception-tag-authoring.md`](exception-tag-authoring.md), [`table-instruction-authoring.md`](table-instruction-authoring.md), [`reference-instruction-authoring.md`](reference-instruction-authoring.md), [`parametric-instruction-authoring.md`](parametric-instruction-authoring.md)
