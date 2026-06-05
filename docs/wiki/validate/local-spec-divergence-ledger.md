---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-05-extended-name-section-boundary-refresh.md
  - ../raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md
  - ../raw/validation/2026-06-04-local-spec-divergence-ledger-source-bridge.md
  - ../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md
  - ../raw/wasm/2026-06-04-exception-tag-current-refresh.md
  - ../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md
  - ../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md
  - ../raw/wasm/2026-06-04-constant-expression-current-refresh.md
  - ../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md
  - ../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/lib/types.mbt
related:
  - ./module-validation-phases.md
  - ./ref-func-declarations.md
  - ./resource-sections-and-limits.md
  - ./memory-table-address-widths.md
  - ./data-count-and-code-data-indices.md
  - ./constant-expressions.md
  - ./import-export-and-external-type-matching.md
  - ../wasm-feature-status-and-proposal-boundaries.md
  - ../wasm-extended-name-section-boundary.md
  - ../wasm-js-string-builtins-boundary.md
  - ../wast/exception-tag-authoring.md
  - ../wast/memory-instruction-authoring.md
  - ../wast/table-instruction-authoring.md
  - ../wast/gc-aggregate-instruction-authoring.md
---

# Validator Local/Spec Divergence Ledger

## Overview

Use this page when a validation test, invalid-fuzzer case, generator fixture, binary fixture, optimizer pass, or wiki page asks: **"Is this current WebAssembly, current Starshine, or a known local split?"**

The focused validator pages remain the source of truth for each rule. This ledger is the navigation layer that keeps the current local/spec splits visible in one place. It is grounded in the source bridge [`../raw/validation/2026-06-04-local-spec-divergence-ledger-source-bridge.md`](../raw/validation/2026-06-04-local-spec-divergence-ledger-source-bridge.md), which rechecked the current WebAssembly Core 3.0 validation pages plus Starshine's validator implementation and the existing raw source manifests.

A **local/spec divergence** here means one of three things:

1. **Starshine is stricter than current Core WebAssembly.** A portable WebAssembly shape may be rejected locally until a validator-widening slice lands.
2. **Starshine is broader or local-policy-specific.** A local extension, proposal mirror, or metadata policy is intentionally accepted/checked by Starshine but should not be taught as stable Core WebAssembly.
3. **Starshine has a partial implementation of a positional rule.** Some operands or sections are aligned, while sibling operands still carry older `i32` or narrow scanning assumptions.

This page deliberately does **not** list ordinary WAST parser/printer gaps. If the module cannot be authored in high-level WAST text but the core/binary/validator model is correct, route through the relevant WAST authoring page instead of this ledger.

## Quick Triage Flow

1. **Name the layer first.** Is the behavior about binary decode, module validation, instruction typechecking, WAST text lowering, runtime/linking, or optimizer output validity?
2. **Check the row below.** If the shape appears here, treat current local behavior as a documented split rather than an accidental green or red result.
3. **Follow the focused owner page.** Each row links to the page that owns examples, exact source locations, invalid-fuzzer expectations, and signoff guidance.
4. **Update all dependents when the split changes.** At minimum, update the focused page, this ledger, [`module-validation-phases.md`](module-validation-phases.md), [`docs/wiki/index.md`](../index.md), and [`docs/wiki/log.md`](../log.md).

## Current Validator-Facing Splits

