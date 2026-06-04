---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-exception-tag-current-refresh.md
  - ../raw/wasm/2026-05-19-wast-exception-tag-sources.md
  - ../raw/wasm/2026-05-20-exception-throwref-nullability-refresh.md
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/validate.mbt
related:
  - gc-type-authoring.md
  - element-segment-authoring.md
  - static-assertion-harness.md
  - identifier-name-and-annotation-authoring.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../binary/instruction-and-expression-encoding.md
  - ../validate/module-validation-phases.md
  - ../validate/stack-polymorphism-and-bottom.md
  - ../validate/fuzz-hardening.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST Exception Tag Authoring

## Overview

Exception handling in Starshine crosses three layers:

1. **Text/WAST authoring**: fixtures use `(tag ...)`, `throw`, `throw_ref`, and `try_table` catch clauses.
2. **Core module representation**: tags occupy the same imported-prefix `TagIdx` space whether they come from imports or from the tag section; instructions carry numeric `TagIdx` and `LabelIdx` values.
3. **Validation**: Starshine currently requires tag types to point at function types with no results; `throw` consumes a tag payload and makes control unreachable; `throw_ref` consumes nullable `exnref` and makes control unreachable; `try_table` catches branch to labels outside the temporary try body. Current Core 3.0 source is slightly broader at tag-declaration validation time, so keep the local-versus-official split below visible.

Use this page when adding WAST fixtures, fuzz-prelude shapes, validation tests, or pass rewrite rules that touch exception tags. The broader binary section guide in [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md) explains section id `13` and imported-prefix index spaces; this page focuses on the text syntax and lowering/validation traps that are easiest to miss.

The current source refresh is [`../raw/wasm/2026-06-04-exception-tag-current-refresh.md`](../raw/wasm/2026-06-04-exception-tag-current-refresh.md). It checked the official WebAssembly Core 3.0 pages dated 2026-06-03 plus local parser/lowering/printer/binary/typechecker sources. The older broad snapshot [`../raw/wasm/2026-05-19-wast-exception-tag-sources.md`](../raw/wasm/2026-05-19-wast-exception-tag-sources.md) remains useful for the original source map, and the targeted 2026-05-20 refresh [`../raw/wasm/2026-05-20-exception-throwref-nullability-refresh.md`](../raw/wasm/2026-05-20-exception-throwref-nullability-refresh.md) remains the historical correction that `throw_ref` validates with a nullable `exnref` operand while `catch_ref` / `catch_all_ref` branch payloads carry non-null captured `(ref exn)`.

## Concrete Text Shapes

### Minimal throwing tag

```wat
(module
  (type $e (func (param i32)))
  (tag $err (type $e))
  (func (param i32)
    (local.get 0)
    (throw $err)))
```

The tag's type is a function type. Its parameters are the exception payload; its result list must be empty. Starshine lowers `$err` to a numeric `TagIdx`, checks the payload is on the stack, then marks the continuation unreachable.

### Imported tags and local tags share one index space

```wat
(module
  (type $e (func))
  (import "env" "imp0" (tag $imp0 (type $e))) ;; TagIdx(0)
  (import "env" "imp1" (tag $imp1 (type $e))) ;; TagIdx(1)
  (tag $local (type $e))                         ;; TagIdx(2)
  (func
    (block $h
      (try_table (catch $imp0 $h) (throw $imp1))
      (try_table (catch $local $h) (throw $local)))))
```

This mirrors function/table/memory/global imported-prefix behavior. Lowering must resolve both throw sites and catch clauses through the combined tag space, not through the local tag section alone. The focused lowering test `wast_to_binary_module keeps imported-tag wiring stable across catch and throw forms` in [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) protects this exact family.

### `try_table` catch labels target the surrounding context

```wat
(module
  (tag $e)
  (func
    (block $outer
      (block $inner
        (try_table
          (catch $e 0)       ;; $inner
          (catch $e 1)       ;; $outer
          (catch $e $inner)
          (catch $e $outer)
          (throw $e))))))
```

Starshine's lowering gives the `try_table` body its own temporary label for result typing, but catch clauses resolve against the enclosing label space. That is why numeric catch label `0` names the nearest surrounding block, not the internal try body label. [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) has explicit nested-depth tests for this rule, and [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) typechecks catches against the outer state after the body is checked.

### Catch-reference forms add `exnref`

