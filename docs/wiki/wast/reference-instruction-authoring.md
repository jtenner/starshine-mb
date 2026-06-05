---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md
  - ../raw/wasm/2026-06-05-gc-core-boundary-refresh.md
  - ../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md
  - ../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md
  - ../raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md
  - ../raw/wasm/2026-05-20-call-ref-source-refresh.md
  - ../raw/wasm/2026-05-19-wast-reference-instruction-sources.md
  - ../raw/wasm/2026-05-20-reference-branch-validation-refresh.md
  - ../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md
  - ../raw/wasm/2026-05-20-ref-func-declaration-refresh.md
  - ../raw/wasm/2026-05-13-ref-func-declaration-sources.md
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
  - ../wasm-typed-function-references-boundary.md
  - ../wasm-gc-core-boundary.md
  - function-call-and-module-authoring.md
  - gc-type-authoring.md
  - gc-aggregate-instruction-authoring.md
  - control-flow-authoring.md
  - tail-call-authoring.md
  - ../custom-descriptors/descriptor-instruction-surface.md
  - ../validate/ref-func-declarations.md
  - ../validate/module-validation-phases.md
  - ../binary/instruction-and-expression-encoding.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST Reference-Instruction Authoring

## Overview

Use this page when writing, reducing, or widening fixtures that mention WebAssembly reference values or reference-sensitive branch/cast instructions. For the bigger “is this GC/Core, Starshine WAST, Starshine core/binary/validator, or custom-descriptor evidence?” question, start with [`../wasm-gc-core-boundary.md`](../wasm-gc-core-boundary.md); this page owns the reference-instruction and reference-branch slice:

- basic reference values: `ref.null`, `ref.func`, `ref.is_null`, `ref.eq`, and `ref.as_non_null`;
- GC cast/test instructions represented by Starshine core and binary: `ref.test`, `ref.cast`, `br_on_cast`, and `br_on_cast_fail`;
- nullability-specialized branches represented by Starshine core and binary: `br_on_null` and `br_on_non_null`;
- Starshine's descriptor-family local/custom-descriptor text forms: `ref.test_desc`, `ref.test_desc_null`, `ref.cast_desc_eq`, and `ref.cast_desc_eq_null`.

The cross-layer GC router is [`../wasm-gc-core-boundary.md`](../wasm-gc-core-boundary.md), backed by [`../raw/wasm/2026-06-05-gc-core-boundary-refresh.md`](../raw/wasm/2026-06-05-gc-core-boundary-refresh.md). The focused typed-function-reference router is [`../wasm-typed-function-references-boundary.md`](../wasm-typed-function-references-boundary.md), backed by [`../raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md`](../raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md); use it when the question is `ref.func` feeding ordinary `call_ref`, the Core-3.0 status of reference calls, or the current Starshine WAST ordinary-`call_ref` gap. The current descriptor-instruction bridge is [`../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md`](../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md) and the focused descriptor overview is [`../custom-descriptors/descriptor-instruction-surface.md`](../custom-descriptors/descriptor-instruction-surface.md). The current ordinary reference source-routing refresh is [`../raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md`](../raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md). The broad primary-source and local-code manifest is [`../raw/wasm/2026-05-19-wast-reference-instruction-sources.md`](../raw/wasm/2026-05-19-wast-reference-instruction-sources.md). The targeted branch/cast refresh is [`../raw/wasm/2026-05-20-reference-branch-validation-refresh.md`](../raw/wasm/2026-05-20-reference-branch-validation-refresh.md), the focused ordinary reference-call refresh is [`../raw/wasm/2026-05-20-call-ref-source-refresh.md`](../raw/wasm/2026-05-20-call-ref-source-refresh.md), and the current `ref.func` / start `refs` declaration-membership refresh is [`../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md`](../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md). The key local lesson from these ingests is a layer split: **Starshine's core, binary, validator, and valid-generator surfaces are wider than its current WAST text surface.** Text fixtures can directly author the basic `ref.*` subset and descriptor-family forms today, while ordinary `ref.test` / `ref.cast`, `br_on_*`, and ordinary non-tail `call_ref` require core/binary fixtures or a WAST parser/printer widening first. For `ref.i31`, `i31.get_*`, `any.convert_extern`, and struct/array aggregate allocation or access, use [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md).

