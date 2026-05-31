---
kind: concept
status: supported
last_reviewed: 2026-05-31
sources:
  - ../raw/wasm/2026-05-20-constant-expression-validation-sources.md
  - ../raw/wasm/2026-05-20-gc-aggregate-constant-expression-refresh.md
  - ../raw/wasm/2026-05-20-ref-func-declaration-refresh.md
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
related:
  - ./module-validation-phases.md
  - ./ref-func-declarations.md
  - ./diagnostics-and-invalid-repro.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../binary/data-element-and-datacount-sections.md
  - ../wast/resource-declaration-authoring.md
  - ../wast/variable-instruction-authoring.md
  - ../wast/numeric-instruction-authoring.md
  - ../wast/data-segment-authoring.md
  - ../wast/element-segment-authoring.md
  - ../wast/gc-aggregate-instruction-authoring.md
  - ../fuzzing/generator-coverage-ledger.md
---

# Constant Expressions

## Overview

A WebAssembly **constant expression** is a small expression that is evaluated during module instantiation or module validation contexts rather than during ordinary function-body execution. Starshine uses them for:

- global initializers;
- optional table initializers in the core/binary `Table` representation;
- active data-segment offsets;
- active element-segment offsets;
- function-reference and GC/reference element expressions.

The focused source manifest is [`../raw/wasm/2026-05-20-constant-expression-validation-sources.md`](../raw/wasm/2026-05-20-constant-expression-validation-sources.md). The current official WebAssembly 3.0 validation docs define a conservative constant-instruction predicate and warn that the accepted list can grow in future versions. Starshine currently accepts a broader local set in `validate_const_instr(...)`; keep that local/spec split visible when writing portable fixtures, pass contracts, or generator claims.

## Beginner Model

A normal function body can use locals, labels, calls, memory instructions, branches, and many side effects. A constant expression cannot. It must be a self-contained expression that produces exactly one value of the expected type.

```text
(global i32 (i32.const 7))              ok: one i32 constant
(global i32 (i32.const 1) (i32.add))    invalid: missing second operand
(global i32 (i32.const 1) drop)         invalid: leaves no value
(global i32 (local.get 0))              invalid: no locals in const context
```

Starshine's validator checks two things:

1. every instruction in the expression is on Starshine's constant-instruction allow-list; and
2. ordinary expression typechecking still succeeds with empty locals, empty labels, no return type, reachability, exactly one final stack value, and subtype matching against the expected type.

## Starshine Validation Flow

[`validate_const_expr(...)`](../../../src/validate/validate.mbt) is the central helper. It is intentionally two-layered:

| Step | Local check | Why it matters |
| --- | --- | --- |
| Instruction gate | [`validate_const_instr(...)`](../../../src/validate/validate.mbt) rejects instructions outside the local allow-list. | Prevents ordinary body-only operations such as `drop`, calls, memory loads, stores, table ops, branch ops, and most GC/string helper operations from entering initializer contexts. |
| Empty execution context | Typechecking runs with no locals, no labels, and no return type. | `local.get`, branch labels, `return`, and label-dependent control do not become accidentally valid. |
| Reachability | The final typechecker state must still be reachable. | A stack-polymorphic `unreachable` cannot be used to synthesize an initializer value. |
| Stack arity | The final stack must contain exactly one value. | Initializers and offsets are single-value fields; extra stack junk is invalid even if the top value has the right type. |
| Type match | The final value must match the expected `ValType` using [`Match::matches(...)`](../../../src/validate/match.mbt). | Reference subtyping, exactness, nullability, and memory/table address widths still matter. |

The helper is used by global validation, table initializer validation, active data modes, active element modes, and element expression validation in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt).

## Where Constant Expressions Appear

| Context | Expected type | Visibility / ordering rule | Diagnostic family when it fails |
| --- | --- | --- | --- |
| Global initializer | The declared global value type. | Imports plus earlier defined globals are visible; later sibling globals are not. Mutable `global.get` is rejected. | `global` |
| Optional core/binary table initializer | The table element reference type. | Uses the current validation environment. Starshine accepts imported immutable `global.get` table initializers; treat broader visibility as local behavior unless rechecked against the official spec version you target. | `table` |
| Active data offset | The selected memory's address type: `i32` for memory32, `i64` for memory64. | The memory index must exist; the expression is startup/module initialization data, not a function-body `MemArg.offset`. | `data` |
| Active element offset | The selected table's address type. | The table index must exist, the segment reference type must match the table element type, then the offset is checked. | `element` |
| Element expression payload | The segment element reference type, or `funcref` for legacy expression segments. | `ref.func` expressions also participate in Starshine's declared-function bitmap; use [`ref-func-declarations.md`](ref-func-declarations.md) for the separate declaration-membership rule. | `element` or later `ref_func_declarations` |