| Surface | Current Core WebAssembly / proposal source | Current Starshine behavior | Owner pages and code routes | Fixture guidance |
| --- | --- | --- | --- | --- |
| `ref.func` declaration sources and `start` | Core module validation includes optional start among function-reference declaration sources (`refs`), and `ref.func x` requires `x` in both `funcs` and `refs`. | [`collect_declared_funcs_bitmap(...)`](../../../src/validate/validate.mbt) marks exports, global/table initializer `ref.func`, and element payloads/expressions, but intentionally excludes `start_sec`; start-only `ref.func` declaration remains rejected locally. | [`ref-func-declarations.md`](ref-func-declarations.md), [`start-section.md`](start-section.md), [`../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md`](../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md). | Use start-only `ref.func` shapes as local/spec divergence tests, not portable green fixtures, until the bitmap and regression tests deliberately change. |
| Resultful exception tag declarations | Current Core 3.0 tag-type validation accepts function types with results at declaration time; `throw`, `catch`, and `catch_ref` still require empty-result tags at instruction use sites. | [`Validate for TagType`](../../../src/validate/validate.mbt) rejects resultful tag imports and tag-section entries before EH instruction validation can see them. | [`resource-sections-and-limits.md`](resource-sections-and-limits.md), [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md), [`../raw/wasm/2026-06-04-exception-tag-current-refresh.md`](../raw/wasm/2026-06-04-exception-tag-current-refresh.md). | Declaration-only resultful tags belong in future section-validator widening tests; use-site resultful tag rejection should stay in [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) after widening. |
| Data-count requirement for GC-array data users | Core binary validation requires `DataCntSec` when any data index occurs in the code section; Starshine's code data-index carriers include `MemoryInit`, `DataDrop`, `ArrayNewData`, and `ArrayInitData`. | [`validate_bulk_memory_data_count_requirement(...)`](../../../src/validate/validate.mbt) prechecks `MemoryInit` and `DataDrop`, but not `ArrayNewData` / `ArrayInitData`; the latter still validate selected `DataIdx` during instruction typechecking. | [`data-count-and-code-data-indices.md`](data-count-and-code-data-indices.md), [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), [`../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md`](../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md). | WAST `memory.init` / `data.drop` fixtures can prove the current precheck; direct core/binary `array.new_data` / `array.init_data` without `DataCntSec` are gap evidence. |
| Memory64 `memory.fill` length | Official validation types `memory.fill` destination and length with the selected memory address type; the byte value remains `i32`. | [`typecheck_memory_fill(...)`](../../../src/validate/typecheck.mbt) resolves the selected memory address type for destination but still pops `len:i32`, so memory64-positive `i64` lengths are rejected locally. | [`memory-table-address-widths.md`](memory-table-address-widths.md), [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md), [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md). | Use direct core/binary memory64 fixtures for validator widening; do not cite current rejection as the portable rule. |
| Table64 ordinary table operations, `table.fill`, and indirect calls | Official validation uses the selected table address type for table get/set/size/grow, fill destination/length, copy positions, and indirect-call table indices; `table.init` keeps segment source/length as `i32`. | Starshine is aligned for `table.copy` and `table.init` destination widths, but ordinary table ops and indirect-call table indices still use `i32`; `table.fill` widens destination but keeps `len:i32`. | [`memory-table-address-widths.md`](memory-table-address-widths.md), [`../wast/table-instruction-authoring.md`](../wast/table-instruction-authoring.md), [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md), [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md). | For table64 work, test ordinary table ops, `table.fill`, `call_indirect`, and `return_call_indirect` separately; `table.copy` green evidence does not cover the other positions. |
| Constant-expression allow-list | Core 3.0 defines a current constant-instruction family and notes the list can grow; array constructors are included, and table-initializer `global.get` visibility is narrower than ordinary global initializers. | [`validate_const_instr(...)`](../../../src/validate/validate.mbt) is broader for several scalar/local proposal operations and narrower for official array constructors; environment order makes optional core table initializers see imported immutable globals but not later locals. | [`constant-expressions.md`](constant-expressions.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), [`../raw/wasm/2026-06-04-constant-expression-current-refresh.md`](../raw/wasm/2026-06-04-constant-expression-current-refresh.md). | Mark broader accepted forms as Starshine-local unless the feature-status page says otherwise; mark array-constructor initializer rejection as local gap evidence. |
| Structured `name` section and Extended-Name-Section-facing maps | Core custom sections are not ordinary semantic validation blockers, and current official Core 3.0 name subsections are narrower than Starshine's structured local metadata surface. The active Phase-2 Extended Name Section proposal covers label/table/memory/global/elem/data name maps, but it is not finished/Core evidence yet. | Starshine rejects raw `name` custom sections in `custom_secs`, validates structured official maps, and also validates proposal-facing/local label/table/memory/global/elem/data maps against index spaces. | [`../wasm-extended-name-section-boundary.md`](../wasm-extended-name-section-boundary.md), [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md), [`module-validation-phases.md`](module-validation-phases.md), [`../wast/identifier-name-and-annotation-authoring.md`](../wast/identifier-name-and-annotation-authoring.md), [`../raw/wasm/2026-06-05-extended-name-section-boundary-refresh.md`](../raw/wasm/2026-06-05-extended-name-section-boundary-refresh.md). | Treat name-map failures as Starshine metadata validation behavior, not Core semantic invalidity. Passes that remap indices must repair or clear the affected maps before claiming valid output. |
| Import/export matching and shared-memory flags | Core matching covers external-type kind, limit/address-type containment, reference types, globals, tags, and function types; current Core memory matching does not include Starshine's local shared flag. | [`validate_importsec(...)`](../../../src/validate/validate.mbt) validates declarations only; [`Match for ExternType`](../../../src/validate/match.mbt) is reusable for future host matching and currently includes shared-flag equality for memory types. | [`import-export-and-external-type-matching.md`](import-export-and-external-type-matching.md), [`resource-sections-and-limits.md`](resource-sections-and-limits.md), [`../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md`](../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md). | Do not report static `assert_unlinkable` success as proof of host import matching; keep shared-memory matching claims labeled Starshine-local. |
| `StringRefsSec`, string instructions, and JS string builtins | Stable Core WebAssembly 3.0 does not include the reference-typed string proposal; the active proposal defines a draft section id `14` and string instruction families. JS String Builtins is a separate finished Core-3.0 + JS API feature for host builtin imports and compile options. | Starshine mirrors a supported stringref subset: `StringRefsSec`, `string.const`, selected array-backed string constructors/encoders, validator/generator support, and local/proposal binary shapes. The Node wasm-gc runtime opts into `builtins: ["js-string"]`, but current Starshine validation does not model JS host import resolution or the `importedStringConstants` option. | [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md), [`../wasm-js-string-builtins-boundary.md`](../wasm-js-string-builtins-boundary.md), [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md), [`../raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md`](../raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md), [`../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`](../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md). | Treat local `stringref` / `StringRefsSec` fixtures as proposal/local evidence, and treat JS builtin imports / imported constants as host/JS API evidence. Do not use one as proof of the other. |