## Beginner Mental Model

A reference value is a typed handle to a function, struct, array, external value, exception, or abstract heap family. Reference instructions either:

1. **create** a reference-like value (`ref.null`, `ref.func`),
2. **ask a question** about a reference (`ref.is_null`, `ref.eq`, `ref.test`),
3. **refine or trap** on a reference (`ref.as_non_null`, `ref.cast`), or
4. **branch while refining** the value available on the branch or fallthrough path (`br_on_null`, `br_on_non_null`, `br_on_cast`, `br_on_cast_fail`).

The validator is where those meanings become precise. Binary decode only sees opcodes and immediates; WAST lowering only resolves `$` identifiers and heap/type/function names into core indices.

## Layer Model

| Layer | Owner | Reference-instruction facts to remember |
| --- | --- | --- |
| WAST keywords/parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Registers `ref.null`, `ref.is_null`, `ref.func`, `ref.eq`, `ref.as_non_null`, and descriptor-family `ref.test_desc` / `ref.cast_desc_eq` forms. Ordinary `ref.test`, `ref.cast`, and `br_on_*` are official core families, but they are not currently Starshine WAST text keywords. |
| WAST lowerer/printer | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Resolves `ref.func` function ids to absolute `FuncIdx`; resolves `ref.null` and descriptor type ids; prints the WAST-supported subset. |
| Core instruction model | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Models the wider reference family: `RefNull`, `RefIsNull`, `RefFunc`, `RefEq`, `RefAsNonNull`, `BrOnNull`, `BrOnNonNull`, `RefTest`, `RefCast`, descriptor test/cast, `BrOnCast`, and `BrOnCastFail`. |
| Binary bytes | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Encodes one-byte reference operators such as `0xD0`-family forms, one-byte `br_on_null` / `br_on_non_null`, and `0xFB` GC-prefixed test/cast/branch forms. Byte success is not proof of type or declaration validity. |
| Validation | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) | Checks nullable/nonnullable requirements, function-index existence, `ref.func` declaration membership, cast/test hierarchy compatibility, label payloads, and branch/fallthrough refinements. The branch/fallthrough split is the semantic contract for `br_on_*`. |
| Fuzz / WAST arbitrary | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt) | `[FZG]009` proves the core valid-generator can emit widened basic-reference forms. WAST arbitrary currently mirrors only text-supported descriptor forms, not ordinary `ref.test` / `ref.cast` / `br_on_*`. |

## Current Text-Surface Matrix

| Instruction family | WAST text support today | Core/binary/validator support today | Fixture guidance |
| --- | --- | --- | --- |
| `ref.null`, `ref.is_null`, `ref.func` | Yes | Yes | Prefer WAST fixtures when the purpose is parser/lowering/validation behavior. |
| `ref.eq`, `ref.as_non_null` | Yes | Yes | WAST parser classifies these through the no-immediate compare/unary path. |
| `ref.test`, `ref.cast` | No ordinary Starshine text keyword in this snapshot | Yes | Official text/binary/validation sources recognize the ordinary cast/test family; use core/binary fixtures locally or add WAST keyword/parser/lowerer/printer coverage first. |
| `br_on_null`, `br_on_non_null` | No | Yes | Treat as reference-branch core instructions; do not cite WAST parser absence as semantic absence. The current Core 3.0 syntax and binary pages are the portable anchors, while Starshine's typechecker and proposal-era pages are clearer teaching anchors for branch/fallthrough stack splits. |
| `br_on_cast`, `br_on_cast_fail` | No | Yes | Same as above; also recheck branch label payloads and cast hierarchy rules. |
| `ref.test_desc*`, `ref.cast_desc_eq*` | Yes, local/custom-descriptor surface | Yes | Use for custom-descriptor fixtures; do not conflate with ordinary official `ref.test` / `ref.cast`. |

## Stack And Validation Shapes

