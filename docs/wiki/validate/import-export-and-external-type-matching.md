---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md
  - ../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md
  - ../raw/wasm/2026-06-04-exception-tag-current-refresh.md
  - ../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md
  - ../raw/wasm/2026-05-13-module-validation-phase-sources.md
  - ../raw/wasm/2026-05-13-function-import-export-section-sources.md
  - ../raw/wasm/2026-05-19-wast-resource-declaration-sources.md
  - ../raw/wasm/2026-05-20-resource-section-validation-refresh.md
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/match.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
  - ../../../src/validate/gen_invalid_tests.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/wast/lower_to_lib.mbt
related:
  - ./module-validation-phases.md
  - ./diagnostics-and-invalid-repro.md
  - ./start-section.md
  - ./ref-func-declarations.md
  - ./resource-sections-and-limits.md
  - ../binary/function-import-export-and-code-sections.md
  - ../binary/type-table-memory-global-tag-sections.md
  - ../binary/custom-and-name-sections.md
  - ../wast/function-call-and-module-authoring.md
  - ../wast/resource-declaration-authoring.md
  - ../wast/static-assertion-harness.md
  - ../wasm-custom-page-sizes-boundary.md
  - ../fuzzing/generator-coverage-ledger.md
---

# Import, Export, And External-Type Matching

## Overview

Use this page when changing or debugging the boundary where a module names values outside itself or exposes values to the host:

- [`ImportSec`](../../../src/lib/types.mbt) entries declare an external module name, field name, and [`ExternType`](../../../src/lib/types.mbt).
- [`ExportSec`](../../../src/lib/types.mbt) entries declare a public name and an [`ExternIdx`](../../../src/lib/types.mbt) that points into one of Starshine's function, table, memory, global, or tag index spaces.
- [`src/validate/match.mbt`](../../../src/validate/match.mbt) implements the reusable WebAssembly matching relation for external types and their component limits, globals, memories, tables, tags, and functions.

The current focused source manifest is [`../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md`](../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md). It rechecks the Core 3.0 matching, type-validity, module-validation, runtime-instantiation, and abstract module pages against Starshine's validator, matching helper, invalid-fuzzer families, binary codec, core model, and WAST lowering. The older 2026-05-20 manifest [`../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md`](../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md) remains useful provenance. The 2026-06-04 exception refresh [`../raw/wasm/2026-06-04-exception-tag-current-refresh.md`](../raw/wasm/2026-06-04-exception-tag-current-refresh.md) updates the tag-import nuance: Starshine still rejects resultful tag imports locally, but current Core 3.0's tagtype validity is broader and leaves the empty-result requirement to exception instruction use sites.

Keep one distinction visible: **module validation is not host instantiation**. Starshine validates that import declarations are well typed and that exports point at real module items. A future linker or embedding API still needs to match host-provided external values against those import declarations.

## Beginner Mental Model

A module can be read as saying:

```wat
(module
  (import "env" "host" (func $host (param i32))) ;; declare what must be supplied
  (memory $mem 1 3)                               ;; define a local resource
  (export "mem" (memory $mem))                    ;; expose a real index
  (export "call_host" (func $host)))              ;; exports may point at imports
```

The import does not run or link anything during Starshine module validation. It only adds one function entry to the module's function index space. Because imports occupy the prefix of each same-kind index space, `$host` is `FuncIdx(0)` in this example. Export validation then checks that `FuncIdx(0)` and the memory index both resolve and that no two exports reuse the same public name.

A separate instantiation/linking step would ask: "Does the host actually provide `env.host`, and does that value match `(func (param i32))`?" The compatibility rules for that question are the matching relation documented below.

## Starshine Validation Flow

[`validate_module_impl(...)`](../../../src/validate/validate.mbt) routes import/export boundary checks through these phases:

| Phase | Starshine behavior | Evidence |
| --- | --- | --- |
| `importsec` | Validates each imported `ExternType`, then appends imported functions, tables, memories, globals, and tags to the same index spaces used by local definitions. Function imports also append the resolved function type and remember the source `TypeIdx` when available. | [`validate_importsec(...)`](../../../src/validate/validate.mbt), [`Validate for ExternType`](../../../src/validate/validate.mbt), [`Env`](../../../src/validate/env.mbt) |
| local definition sections | Append defined functions/tables/memories/globals/tags after the imported prefix. | [`module-validation-phases.md`](module-validation-phases.md) |
| `startsec` | Checks that the optional start target resolves and has no parameters or results. Imported starts are legal when the imported function has that empty signature. | [`start-section.md`](start-section.md) |
| `exportsec` | Validates each `ExternIdx` against the completed index spaces, then rejects duplicate export names. | [`validate_exportsec_unique(...)`](../../../src/validate/validate.mbt) |
| later phases | `ref.func` declarations, code bodies, and name maps use the same imported-prefix index spaces. | [`ref-func-declarations.md`](ref-func-declarations.md), [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md) |

The user-visible diagnostic split is stable: invalid import declarations report `ImportSection`, while invalid export indices or duplicate export names report `ExportSection`. The invalid-fuzzer registry keeps both families explicit in [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt): the duplicate-name strategy now uses a cross-kind function/memory duplicate with individually valid indices, while the export-index strategies include both ordinary out-of-range targets and a wrong-kind function-export case where index `0` exists in the table space but not the function space.

## What Counts As A Valid Import Declaration

An imported external type must be internally valid before it can extend an index space:

| Imported kind | Validation rule | Important edge case |
| --- | --- | --- |
| function | Type index must resolve to a function type. | A type index that exists but names a struct/array type is rejected for `FuncExternType`. |
| table | Reference type must validate; limits must be in range. | Current WAST declarations lower natural limits to i32 limits, but core/binary paths can represent i64 table limits; the shared table-limit contract lives in [`resource-sections-and-limits.md`](resource-sections-and-limits.md). |
| memory | Limits must be in range; shared memories require an explicit maximum. | Memory32 max is bounded to 65536 pages; memory64 uses the wider local core limit; the shared-memory maximum policy and limit-width caveats live in [`resource-sections-and-limits.md`](resource-sections-and-limits.md). |
| global | Value type must validate; mutability is carried for matching and runtime `global.set` checks. | Immutable imported globals can be read from constant expressions when they are already in the environment; see [`constant-expressions.md`](constant-expressions.md). |
| tag | Starshine requires the type index to resolve to a function type with empty results. Current Core 3.0 tagtype validity only requires a function-type expansion, while `throw` / `catch` / `catch_ref` use sites require empty results. | Tag imports extend the tag index space before local tags; resultful tag imports are local validator-gap evidence until Starshine deliberately widens this rule. |

Import module/name pairs are **not** de-duplicated by module validation. Multiple imports may use the same string pair if their section entries say so; whether a host environment can or should satisfy that shape is an embedding/linking concern.

## Export Validation Is Index And Name Validation

Exports are simpler than imports because the exported value already lives in the module. Starshine checks:

1. the exported kind selects the right index space;
2. the selected index is in range after imports and local definitions have been appended; and
3. the export name is unique across all exports, regardless of exported kind.

A same numeric index in a different namespace does not satisfy the selected export kind. For example, exporting `(func 0)` from a module that only defines table `0` is still an export-section error; the AST invalid lane locks this as `invalid-export-func-wrong-kind-index`.

For example, this is invalid because both exports use the same public name even though they target different functions:

```wat
(module
  (func $a)
  (func $b)
  (export "run" (func $a))
  (export "run" (func $b)))
```

This is also invalid if there is no memory index `1` after import and memory sections are built:

```wat
(module
  (memory 1)
  (export "bad" (memory 1)))
```

Exported imports are valid. A module can import a memory or function and then re-export it; the export target is just the absolute imported-prefix index.

## External-Type Matching Relation

The official WebAssembly model uses a matching relation to decide whether one external type is compatible with another. Starshine implements the local relation in [`src/validate/match.mbt`](../../../src/validate/match.mbt) as `Match::matches(left, right, env)`, read as "`left` can stand where `right` is expected." This relation is broader than export-index validation and is most useful for future host import matching, subtype-aware analysis, and pass safety checks.