```wat
(module
  (tag $e)
  (func
    (block $h (result exnref)
      (try_table (catch_ref $e $h)
        (throw $e)))
    (drop))
  (func
    (block $h (result exnref)
      (try_table (result exnref) (catch_all_ref $h)
        (throw $e)))
    (drop)))
```

`catch_ref` branches with the tag payload followed by a captured non-null `(ref exn)` value; `catch_all_ref` branches with just that non-null exception reference. A target label written as `(result exnref)` can still receive it because non-null `(ref exn)` is a subtype of nullable `exnref`. Plain `catch` carries only the tag payload, and plain `catch_all` carries no values. This is a validation property, not merely syntax. The typechecker functions in [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) enforce those four payload shapes.

## Starshine Implementation Map

| Layer | Owner files | Current contract |
| --- | --- | --- |
| Core types | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | Defines `TagIdx`, `TagType`, `Catch::{Catch,CatchRef,CatchAll,CatchAllRef}`, `Instruction::{Throw,ThrowRef,TryTable}`. |
| WAST parse | [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | Parses tag fields, inline tag imports, inline tag exports, `throw`, `throw_ref`, modern `try_table`, and legacy `try` / `do` / `catch` / `catch_all` / `delegate` / `rethrow`. |
| WAST print | [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Prints tag fields, tag import/export descriptors, throw forms, modern `try_table` catches, and legacy catch syntax. |
| WAST lowering | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) | Resolves tag ids to absolute imported-prefix `TagIdx`, converts modern `try_table` to core `TryTable`, validates catch labels during lowering, and lowers legacy `try` to synthetic block/unreachable forms. |
| Module validation | [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) | Validates tag definitions after memories and before globals; each `TagType` must resolve to a function type with no results. |
| Instruction typecheck | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) | Checks `throw`, nullable-operand `throw_ref`, `try_table`, and catch payload-to-label compatibility, with `catch_ref` / `catch_all_ref` adding non-null `(ref exn)` to branch payloads. |
| Fuzz/text coverage | [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt), [`src/fuzz/invalid_text.mbt`](../../../src/fuzz/invalid_text.mbt), [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt) | WAST arbitrary generation includes representative exception syntax; invalid lanes include tag-family diagnostics and unlinkable tag-import seeds. |

## Modern Versus Legacy Exception Syntax

Prefer **modern `try_table`** for new semantic fixtures. It is the first-class core instruction shape in Starshine's `@lib.Instruction` model and is validated directly.

Starshine also accepts a legacy text family:

```wat
(module
  (tag $e)
  (func
    (try $outer
      (do
        (try
          (do (throw $e))
          (delegate $outer)))
      (catch $e)))
  (func
    (try
      (do (throw $e))
      (catch $e (rethrow 0)))))
```

Treat this as compatibility syntax, not as proof that Starshine has a preserved core legacy `try` instruction. [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) validates legacy `delegate` / `rethrow` labels during lowering, lowers accepted `rethrow` to `unreachable`, and lowers accepted legacy `try` into synthetic block/unreachable/check shapes. Add tests here only when the parser/lowerer compatibility boundary is what matters.

## Validation Invariants And Edge Cases

### Tag result-shape split: declaration versus EH use site

Current Core 3.0 and current Starshine agree that exception **use sites** need empty-result tag expansions, but they disagree about where a resultful tag is rejected:

| Shape | Current Core 3.0 model | Current Starshine model | How to classify fixtures today |
| --- | --- | --- | --- |
| `(tag (type (func (param i32))))` | Valid tag declaration; `throw` / `catch` consume or branch with the `i32` payload. | Valid tag declaration; instruction validation uses the same payload. | Ordinary portable positive. |
| `(tag (type (func (result i32))))` with no EH use | Tag type validation accepts a function type expansion with results. | `Validate for TagType` rejects the tag during `importsec` / `tagsec` validation. | Local validator-gap evidence, not an ordinary portable positive. |
| `throw` / `catch` / `catch_ref` selecting a resultful tag | Rejected at the EH instruction rule because the selected tag must expand as `func params -> epsilon`. | Already rejected earlier by the strict tag declaration rule, so the use-site check is not reached. | If Starshine widens tag declarations later, keep this rejection in instruction validation. |

This split is intentionally visible because it affects where tests should live. A declaration-only resultful tag belongs in a validator-widening test for [`src/validate/validate.mbt`](../../../src/validate/validate.mbt). A future resultful-tag `throw` / `try_table` test belongs in [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) after declaration validation is widened.