| Instruction | Main stack rule in Starshine | Important caveat |
| --- | --- | --- |
| `ref.null ht` | Pushes `(ref null ht)`. | WAST lowering accepts reference value-type immediates and normalizes to a nullable core reference type. |
| `ref.func f` | Pushes a non-null function reference for `f`. | The function index must exist, and the whole-module `ref_func_declarations` phase must allow the target; see [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md). |
| `ref.is_null` | Pops a nullable reference and pushes `i32`. | Current Starshine rejects non-null reference operands at typecheck time. |
| `ref.eq` | Pops two nullable `eqref` values and pushes `i32`. | Not a pointer-identity proof for arbitrary non-`eqref` references. |
| `ref.as_non_null` | Pops `(ref null ht)` and pushes `(ref ht)`. | Runtime semantics can trap on null; Starshine typechecking still only refines the static type. |
| `ref.test rt` | Pops a reference and pushes `i32`. | Core/validator support exists; current Starshine WAST text does not expose ordinary `ref.test`. |
| `ref.cast rt` | Pops a reference and pushes `rt`. | Core/validator support exists; current Starshine WAST text does not expose ordinary `ref.cast`. |
| `br_on_null l` | Pops `(ref null ht)`; null path branches to `l`, fallthrough keeps non-null `(ref ht)`. | Label payloads besides the tested reference still obey ordinary branch rules. |
| `br_on_non_null l` | Pops a nullable reference; non-null path branches with a non-null ref as the label's final payload, fallthrough consumes the operand. | The target label type must end in a compatible non-null reference. |
| `br_on_cast l rt1 rt2` | Tests a cast from `rt1` to `rt2`; success branches with the target reference, fallthrough keeps the difference type. | The target type must be compatible with both the source and the label's final reference payload. |
| `br_on_cast_fail l rt1 rt2` | Failure branches with the source-minus-target reference, success fallthrough keeps `rt2`. | This is easy to invert when writing optimizer rewrites. |

### Branch-path versus fallthrough-path results

Reference branches have two useful types to track: the type delivered to the branch label and the type left on the local fallthrough path.

| Instruction | Branch path | Fallthrough path | Local implementation anchor |
| --- | --- | --- | --- |
| `br_on_null l` | Takes label `l` only when the popped nullable ref is null; the label consumes the ordinary non-reference prefix payload already on the stack. | Pushes the same heap type as non-null `(ref ht)` after the nullable operand is proven not null. | [`typecheck_br_on_null`](../../../src/validate/typecheck.mbt) validates the heap type, checks label prefix payloads, then pushes `RefType::new(false, ht)`. |
| `br_on_non_null l` | Branches on non-null and supplies a non-null reference as the final label payload slot. | Consumes the operand and leaves no refined reference behind. | [`typecheck_br_on_non_null`](../../../src/validate/typecheck.mbt) requires the label type to end in a compatible non-null ref and checks only the prefix stack separately. |
| `br_on_cast l rt1 rt2` | Branches on successful cast and supplies `rt2` as the final label payload slot. | Pushes `diff(rt1, rt2)`, the local difference type for the failed cast. | [`typecheck_br_on_cast`](../../../src/validate/typecheck.mbt) checks `rt2 <: rt1`, checks `rt2` against the label's final reference payload, and uses `diff(rt1, rt2)` for fallthrough. |
| `br_on_cast_fail l rt1 rt2` | Branches on failed cast and supplies `diff(rt1, rt2)` as the final label payload slot. | Pushes `rt2`, the successful-cast target type. | [`typecheck_br_on_cast_fail`](../../../src/validate/typecheck.mbt) checks the label against the difference type and pushes `rt2` on success fallthrough. |

This table is the fastest way to avoid optimizer bugs: do not move or rewrite one of these instructions as if it were an ordinary `br_if` plus a separate `ref.cast`. Both the branch label payload and the fallthrough stack type are part of the instruction's static contract.

## Concrete WAST Shapes That Work Today

### `ref.null` and `ref.is_null`

```wasm
(module
  (func (result i32)
    (ref.is_null
      (ref.null func))))
```

