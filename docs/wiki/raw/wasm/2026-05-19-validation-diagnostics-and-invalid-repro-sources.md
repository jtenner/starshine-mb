# WebAssembly Validation Diagnostics And Invalid-Repro Source Snapshot

- Capture date: 2026-05-19
- Source family: WebAssembly Core Specification 3.0 draft plus current Starshine validator / invalid-fuzz evidence
- Primary sources checked:
  - WebAssembly Core Specification, `Validation` index — WebAssembly 3.0 (2026-05-14): <https://webassembly.github.io/spec/core/valid/index.html>
  - WebAssembly Core Specification, `Validation / Modules` — WebAssembly 3.0 (2026-05-14): <https://webassembly.github.io/spec/core/valid/modules.html>
  - WebAssembly Core Specification, `Validation / Instructions` — WebAssembly 3.0 (2026-05-14): <https://webassembly.github.io/spec/core/valid/instructions.html>
  - WebAssembly Core Specification, `Appendix / Validation Algorithm` — WebAssembly 3.0 (2026-05-14): <https://webassembly.github.io/spec/core/appendix/algorithm.html>
  - WebAssembly Core Specification, `Text Format / Modules` — WebAssembly 3.0 (2026-05-14): <https://webassembly.github.io/spec/core/text/modules.html>
- Repository evidence checked:
  - `src/validate/validate.mbt`
  - `src/validate/invalid_fuzzer.mbt`
  - `src/validate/gen_invalid.mbt`
  - `src/validate/gen_invalid_tests.mbt`
  - `src/fuzz/invalid_binary.mbt`
  - `src/fuzz/invalid_text.mbt`
  - `src/fuzz/invalid_repro.mbt`
  - `src/fuzz/invalid_repro_wbtest.mbt`
  - `src/fuzz/main.mbt`
  - `docs/wiki/validate/module-validation-phases.md`
  - `docs/wiki/validate/fuzz-hardening.md`
  - `docs/wiki/tooling/fuzz-runner.md`
  - `docs/wiki/tooling/node-package-surface.md`

## Durable takeaways

- The official WebAssembly validation spec is semantic and context-driven. It defines whether modules, module fields, and instructions are valid, but it does not prescribe an implementation's user-facing diagnostic taxonomy.
- The official module validation source builds a context containing types, functions, tables, memories, globals, tags, elements, data segments, returns, and declared function references. Starshine's phase-level diagnostics are a local, implementation-facing projection of those semantic dependencies.
- The official validation algorithm appendix emphasizes a stack-based instruction checker with value, control, and initialization stacks plus an unreachable-code rule. Starshine's `FunctionBody` diagnostics are the local bucket for failures discovered inside that body/typechecking context.
- The official `ref.func` rule still requires both an existing function index and membership in the validation context's `refs` set. The module rule still builds `refs` from function-index occurrences in globals, memories, tables, element segments, optional start, and exports. Starshine keeps the already-documented local divergence that `start_sec` alone is not treated as a declaration source.
- Starshine's public validator error shape is `ValidationError::Validation(ValidationDiagnostic)`. The diagnostic stores a `ValidationIssue` variant and optional absolute `FuncIdx`. The optional index is used for function-body diagnostics and some start-section diagnostics; its value is in the full imported-prefix function index space, not the defined-body ordinal.
- Starshine maps the same issue variants to stable invalid-fuzz `ValidationIssueFamily` values in `src/validate/invalid_fuzzer.mbt`: type, import, function, table, memory, tag, global, element, data, datacount, start, export, code, name, and function-body.
- The AST-invalid registry has stable ids and expected families for deterministic mutations. Current repository tests and docs say the registry has at least one deterministic strategy for every current family.
- The `gen_invalid` API starts from a valid seed module, optionally widens seed prerequisites, applies one invalid mutation, and records the expected diagnostic family. Named seed profiles (`natural`, `coverage-forced`, `small-*`, `repro`, `minimal`) are part of the reproducibility contract.
- The invalid-repro layer unifies AST, binary, inline-text, and spec-seed invalid cases under one report shape. Reports record source kind, suite/profile/seed/attempt, strategy stable id, expected/actual stage, expected/actual diagnostic family when applicable, seed profile/mode/prereq metadata for generated AST/binary cases, original artifacts, and reduced artifacts.
- Stage is separate from family: binary malformed cases can fail during decode with no validator family, text/spec malformed cases can fail during parse/lower, validation cases should report `validate-rejected` plus a family, and unlinkable text/spec cases should stop at `valid-before-link`.
- The Moon-owned `src/fuzz` CLI exposes invalid repro persistence through `--emit-invalid-repro`; the Bun wrapper currently does not. This is a Starshine runner contract, not an upstream WebAssembly rule.
- The Node package still lacks several high-value validation diagnostics/repro helpers. Treat those as public API backlog, not as missing validator semantics.

## Maintenance implications

- Adding or reclassifying a validator diagnostic family must update `ValidationIssue`, `validation_issue_family(...)`, invalid-fuzzer registry coverage, invalid-generation/repro tests, `docs/wiki/validate/module-validation-phases.md`, and the focused diagnostics page together.
- Adding a validator phase without adding a new family may still require a new AST-invalid strategy if the phase owns a user-visible rejection path that has no deterministic stable-id repro.
- Changing a body-level rule must preserve absolute `FuncIdx` reporting for body diagnostics when imports precede defined functions.
- Changing `ref.func` declaration sources must update both the focused `ref.func` page and invalid-repro family expectations for `undeclared-ref-func`.
- Changing invalid-repro metadata or artifact layout must update the fuzz runner page and any downstream Node/API notes that describe reproducibility surfaces.

## Follow-up questions

- Should the Node package expose `validationIssueFamily(...)`, stable invalid-AST strategy lookup, and invalid-repro builders before adding broader validate-generation helpers?
- Should Starshine eventually publish a machine-readable list that joins validation phase, `ValidationIssue` variant, family label, invalid-AST stable ids, and minimal repro artifacts?
- If Starshine aligns the start-section `ref.func` declaration divergence with the official module rule, should the old negative regression become an invalid-fuzz stable-id removal, a superseded stable id, or a compatibility alias that now expects acceptance?