| Type surface | Starshine matching rule | Why it matters |
| --- | --- | --- |
| `Limits` | Same limit width (`i32` with `i32`, `i64` with `i64`); actual minimum must be at least expected minimum; actual maximum must be no larger than expected maximum when expected is bounded. | A host memory/table with enough initial capacity and no too-large maximum can satisfy an import; section-level range validation remains centralized in [`resource-sections-and-limits.md`](resource-sections-and-limits.md). |
| `MemType` | Limits match by the same i32/i64 address-width family and the local `shared` flag is identical. | Core 3.0 memory matching is address-type-plus-limits; Starshine's `shared` Boolean is a local/proposal extension, so a shared-memory import cannot be satisfied by an unshared memory or the reverse. Current Starshine has no custom-page-size field to compare, so Custom Page Sizes remains future-port evidence routed through [`../wasm-custom-page-sizes-boundary.md`](../wasm-custom-page-sizes-boundary.md). Keep shared-memory maxima and shared-without-max invalid-byte fixtures on [`resource-sections-and-limits.md`](resource-sections-and-limits.md). |
| immutable `GlobalType` | Value type is covariant. | A `(global (ref eq))` can satisfy a `(global (ref any))`-style expectation when the reference type matches by subtype. |
| mutable `GlobalType` | Value type is invariant and mutability must match. | Mutable globals can be read and written, so allowing only one direction would be unsound. |
| `TableType` | Limits match and reference type matches both directions. | Starshine treats table element reference type as invariant even when heap types have subtyping. |
| `TagType` | Function type index compatibility must hold in both directions. | Exception tags must agree on their parameter payload shape. Results are already empty under current Starshine validation, but the current official tagtype rule is broader, so a future local widening would need to preserve empty-result checks at EH instruction validation. |
| function `ExternType` | Both type indices must resolve to function types; then type-index subtyping decides compatibility. | Function parameters are contravariant and results covariant through the underlying function subtype relation. |
| `ExternType` kind | Kinds must match. | A memory cannot satisfy a table import even if both have limits. |

This is a semantic relation, not a binary-byte comparison. Two type indices can be compatible because their referenced types participate in the same subtype hierarchy, while different external kinds never match. For memory/table limits, the relation is directional: read `Match::matches(actual, expected, env)` as the host or candidate value having at least the requested minimum and no maximum that exceeds a bounded expectation.

## Current Local Boundary

Starshine currently has no active public runtime linker page or complete host-import matching API in the wiki. Current Core 3.0 instantiation is a separate runtime phase: the embedding supplies a sequence of external addresses, and each address type is matched against the corresponding import external type. Therefore:

- do not cite `validate_module(...)` as proof that host imports were supplied;
- do cite `validate_importsec(...)` as proof that import declarations are internally valid and extend the local context;
- do cite `Match for ExternType` as the reusable compatibility relation for future linker/embedding work;
- when discussing shared memories, say explicitly that Starshine's shared-flag equality is local/proposal policy layered on top of the stable Core 3.0 memory matching relation;
- when discussing Custom Page Sizes, say explicitly that current Starshine cannot match page size because `MemType` has no page-size field; and
- if a new Node or CLI instantiation surface is added, document whether it uses `Match::matches(actual, expected, env)` exactly, how it reports the `(module, name)` import pair, and whether it adds host-specific policy.

### Static WAST `assert_unlinkable` Is Pre-Link Evidence