Use this for parser/lowerer/typechecker tests that need a simple nullable reference. Starshine also supports newer abstract heap spellings such as `none`, `nofunc`, and `noextern` in `ref.null` immediates where the local value-type parser accepts them.

### `ref.func` with a declaration source

```wasm
(module
  (type $v (func))
  (func $f (type $v)
    (drop (ref.func $f)))
  (export "f" (func $f)))
```

The export declares `$f` as a legal `ref.func` target before the body use is checked. Without an export, global/table initializer, or element source, the body use fails even though `$f` exists. The declaration-source rules are intentionally centralized in [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md).

If the next instruction is a core/binary `call_ref`, the declaration rule still belongs to `ref.func`; `call_ref` only consumes the function reference and uses its type immediate for parameter/result stack typing. Current Starshine WAST can express `return_call_ref` text, but not ordinary `call_ref` text, so ordinary reference-call fixtures should route through [`../wasm-typed-function-references-boundary.md`](../wasm-typed-function-references-boundary.md), [`function-call-and-module-authoring.md`](function-call-and-module-authoring.md), and [`../raw/wasm/2026-05-20-call-ref-source-refresh.md`](../raw/wasm/2026-05-20-call-ref-source-refresh.md).

### `ref.eq` and `ref.as_non_null`

```wasm
(module
  (func (param eqref) (result i32)
    (ref.eq
      (local.get 0)
      (ref.as_non_null (local.get 0)))))
```

This is valid only if the operand to `ref.as_non_null` is statically nullable. Use it to test nullability refinement and equality stack effects, not generic cast behavior.

### Descriptor-family local forms

```wasm
(module
  (type $d (struct))
  (func (param (ref null $d))
    (drop (ref.test_desc $d (local.get 0)))
    (drop (ref.cast_desc_eq_null $d (local.get 0)))))
```

These Starshine-supported text forms are useful for custom-descriptor fixtures and Binaryen descriptor-cast parity work. They should not be used as evidence that ordinary official `ref.test` or `ref.cast` text parsing is implemented. For their descriptor metadata, exactness, stack-shape, bottom-input, and rewrite rules, use [`../custom-descriptors/descriptor-instruction-surface.md`](../custom-descriptors/descriptor-instruction-surface.md).

## Core/Binary-Only Shapes To Treat Carefully

The following families are real local core instructions and are exercised by valid generation, but the WAST text path cannot author them directly yet. The 2026-06-04 refresh confirmed this as a Starshine text-surface gap, not a portable WebAssembly absence: current official syntax/binary pages still list these families, but Starshine's keyword/parser/printer set is narrower.

```text
RefTest(nullable, HeapType)
RefCast(nullable, HeapType)
BrOnNull(LabelIdx)
BrOnNonNull(LabelIdx)
BrOnCast(LabelIdx, CastOp(source_nullable, target_nullable), source_heap, target_heap)
BrOnCastFail(LabelIdx, CastOp(source_nullable, target_nullable), source_heap, target_heap)
```

`CastOp` is a branch-on-cast immediate for source and target nullability. It is not descriptor exactness and should not be used to explain `ref.cast_desc_eq` / `ref.test_desc` behavior; route descriptor instruction semantics through [`../custom-descriptors/descriptor-instruction-surface.md`](../custom-descriptors/descriptor-instruction-surface.md), with exact-reference mechanics in [`../custom-descriptors/exact-reference-equivalence.md`](../custom-descriptors/exact-reference-equivalence.md) and `ref.get_desc` result typing in [`../custom-descriptors/ref-get-desc-fixture-path.md`](../custom-descriptors/ref-get-desc-fixture-path.md).

When a pass regression needs one of these forms today, prefer a programmatic `@lib.Instruction` fixture or a binary fixture. If the goal is WAST coverage, the first slice is not an optimizer change; it is a parser/printer/lowerer widening with tests in `src/wast` and validation coverage in `src/validate`.

The Binaryen-specific BrOn assertion bridge [`../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md`](../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md) is only tool-oracle guidance for malformed-input assertions in older `wasm-opt` builds. It does not change Starshine's local reference-branch stack rules, does not add WAST text support, and should not be used to override the source map above.