## Things This Ledger Does Not Mean

- **A parser gap is not automatically a validator gap.** Many official instruction forms are core/binary/generator-visible but not yet high-level WAST-authored. Route those through the WAST authoring pages.
- **Validation success is not runtime equivalence.** Static validation does not prove host import matching, execution results, traps, or optimization parity. Use [`runtime-trap-semantics.md`](runtime-trap-semantics.md), [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md), and pass-specific Binaryen compare pages for those layers.
- **A local extension is not a bug by default.** Some rows are deliberate Starshine policy or proposal tracking. The fix might be documentation, feature gating, or preserving the local contract—not necessarily changing code.
- **A local gap is not a portable positive.** If Starshine currently accepts a shape only because a precheck is missing, record that as gap evidence and add a focused failing test before implementation work.

## Maintenance Checklist

When one of these rows changes:

1. Update the focused owner page with the new contract and tests.
2. Update this ledger row from `gap` / `local extension` / `stricter policy` to the new status.
3. Update [`module-validation-phases.md`](module-validation-phases.md) if phase order, diagnostics, or the local-policy table changes.
4. Update invalid-fuzzer stable ids, expected diagnostic families, or generator feature gates if the user-visible behavior changes.
5. Update [`../index.md`](../index.md) and append [`../log.md`](../log.md).
6. If the change came from an official-source refresh or a new primary-source read, add or refresh the appropriate raw source bridge under [`../raw/`](../raw/).

## Sources

- Source bridge for this ledger: [`../raw/validation/2026-06-04-local-spec-divergence-ledger-source-bridge.md`](../raw/validation/2026-06-04-local-spec-divergence-ledger-source-bridge.md)
- Core validator phase map: [`module-validation-phases.md`](module-validation-phases.md)
- Focused current-source refreshes: [`../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md`](../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md), [`../raw/wasm/2026-06-04-exception-tag-current-refresh.md`](../raw/wasm/2026-06-04-exception-tag-current-refresh.md), [`../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`](../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md), [`../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md`](../raw/wasm/2026-06-04-data-count-code-data-index-recheck.md), [`../raw/wasm/2026-06-04-constant-expression-current-refresh.md`](../raw/wasm/2026-06-04-constant-expression-current-refresh.md), [`../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md`](../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md), [`../raw/wasm/2026-06-05-extended-name-section-boundary-refresh.md`](../raw/wasm/2026-06-05-extended-name-section-boundary-refresh.md), [`../raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md`](../raw/wasm/2026-06-05-js-string-builtins-boundary-refresh.md), [`../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md`](../raw/wasm/2026-06-04-stringref-proposal-current-refresh.md)
- Starshine validator sources: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt), [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt)