[`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md) deliberately keeps `assert_unlinkable` as a **pre-link** static assertion. In current Starshine, an `assert_unlinkable` command succeeds when the module compiles/lowers/decodes and then passes core validation; the result stage is `ValidBeforeLink`. That stage is useful because it proves the import declarations are internally valid and the module has reached the point where a host linker could try to satisfy them. It does **not** prove that a host value was supplied, that a `(module, name)` pair was found, or that `Match::matches(actual, expected, env)` accepted a supplied external value.

This matters for fuzzing names too. `validate-invalid-text` and `validate-invalid-spec-seed` can generate or replay `assert_unlinkable` fixtures with messages like "unknown import" or "incompatible import type", but current Starshine does not compare those diagnostic strings to a real linker failure. Treat those cases as static stage-classification evidence until a dedicated linker/embedding API exists. A future host-linking surface should reuse this page's matching relation, define the host environment shape explicitly, and then update the static harness page to say whether `assert_unlinkable` remains pre-link-only or gains real import-resolution coverage.

The inactive compatibility directories called out in [`../../../AGENTS.md`](../../../AGENTS.md) (`src/node_api/`, `src/optimization/`, `src/transformer/`) should not be used as evidence for an active linker contract unless they are rebuilt and re-documented.

## Pass, Generator, And Fixture Checklist

When a pass, generator, or fixture changes import/export structure:

1. Preserve imported-prefix ordering per kind. A removed function import shifts every later `FuncIdx`; the same applies to tables, memories, globals, and tags.
2. Remap all `ExternIdx` export targets after deleting, merging, or reordering module items.
3. Re-check duplicate export names after adding inline exports or creating helper exports.
4. Keep function signatures, start target, `ref.func` declarations, element payloads, and name maps consistent with changed function indices.
5. Keep table/memory/global/tag names and structured name maps aligned; clear stale raw name payloads if indices changed.
6. For import-declaration fuzzing, expect `ImportSection` diagnostics for invalid imported function/tag type indices or invalid external type shapes.
7. For export fuzzing, expect `ExportSection` diagnostics for duplicate names and invalid function/table/memory/global/tag export indices.
8. For future instantiation tests, add host-value matching cases separately from ordinary module validation.
9. For `assert_unlinkable` fixtures, keep the stage distinction explicit: today they prove `ValidBeforeLink`, not host-resolution or diagnostic-text parity; update [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md) if that changes.
10. When changing table or memory limit validation, update [`resource-sections-and-limits.md`](resource-sections-and-limits.md) first, then keep this page focused on the import/export and host-matching boundary.

## Sources

- Current exception/tag-result refresh: [`../raw/wasm/2026-06-04-exception-tag-current-refresh.md`](../raw/wasm/2026-06-04-exception-tag-current-refresh.md)
- Current source manifest: [`../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md`](../raw/wasm/2026-06-04-import-export-external-type-matching-current-refresh.md)
- Previous source manifest: [`../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md`](../raw/wasm/2026-05-20-external-type-matching-import-export-validation.md)
- Module-validation phase snapshot: [`../raw/wasm/2026-05-13-module-validation-phase-sources.md`](../raw/wasm/2026-05-13-module-validation-phase-sources.md)
- Function/import/export snapshot: [`../raw/wasm/2026-05-13-function-import-export-section-sources.md`](../raw/wasm/2026-05-13-function-import-export-section-sources.md)
- WAST resource declaration snapshot: [`../raw/wasm/2026-05-19-wast-resource-declaration-sources.md`](../raw/wasm/2026-05-19-wast-resource-declaration-sources.md)
- Resource-section validation snapshot: [`../raw/wasm/2026-05-20-resource-section-validation-refresh.md`](../raw/wasm/2026-05-20-resource-section-validation-refresh.md), [`resource-sections-and-limits.md`](resource-sections-and-limits.md)
- Validation implementation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/match.mbt`](../../../src/validate/match.mbt), [`../../../src/validate/env.mbt`](../../../src/validate/env.mbt)
- Invalid-fuzzer evidence: [`../../../src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), [`../../../src/validate/gen_invalid_tests.mbt`](../../../src/validate/gen_invalid_tests.mbt)
- Core/binary/WAST surfaces: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt)
- Related pages: [`module-validation-phases.md`](module-validation-phases.md), [`diagnostics-and-invalid-repro.md`](diagnostics-and-invalid-repro.md), [`resource-sections-and-limits.md`](resource-sections-and-limits.md), [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md), [`../binary/type-table-memory-global-tag-sections.md`](../binary/type-table-memory-global-tag-sections.md), [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md), [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md), [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md)