- **Tag result lists are a local/spec split.** Current Core 3.0 validates a tag type use as any function-type expansion at declaration time, while the `throw`, `catch`, and `catch_ref` instruction rules still require the selected tag to expand as `func params -> epsilon`. Starshine keeps the older/stricter rule in [`Validate for TagType`](../../../src/validate/validate.mbt): a tag type index resolving to `(func (result i32))` is rejected in `importsec` / `tagsec` before any EH use site is checked. Treat resultful tag declarations as validator-gap evidence until a deliberate widening moves the empty-result check to exception-instruction validation.
- **`throw` is stack-polymorphic after consuming payload.** It pops the tag's parameters and makes the remaining path unreachable; the general bottom-value and concrete-stack-junk boundary is [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md).
- **`throw_ref` consumes nullable `exnref`.** [`typecheck_throw_ref`](../../../src/validate/typecheck.mbt) pops `ValType::ref_null_exn()` before marking the path unreachable. A non-null exception reference is accepted by subtyping, but validation does not require non-nullness; runtime execution must still preserve the null-trap versus non-null-throw distinction.
- **Catch payloads must match their target labels.** `catch` expects the tag payload at the branch target; `catch_ref` expects payload plus non-null `(ref exn)`; `catch_all` expects no values; `catch_all_ref` expects non-null `(ref exn)`.
- **Catch labels are not the try body's temporary label.** The body uses an internal result label for stack typing, but catches branch to labels in the enclosing context.
- **Inline tag export/import syntax is supported, with a local caveat.** Inline tag exports lower into ordinary export entries. Inline tag import shorthand rejects inline exports; use a separate `(export ...)` field for that combination.
- **Binary tag attributes may grow later.** The current official binary tag type still begins with `0x00` followed by a type index, with the byte documented as a future attribute slot. Starshine currently requires/emits that `0x00` and models `TagType` as only a `TypeIdx`, so future binary broadening should revisit decode/encode/types together if attributes become meaningful.

## Pass And Rewrite Checklist

Any pass that removes, reorders, deduplicates, imports, exports, or renames tags must update every tag carrier:

1. `TagSec` entries and `TagExternType` imports.
2. `throw` immediates.
3. `try_table` `catch` / `catch_ref` clauses.
4. tag exports and structured name-section `tag_names`.
5. validation summaries or caches that include tag payload types.
6. WAST id/name expectations if the fixture source uses `$tag` ids.

When a pass rewrites control around `try_table`, rerun validation. The high-risk failure mode is a catch branch whose payload no longer matches the target label's result type, especially for `catch_ref` / `catch_all_ref` because they carry a non-null captured `(ref exn)`. When a pass rewrites around `throw_ref`, preserve operand evaluation and the possible null trap; do not treat nullable `exnref` input as already proven non-null unless the proof is local and validated.

## Authoring And Signoff Guidance

- For parser-only syntax coverage, add or update tests near the existing parser exception tests in [`src/wast/parser.mbt`](../../../src/wast/parser.mbt).
- For lowering correctness, prefer tests in [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) that inspect lowered `TagIdx`, `LabelIdx`, and `Catch` shapes and then call `@validate.validate_module(...)` when the fixture should be valid.
- For typechecker behavior, add focused `Instruction::throw_`, `Instruction::throw_ref`, or `Instruction::try_table` tests in [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt).
- For invalid-fuzz changes, keep expected `ValidationIssueFamily::tag` or related body/export/name families aligned with [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md) and the suite summary in [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md).
- For WAST arbitrary widening, update [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md) instead of implying that text prelude coverage is a full typed validity oracle.

## Sources

- Current exception tag refresh: [`../raw/wasm/2026-06-04-exception-tag-current-refresh.md`](../raw/wasm/2026-06-04-exception-tag-current-refresh.md)
- Broad primary-source and local-code manifest: [`../raw/wasm/2026-05-19-wast-exception-tag-sources.md`](../raw/wasm/2026-05-19-wast-exception-tag-sources.md)
- Targeted `throw_ref` nullability refresh: [`../raw/wasm/2026-05-20-exception-throwref-nullability-refresh.md`](../raw/wasm/2026-05-20-exception-throwref-nullability-refresh.md)
- Binary tag/resource guide: [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md)
- Validator phase guide: [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md)
- Stack-polymorphism guide: [`../validate/stack-polymorphism-and-bottom.md`](../validate/stack-polymorphism-and-bottom.md)
- Current implementation and tests: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt)