## Rewrite And Validation Checklist

1. **Keep text, core, binary, and validation claims separate.** WAST parser support is narrower than core support in this snapshot.
2. **Preserve `ref.func` declaration sources.** Function-index rewrites must update exports, globals, table initializers, element payloads/expressions, names, annotations, and surviving `ref.func` use sites together. A surviving `call_ref` does not declare anything by itself, but a surviving `ref.func` feeding it must still be declared. Use [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md) and [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md).
3. **Do not erase traps accidentally.** `ref.as_non_null` and `ref.cast` can trap at runtime. Removing or moving them needs a proof from type/flow facts, not just a successful static typecheck.
4. **Recheck both branch and fallthrough types for reference branches.** `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` carry refined references to labels, while `br_on_null`, `br_on_cast`, and `br_on_cast_fail` also leave refined fallthrough values. Pair this page with [`control-flow-authoring.md`](control-flow-authoring.md) for ordinary label-depth and branch-payload rules.
5. **Treat cast/test hierarchy checks as semantic checks.** Binary opcode decode does not prove that source and target heap types share a legal hierarchy relationship.
6. **Update WAST arbitrary only after text support exists.** `src/wast/arbitrary.mbt` should not emit ordinary `ref.test` / `ref.cast` / `br_on_*` or ordinary `call_ref` text until keywords, parser, lowerer, printer, and roundtrip tests exist.
7. **Validate after mutation.** Reference rewrites commonly touch stack types, type indices, function declarations, and labels; run module validation plus the pass's Binaryen-oracle lane where relevant.
8. **Classify external `br_on*` assertions as tool evidence first.** If Binaryen asserts while parsing malformed `br_on*` / descriptor-branch operands, preserve the installed command/build and use the BrOn assertion bridge plus [`../tooling/pass-fuzz-compare.md`](../tooling/pass-fuzz-compare.md) before claiming a Starshine semantic issue.

## Source Map

- Cross-layer GC boundary refresh: [`../raw/wasm/2026-06-05-gc-core-boundary-refresh.md`](../raw/wasm/2026-06-05-gc-core-boundary-refresh.md), [`../wasm-gc-core-boundary.md`](../wasm-gc-core-boundary.md)
- Binaryen BrOn assertion / oracle boundary bridge: [`../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md`](../raw/binaryen/2026-06-05-binaryen-bron-assertion-oracle-boundary.md)
- Descriptor instruction bridge: [`../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md`](../raw/wasm/2026-06-05-custom-descriptor-instruction-surface-refresh.md), [`../custom-descriptors/descriptor-instruction-surface.md`](../custom-descriptors/descriptor-instruction-surface.md)
- Primary-source and local-code manifests: [`../raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md`](../raw/wasm/2026-06-05-typed-function-references-boundary-refresh.md), [`../raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md`](../raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md), [`../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md`](../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md), [`../raw/wasm/2026-05-19-wast-reference-instruction-sources.md`](../raw/wasm/2026-05-19-wast-reference-instruction-sources.md), [`../raw/wasm/2026-05-20-reference-branch-validation-refresh.md`](../raw/wasm/2026-05-20-reference-branch-validation-refresh.md), [`../raw/wasm/2026-05-20-call-ref-source-refresh.md`](../raw/wasm/2026-05-20-call-ref-source-refresh.md), [`../raw/wasm/2026-05-20-ref-func-declaration-refresh.md`](../raw/wasm/2026-05-20-ref-func-declaration-refresh.md)
- WAST keyword/parser/printer/lowerer: [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Core model and binary codec: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
- Validation and generation: [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md)
- Related wiki pages: [`function-call-and-module-authoring.md`](function-call-and-module-authoring.md), [`gc-type-authoring.md`](gc-type-authoring.md), [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md), [`control-flow-authoring.md`](control-flow-authoring.md), [`../validate/ref-func-declarations.md`](../validate/ref-func-declarations.md), [`../binary/instruction-and-expression-encoding.md`](../binary/instruction-and-expression-encoding.md), [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md)