For binary/data layout details, pair this page with [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md). For fixture-facing WAST text, use [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md), [`../wast/data-segment-authoring.md`](../wast/data-segment-authoring.md), and [`../wast/element-segment-authoring.md`](../wast/element-segment-authoring.md).

## Official List Versus Starshine Local List

The current official WebAssembly 3.0 instruction-validation page accepts a bounded set for constant expressions: scalar/vector constants, `ref.null`, `ref.i31`, `ref.func`, `struct.new`, `struct.new_default`, `array.new`, `array.new_default`, `array.new_fixed`, `any.convert_extern`, `extern.convert_any`, immutable `global.get`, and integer `i32`/`i64` `add`/`sub`/`mul`. A `ref.func` initializer still has the independent `refs` membership obligation refreshed in [`../raw/wasm/2026-05-20-ref-func-declaration-refresh.md`](../raw/wasm/2026-05-20-ref-func-declaration-refresh.md). The aggregate-specific source bridge in [`../raw/wasm/2026-05-20-gc-aggregate-constant-expression-refresh.md`](../raw/wasm/2026-05-20-gc-aggregate-constant-expression-refresh.md) keeps the official array-constructor allowance separate from Starshine's ordinary body support for `array.*` instructions.

Starshine's local [`validate_const_instr(...)`](../../../src/validate/validate.mbt) is **not identical** to that official list:

- it is broader for many scalar integer and floating comparison, unary, binary, conversion, reinterpret, sign-extension, and saturating-truncation instructions;
- it is broader for local reference/string forms such as `RefIsNull`, `RefEq`, `RefAsNonNull`, `StringConst`, `StructNewDesc`, and `StructNewDefaultDesc`;
- it includes `AnyConvertExtern`, `ExternConvertAny`, `RefI31`, `I31GetS`, and `I31GetU`;
- it includes `StructNew` / `StructNewDefault` when the type resolves as a struct; and
- it is currently narrower than the official GC constant list for array constructors: `ArrayNew`, `ArrayNewDefault`, and `ArrayNewFixed` exist in Starshine core/typechecking, but they are not admitted by the constant-instruction allow-list reviewed here.

This is a **local Starshine validation policy**, not a blanket portability statement. When a page or test needs strict official WebAssembly behavior, cite the official source and avoid relying on Starshine-only constant forms. Conversely, do not assume every official constant-expression form is locally accepted until `validate_const_instr(...)` and focused tests say so. When a pass creates or rewrites module-level initializers, it may use Starshine's local validator as the immediate safety gate, but it should still document whether the result is intended to be portable to external engines.

## Examples

### Earlier immutable global read

```wat
(global $base i32 (i32.const 7))
(global $copy i32 (global.get $base))
```

Starshine accepts this because the second global is validated after `$base` has been added to the global environment, and `$base` is immutable. The tests `validate_module accepts global initializer global.get from earlier immutable module global` and `... imported immutable global` lock this behavior in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt).

### Mutable global read rejection

```wat
(global $m (mut i32) (i32.const 7))
(global $bad i32 (global.get $m))
```

This fails even though `$m` exists and has type `i32`: a constant expression may not read a mutable global. The invalid-AST stable strategies `mutable-global-get-in-const-init` and `mutable-global-get-in-table-init` keep the diagnostic families live in [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt).

### Active data offset is not `MemArg.offset`

```wat
(memory 1)
(global $base i32 (i32.const 4))
(data (memory 0) (offset (global.get $base)) "x")
```

The `global.get` is an initialization-time expression that computes where the active segment is copied during instantiation. It is not the same as the static immediate in `i32.load offset=4`. Use [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md) for function-body `MemArg` details and [`../wast/data-segment-authoring.md`](../wast/data-segment-authoring.md) for active data authoring.

### Non-constant sequence rejection

```wat
(data (i32.const 1) drop "x")
```

Starshine rejects this before ordinary type mismatch questions because `drop` is not a constant instruction, and even if it were, the expression would leave no final value. The test `validate_module rejects data offset with non-constant instruction sequence` locks this shape.

## Pass And Generator Guidance

- **Do not move arbitrary function-body code into initializers.** A body-valid expression can still be invalid in a constant-expression context because it uses locals, labels, memory, calls, drops, table ops, mutable globals, multiple results, or unreachable stack polymorphism.
- **Preserve declaration order.** Reordering globals can invalidate `global.get` initializers unless references are rewritten and the new order still exposes only immutable imports or earlier globals.
- **Keep active offsets distinct from memory/table immediates.** Memory/table lowering passes must repair active segment offsets separately from load/store `MemArg` fields and runtime table instructions.
- **Treat trapping local extensions with care.** Some locally accepted Starshine constant-instruction forms, such as integer division or reference non-null checks, can have runtime failure modes. Moving them across startup/runtime boundaries needs an explicit semantic proof. Also remember the opposite direction: a currently official constant-expression family such as array construction still needs local allow-list and test evidence before a Starshine pass may emit it in an initializer.
- **Use the generator ledger vocabulary.** `[FZG]008` records `ConstExprVariants` coverage in [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md). It proves Starshine can deliberately emit and measure widened valid constant-expression families; it does not prove every WAST text spelling or every official-portability claim. Use `gen_valid_const_expr_observed_op_matrix(...)` when a fuzzer report needs the finer context/op-family attribution for global initializers, active offsets, element payloads, or table initializers.
- **Add invalid strategies for user-visible failures.** New constant-expression rejections should have stable invalid-AST strategies when they are durable validator behavior. Existing examples include mutable global reads and non-constant active offsets.

