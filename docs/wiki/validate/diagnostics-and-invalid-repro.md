---
kind: concept
status: supported
last_reviewed: 2026-05-24
sources:
  - ../raw/wasm/2026-05-19-validation-diagnostics-and-invalid-repro-sources.md
  - ../raw/wasm/2026-05-20-start-section-validation-sources.md
  - ../raw/wasm/2026-05-20-resource-section-validation-refresh.md
  - ../raw/wasm/2026-05-13-module-validation-phase-sources.md
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
  - ../../../src/validate/gen_invalid.mbt
  - ../../../src/validate/gen_invalid_tests.mbt
  - ../../../src/fuzz/invalid_binary.mbt
  - ../../../src/fuzz/invalid_text.mbt
  - ../../../src/fuzz/invalid_repro.mbt
  - ../../../src/fuzz/invalid_repro_wbtest.mbt
  - ../../../src/fuzz/main.mbt
related:
  - ./module-validation-phases.md
  - ./resource-sections-and-limits.md
  - ./import-export-and-external-type-matching.md
  - ./start-section.md
  - ./fuzz-hardening.md
  - ./ref-func-declarations.md
  - ../tooling/fuzz-runner.md
  - ../tooling/node-package-surface.md
  - ../wast/static-assertion-harness.md
---

# Validation Diagnostics And Invalid Repros

## Overview

Starshine's validator has two related but separate contracts:

1. **Semantic validation:** decide whether a WebAssembly module is valid under the official context-and-stack validation model.
2. **Diagnostic and repro surface:** explain where a rejection belongs, preserve enough metadata to replay it, and keep invalid-fuzz failures stable as the validator grows.

The official WebAssembly validation sources checked on 2026-05-19 define the semantic rules but do not prescribe a diagnostic taxonomy. Starshine's taxonomy is therefore local and repository-owned: [`ValidationIssue`](../../../src/validate/validate.mbt#L13-L29) names the public issue variants, [`ValidationDiagnostic`](../../../src/validate/validate.mbt#L32-L43) pairs an issue with an optional absolute `FuncIdx`, and [`validation_issue_family(...)`](../../../src/validate/invalid_fuzzer.mbt#L21-L41) maps those issues to stable invalid-fuzz families. The primary-source and local-code manifest for this page is [`../raw/wasm/2026-05-19-validation-diagnostics-and-invalid-repro-sources.md`](../raw/wasm/2026-05-19-validation-diagnostics-and-invalid-repro-sources.md).

Use this page as the focused companion to [`module-validation-phases.md`](module-validation-phases.md). The phase page answers "what does the validator check, and in what order?" This page answers "what user-visible family should the failure report, and how do I produce a stable repro?"

## Beginner Model

A validation failure should be described with three facts:

```text
stage:          decode-rejected | parse-or-lower-rejected | validate-rejected | valid-before-link
family:         type | import | function | table | memory | tag | global | element |
                data | datacount | start | export | code | name | function-body
function index: optional absolute FuncIdx when the failure belongs to one body/start target
```

Examples:

- A malformed binary section header is `decode-rejected` and has no validator family because the module never reached `validate_module(...)`.
- A body that leaves the wrong stack result is `validate-rejected` with family `function-body` and an absolute `FuncIdx` when validation knows which body failed.
- A `FuncSec` / `CodeSec` length mismatch is `validate-rejected` with family `code`, not `function-body`, because the validator cannot assign the failure to one body.
- A missing data-count section for `memory.init` is `validate-rejected` with family `function-body`, because the rejected use is inside a specific body even though the root cause is a cross-section requirement.
- An `assert_unlinkable` WAST seed that validates locally but needs a linker/runtime failure is `valid-before-link`; see [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md).

## Diagnostic Shape In Code

| Layer | Starshine type / function | Contract |
| --- | --- | --- |
| Public validation error | [`ValidationError::Validation(ValidationDiagnostic)`](../../../src/validate/validate.mbt#L85-L87) | All module-validation failures are wrapped in one suberror carrying the structured diagnostic. |
| Diagnostic payload | [`ValidationDiagnostic`](../../../src/validate/validate.mbt#L32-L43) | Stores one issue plus optional `func_idx`. The `Show` instance prints `func[n]: ...` only when present. |
| Message extraction | [`validation_issue_message(...)`](../../../src/validate/validate.mbt#L46-L64), [`validation_error_message(...)`](../../../src/validate/validate.mbt#L104-L108) | The message is payload text from the issue variant; do not parse it to recover the family. |
| Function index extraction | [`validation_error_func_idx(...)`](../../../src/validate/validate.mbt#L111-L115) | Returns the absolute imported-prefix `FuncIdx` when the diagnostic owns one. |
| Family mapping | [`validation_issue_family(...)`](../../../src/validate/invalid_fuzzer.mbt#L21-L41) | Converts issue variants into the stable family enum used by invalid fuzzing and repro metadata. |
| Repro family label | [`invalid_fuzz_family_label(...)`](../../../src/fuzz/invalid_repro.mbt#L202-L220) | Converts the family enum into compact metadata labels such as `function-body` and `datacount`. |

Do not classify failures by message substrings. The issue variant and family mapping are the durable API. Messages can become clearer without changing the expected fuzz family.

## Family Map

| `ValidationIssue` variant | Family label | Typical owner phase | Notes |
| --- | --- | --- | --- |
| `TypeSection` | `type` | `typesec` | Recursive type, subtype, descriptor, and type-index rules. |
| `ImportSection` | `import` | `importsec` | Import type/reference errors before local definition suffixes are added; detailed import declaration versus host matching rules live in [`import-export-and-external-type-matching.md`](import-export-and-external-type-matching.md). |
| `FunctionSection` | `function` | `funcsec` | Defined-function type-index declarations, not body typing. |
| `TableSection` | `table` | `tablesec` | Table types and table initializer expressions; see [`resource-sections-and-limits.md`](resource-sections-and-limits.md). |
| `MemorySection` | `memory` | `memsec` | Memory limit, memory64, and shared-memory maximum rules; see [`resource-sections-and-limits.md`](resource-sections-and-limits.md). |
| `TagSection` | `tag` | `tagsec` | Exception tag type and result-shape rules; see [`resource-sections-and-limits.md`](resource-sections-and-limits.md) plus [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md). |
| `GlobalSection` | `global` | `globalsec`, `ref_func_declarations` for global initializers | Global types and constant initializers; see [`resource-sections-and-limits.md`](resource-sections-and-limits.md) and [`constant-expressions.md`](constant-expressions.md). |
| `ElementSection` | `element` | `elemsec`, `ref_func_declarations` for element expressions | Element modes, payload typing, table targets, offsets, and declaration expressions; see [`resource-sections-and-limits.md`](resource-sections-and-limits.md). |
| `DataSection` | `data` | `datasec` | Data modes, memory targets, and offsets; see [`resource-sections-and-limits.md`](resource-sections-and-limits.md). |
| `DataCountSection` | `datacount` | `datacnt` | Data-count equality and illegal standalone data-count surfaces; body-level data-count requirements remain `FunctionBody`, as explained in [`resource-sections-and-limits.md`](resource-sections-and-limits.md). |
| `StartSection` | `start` | `startsec` | Start target resolution and empty parameter/result signature; see [`start-section.md`](start-section.md). May carry `func_idx`. |
| `ExportSection` | `export` | `exportsec` | Export target bounds and duplicate export names; see [`import-export-and-external-type-matching.md`](import-export-and-external-type-matching.md) for the focused export-index and duplicate-name contract. |
| `CodeSection` | `code` | `codesec` structural gate | Missing or mismatched `FuncSec` / `CodeSec`, missing function type for a body ordinal, or other section-level code problems. |
| `NameSection` | `name` | `namesec` | Starshine validates structured name maps even though custom sections are not ordinary core semantic blockers. |
| `FunctionBody` | `function-body` | `datacnt_requirement`, `ref_func_declarations` body scan, body typechecking | Anything assigned to one function body: stack typing, local use, missing data-count use, undeclared body `ref.func`, etc. |

The table intentionally mirrors [`module-validation-phases.md`](module-validation-phases.md#starshine-phase-order) rather than replacing it. When phase order changes, update both pages.

## Body Diagnostics Use Absolute Function Indices

When imports precede defined functions, code-body ordinal `0` is not necessarily `FuncIdx(0)`. Starshine reports body diagnostics in the absolute function index space used by calls, exports, elements, and `ref.func`. The code-section validator maps body ordinals through the imported-prefix helpers before wrapping body errors as [`ValidationIssue::FunctionBody`](../../../src/validate/validate.mbt#L1532-L1536). The same rule appears in the data-count requirement scan, which reports `FunctionBody("data count section required")` with the computed function index when a body uses `memory.init` or `data.drop` without `DataCntSec` ([`validate.mbt`](../../../src/validate/validate.mbt#L2138-L2157)).

This is why invalid-fuzz expectations are family-based, not message-only: the same semantic rule can be discovered in a section-level phase or a body-level phase depending on where the offending use lives.

## Invalid-AST Strategy Contract

The AST-invalid lane is the strictest diagnostic-family oracle because it starts from a valid `Module`, applies a deterministic semantic mutation, and expects one validator family.

Key surfaces:

- [`ValidateInvalidAstStrategySpec`](../../../src/validate/invalid_fuzzer.mbt#L116-L125) stores `stable_id`, default `variant_id`, display name, source `layer`, `expected_family`, exact `expected_issue_kind`, and `required_in_smoke`.
- [`validate_invalid_ast_registry()`](../../../src/validate/invalid_fuzzer.mbt#L190-L501) is the checked-in registry of stable ids such as `duplicate-export-name`, `missing-datacount`, `undeclared-ref-func`, `invalid-func-type-index`, `datacount-mismatch-too-small`, `datacount-without-data-sec`, and function-body stack typing cases such as `invalid-function-body-table-grow-delta-type`, `invalid-function-body-table-fill-dest-type`, `invalid-function-body-table-fill-length-type`, `invalid-function-body-table-copy-length-type`, `invalid-function-body-table-copy-source-type`, `invalid-function-body-table-copy-dest-type`, `invalid-function-body-table-init-length-type`, `invalid-function-body-table-init-source-type`, `invalid-function-body-table-init-dest-type`, `invalid-function-body-data-drop-index`, `invalid-function-body-elem-drop-index`, `invalid-function-body-table-set-index-type`, `invalid-function-body-call-indirect-index-type`, `invalid-function-body-return-call-indirect-index-type`, `invalid-function-body-call-ref-type`, `invalid-function-body-return-call-ref-type`, `invalid-function-body-ref-cast-input-type`, `invalid-function-body-ref-test-input-type`, `invalid-function-body-ref-test-desc-input-type`, `invalid-function-body-ref-cast-desc-eq-input-type`, `invalid-function-body-ref-get-desc-input-type`, `invalid-function-body-ref-eq-input-type`, `invalid-function-body-array-len-input-type`, `invalid-function-body-array-get-input-type`, `invalid-function-body-array-set-input-type`, `invalid-function-body-array-set-value-type`, `invalid-function-body-array-fill-input-type`, `invalid-function-body-array-fill-value-type`, `invalid-function-body-array-fill-length-type`, `invalid-function-body-array-copy-input-type`, `invalid-function-body-array-copy-source-input-type`, `invalid-function-body-array-copy-length-type`, `invalid-function-body-array-init-data-input-type`, `invalid-function-body-array-init-data-dest-type`, `invalid-function-body-array-init-data-source-type`, `invalid-function-body-array-init-data-length-type`, `invalid-function-body-array-init-elem-input-type`, `invalid-function-body-array-init-elem-dest-type`, `invalid-function-body-array-init-elem-source-type`, `invalid-function-body-array-init-elem-length-type`, `invalid-function-body-array-new-value-type`, `invalid-function-body-array-new-length-type`, `invalid-function-body-array-new-default-length-type`, `invalid-function-body-array-new-fixed-value-type`, `invalid-function-body-array-new-data-source-type`, `invalid-function-body-array-new-data-length-type`, `invalid-function-body-array-new-elem-source-type`, `invalid-function-body-array-new-elem-length-type`, `invalid-function-body-struct-new-value-type`, `invalid-function-body-struct-get-input-type`, `invalid-function-body-struct-set-input-type`, `invalid-function-body-struct-set-value-type`, `invalid-function-body-struct-get-field-index`, `invalid-function-body-struct-set-field-index`, `invalid-function-body-struct-set-immutable-field`, `invalid-function-body-struct-get-signed-field-type`, `invalid-function-body-br-on-cast-input-type`, and `invalid-function-body-br-on-cast-fail-input-type`.
- [`ValidateInvalidAstMutation`](../../../src/validate/invalid_fuzzer.mbt#L136-L141) records whether the strategy was applicable, the expected family, and the mutated module.
- [`ValidateInvalidAstStrategyStats`](../../../src/validate/invalid_fuzzer.mbt#L144-L160) separately counts attempted, applicable, mutated, rejected, rejected-for-expected-family, default variant attempts/applicability/mutations/rejections, and exact issue-kind matches.

A new validator family is not done when the validator rejects. It is done when at least one stable invalid-AST strategy can exercise the family, the expected family/exact issue kind are correct, and smoke/CI/stress accounting can tell whether the mutation and its variant actually ran. Binary-invalid, inline-text-invalid, and spec-seed stats now carry the same default `variant_id` counters so future non-default variants can be added without renaming existing stable ids.

## `gen_invalid` Seed And Mutation Flow

[`src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt) is the public AST-invalid generation API. It should be read as a reproducibility layer, not just a fuzzer helper:

1. Choose a strategy by `ValidateInvalidAstStrategyId` or stable id.
2. Choose a seed profile: natural, coverage-forced, small natural, small coverage-forced, repro, or minimal.
3. Optionally widen the valid-generator config for strategy prerequisites, such as memory/data availability for `missing-datacount`.
4. Generate or build a valid seed module.
5. Apply the invalid mutation.
6. Validate that the mutated module rejects with the strategy's expected family.

The tests in [`src/validate/gen_invalid_tests.mbt`](../../../src/validate/gen_invalid_tests.mbt) lock the important cases: valid seed before mutation, expected family after mutation, minimal seeds, seed-profile naming, prereq widening, representative type/import/function/element/tag/datacount/export/start families, and focused function-body operand-stack mismatches for call, branch, exception, memory, table, bulk-table, local, global, return, reference-cast, reference-test, and reference-branch cast instructions.

Use `repro_seed(...)` for persisted reports by default. It keeps artifacts compact while preserving the semantic seed profile in report metadata.

## Stage-Aware Repro Reports

The shared invalid-repro layer in [`src/fuzz/invalid_repro.mbt`](../../../src/fuzz/invalid_repro.mbt) joins four source kinds:

| Source kind | Suite | Expected stages | Family? | Reduction shape |
| --- | --- | --- | --- | --- |
| AST invalid | `validate-invalid-ast` | `validate-rejected` | Yes | Minimal invalid module. |
| Binary invalid | `validate-invalid-binary` | `decode-rejected` or `validate-rejected` | Only for validation-rejected cases | Minimal corrupted wasm bytes. |
| Inline text invalid | `validate-invalid-text` | `parse-or-lower-rejected`, `validate-rejected`, or `valid-before-link` | Only for validation-rejected cases | Canonical inline assertion source. |
| Spec seed | `validate-invalid-spec-seed` | `parse-or-lower-rejected`, `validate-rejected`, or `valid-before-link` | Only for validation-rejected cases | Extracted raw assertion S-expression from the spec fixture. |

[`InvalidFuzzFailureReport`](../../../src/fuzz/invalid_repro.mbt#L74-L99) records the suite, profile, seed, attempt, strategy stable id, source kind, expected/actual stage, expected/actual family, seed profile/mode/prereq metadata for generated cases, source path, original artifacts, and reduced artifacts. [`build_invalid_fuzz_failure_report_by_suite_and_stable_id(...)`](../../../src/fuzz/invalid_repro.mbt#L712-L753) dispatches by full suite name or short aliases (`ast`, `binary`, `text`, `spec-seed`). [`persist_invalid_fuzz_failure_report(...)`](../../../src/fuzz/invalid_repro.mbt#L394-L462) writes deterministic metadata plus artifacts, and [`shrink_invalid_fuzz_failure_report(...)`](../../../src/fuzz/invalid_repro.mbt#L1082-L1127) adds replayable reduced artifacts.

The direct Moon-owned command is documented in [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md):

```text
moon run src/fuzz -- --emit-invalid-repro \
  --suite <suite|ast|binary|text|spec-seed> \
  --strategy <stable-id> \
  --seed <uint64> \
  --attempt <n> \
  --out-dir <dir> \
  [--profile <name>]
```

As of this review, `bun fuzz run` forwards ordinary fuzz runs and `--emit-gen-valid-batch`, but not `--emit-invalid-repro`.

## Maintenance Checklist

When changing validator diagnostics or invalid repros:

1. **Classify the semantic owner.** If the failure belongs to one body, use `FunctionBody` with an absolute `FuncIdx`; if it blocks code-section structure before a body is selected, use `CodeSection`.
2. **Update family mapping.** Add or reclassify `validation_issue_family(...)` at the same time as `ValidationIssue` changes.
3. **Add a deterministic invalid strategy.** If a rule is user-visible, add or update a stable id in `validate_invalid_ast_registry()` and lock `expected_family`.
4. **Preserve stable ids.** Rename only when the old meaning is truly gone; otherwise keep aliases or mark supersession in docs and log.
5. **Update repro builders.** If a new source kind, stage, or artifact layout appears, update `InvalidFuzzFailureReport`, persistence/parsing tests, shrinking tests, and [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md).
6. **Update Node/API docs.** [`../tooling/node-package-surface.md`](../tooling/node-package-surface.md) still marks `validationIssueFamily(...)` and invalid-repro helpers as missing high-value Node surfaces.
7. **Keep phase and family docs in sync.** Update [`module-validation-phases.md`](module-validation-phases.md), [`resource-sections-and-limits.md`](resource-sections-and-limits.md) for resource/segment/limit families, [`fuzz-hardening.md`](fuzz-hardening.md), this page, [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md) when floors/strategy ledgers change, and [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md) when text/spec stages change.

## Sources

- Source manifest: [`../raw/wasm/2026-05-19-validation-diagnostics-and-invalid-repro-sources.md`](../raw/wasm/2026-05-19-validation-diagnostics-and-invalid-repro-sources.md)
- Validator phase map: [`./module-validation-phases.md`](module-validation-phases.md)
- Diagnostic implementation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt)
- AST invalid generation: [`../../../src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt), [`../../../src/validate/gen_invalid_tests.mbt`](../../../src/validate/gen_invalid_tests.mbt)
- Binary/text/spec invalid and repro surfaces: [`../../../src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt), [`../../../src/fuzz/invalid_text.mbt`](../../../src/fuzz/invalid_text.mbt), [`../../../src/fuzz/invalid_repro.mbt`](../../../src/fuzz/invalid_repro.mbt), [`../../../src/fuzz/invalid_repro_wbtest.mbt`](../../../src/fuzz/invalid_repro_wbtest.mbt), [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt)
- Related pages: [`./fuzz-hardening.md`](fuzz-hardening.md), [`./ref-func-declarations.md`](ref-func-declarations.md), [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md), [`../tooling/node-package-surface.md`](../tooling/node-package-surface.md), [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md)