## Code Map

| Surface | Repository location |
| --- | --- |
| Constant-instruction allow-list | [`validate_const_instr(...)`](../../../src/validate/validate.mbt) |
| Constant-expression typechecking | [`validate_const_expr(...)`](../../../src/validate/validate.mbt) |
| Global initializer validation | [`validate_global(...)`](../../../src/validate/validate.mbt), [`validate_globalsec(...)`](../../../src/validate/validate.mbt) |
| Table initializer validation | `validate_table(...)` in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) |
| Active data offsets | `Validate for DataMode` in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) |
| Active element offsets and element expressions | `validate_elem_mode(...)` and `Validate for ElemKind` in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) |
| Valid-generator widening | [`gen_valid_const_expr_for_global(...)`](../../../src/validate/gen_valid.mbt), `gen_valid_const_expr_from_context(...)`, `gen_valid_const_expr_context_for_use(...)`, `gen_valid_active_offset_from(...)`, `gen_valid_const_expr_observed_op_matrix(...)`, `allow_const_expr_variants`, `ConstExprVariants`; current focused coverage includes the shared `ref.i31` path for global, table initializer, and element payload targets, plus imported immutable reference `global.get` for global initializers when no higher-priority typed GC/ref constructor lane owns that target. The GenValid context allow-list records active data and active element offsets as address-typed constant-expression targets: memory/table32 offsets use numeric `i32.const` or immutable imported `i32 global.get`, while focused memory64 active data coverage uses either an `i64.const` offset or an imported immutable `i64 global.get`. Boundary active-offset coverage now includes coverage-forced `i32.const 65536` data/element offsets and a no-import memory64 `i64.const 4294967296` data offset; see note [`0689`](../raw/research/0689-2026-05-31-fuz1037-boundary-active-offsets.md). Descriptor initializer coverage now includes an imported immutable exact descriptor global feeding `struct.new_default_desc` to build the paired descriptor-bearing described struct in a global initializer; see note [`0690`](../raw/research/0690-2026-05-31-fuz1037-descriptor-initializers.md). Context/op-family reporting now distinguishes numeric constants, `ref.null`, `ref.func`, imported immutable `global.get`, `ref.i31`, and GC constructor families per initializer/offset/payload context; see note [`0691`](../raw/research/0691-2026-05-31-fuz1037-context-op-report.md). Element payload expressions have their own reference-producing context row so they do not get conflated with active offsets. Inventory note [`0688`](../raw/research/0688-2026-05-31-fuz1037-const-expr-inventory.md) audits the current matrix, call sites, feature facts, and tests; closeout note [`0692`](../raw/research/0692-2026-05-31-fuz1037-closeout.md) records that no active FUZ1037 initializer-expression slice remains after R1-R4. |
| Invalid diagnostics | [`validate_invalid_ast_registry()`](../../../src/validate/invalid_fuzzer.mbt) |

## Signoff Checklist

When changing constant-expression behavior:

1. Update `validate_const_instr(...)` and focused validator tests first.
2. Add or update invalid-AST strategies for newly durable rejection families.
3. If WAST text syntax is involved, update the relevant authoring page and `src/wast` parser/lowerer/printer tests.
4. If generator coverage changes, update `[FZG]008` rows in [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md).
5. Re-run the ordinary validation gate from [`../tooling/validation-gates.md`](../tooling/validation-gates.md); pass-specific rewrites still need Binaryen oracle comparison when an upstream pass owns equivalent behavior.

## Sources

- Source manifest: [`../raw/wasm/2026-05-20-constant-expression-validation-sources.md`](../raw/wasm/2026-05-20-constant-expression-validation-sources.md)
- Aggregate constant-expression refresh: [`../raw/wasm/2026-05-20-gc-aggregate-constant-expression-refresh.md`](../raw/wasm/2026-05-20-gc-aggregate-constant-expression-refresh.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md)
- `ref.func` declaration refresh: [`../raw/wasm/2026-05-20-ref-func-declaration-refresh.md`](../raw/wasm/2026-05-20-ref-func-declaration-refresh.md)
- Validator implementation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt)
- Generator and invalid-fuzzer evidence: [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`../../../src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt)
- Related validator pages: [`module-validation-phases.md`](module-validation-phases.md), [`ref-func-declarations.md`](ref-func-declarations.md), [`diagnostics-and-invalid-repro.md`](diagnostics-and-invalid-repro.md)
