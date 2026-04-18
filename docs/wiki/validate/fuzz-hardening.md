---
kind: concept
status: supported
last_reviewed: 2026-04-18
sources:
  - ../raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md
  - ../raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md
  - ../raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md
  - ../../../src/fuzz/gen_invalid_wbtest.mbt
  - ../../../src/fuzz/invalid_binary.mbt
  - ../../../src/fuzz/invalid_repro.mbt
  - ../../../src/fuzz/invalid_text.mbt
  - ../../../src/validate/gen_invalid.mbt
  - ../../../src/validate/gen_invalid_tests.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
  - ../../../src/wast/spec_harness.mbt
related:
  - ./trace-benchmark-baseline.md
  - ../tooling/fuzz-runner.md
  - ../../../src/fuzz/main.mbt
  - ../../../src/validate/validate.mbt
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../agent-todo.md
---

# Validator Fuzz Hardening

## Durable Conclusions

- The current checked-in fuzz runner is now strong on valid-module coverage plus four distinct validator rejection lanes: AST-invalid, binary-invalid, text-invalid, and spec-seeded invalid/malformed/unlinkable replay.
- The active runnable suites are currently `validate-valid`, `validate-invalid-ast`, `validate-invalid-binary`, `validate-invalid-text`, `validate-invalid-spec-seed`, `binary-roundtrip`, `wast-roundtrip`, `wat-roundtrip`, and `cmd-harness`.
- The fuzz runner no longer carries reserved validator-rejection suite ids in the CLI, and the Bun wrapper now forwards the same discovery plus `--emit-gen-valid-batch` surfaces as the Moon entrypoint instead of exposing a narrower wrapper-only contract.
- The direct `validate-valid` generator loop is owned by `run_validate_valid_fuzz`, while `src/fuzz/main.mbt` now only layers the extra text companion checks on top and reuses `validate_valid_run_config(...)` for the shared profile ladder instead of keeping a second copy.
- The widened `coverage-forced` `gen-valid` batch already exposed and now closed two concrete downstream `RUME` parity holes:
  - `remove-unused-module-elements` no longer preserves an unused imported function or its dead simple function type in the saved repro `.tmp/pass-fuzz-fuz003-genvalid-smoke/failures/case-000001-gen-valid/`; see [`../raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md`](../raw/research/0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md).
  - `remove-unused-module-elements` now also matches Binaryen's no-op `start` pruning family for defined single-`nop` start targets, including the saved repros `.tmp/pass-fuzz-fuz003a-genvalid-smoke/failures/case-000002-gen-valid/` and `case-000020-gen-valid/`; see [`../raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md`](../raw/research/0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md).
- The restored AST invalid lane now keeps one checked-in strategy registry and fails smoke runs when a required strategy never becomes applicable, never mutates, or never reaches the expected diagnostic family.
- The AST lane now also has one shared `gen_invalid` helper in `src/validate/gen_invalid.mbt` that starts from either a random `gen_valid` seed or a minimal valid seed, optionally widens seed prerequisites per strategy, and then applies the parameterized invalid mutation before the runner records rejection-family stats.
- That helper is now a real public integration surface rather than only an internal runner detail: `pkg.generated.mbti` exports `GenInvalidAstParams`, `GenInvalidAstGenerated`, `gen_invalid_ast_seed_config`, `gen_invalid_ast_seed_module`, and `gen_invalid_ast_generate`, and checked-in wbtests prove downstream packages can consume the API with a stable-id lookup plus named `natural_seed(...)`, `coverage_forced_seed(...)`, `small_natural_seed(...)`, `small_coverage_forced_seed(...)`, `repro_seed(...)`, and `minimal_seed(...)` entrypoints.
- AST seed params now preserve semantic seed-profile identity in addition to raw config knobs: the validate package exports `GenInvalidNamedSeedProfile`, `gen_invalid_seed_mode_name(...)`, `gen_invalid_named_seed_profile_name(...)`, and `gen_invalid_ast_params_profile_name(...)` so callers and downstream repro/report surfaces can distinguish `repro` from the lower-level `small_coverage_forced_seed(...)` alias even though both intentionally shrink to the same compact generator config.
- The validate package now also exposes reusable seed-shaping helpers instead of keeping every strategy prerequisite inline: `gen_invalid_require_memory_data_gen_valid_config(...)` centralizes the memory/data-count seed widening used for `MissingDataCount`, `gen_invalid_require_defined_func_gen_valid_config(...)` centralizes the "at least one defined function plus its type" shaping used by downstream binary invalid generation, and `gen_invalid_small_gen_valid_config(...)` remains the compact random-seed preset shared across AST and binary surfaces.
- The currently landed AST-invalid strategy set now covers duplicate export names plus out-of-range export func, table, global, and tag indices, invalid start signatures plus out-of-range start function indices, missing datacount for both `memory.init` and `data.drop`, datacount mismatches in both too-small and too-large directions, undeclared `ref.func`, out-of-range function-name, memory-name, table-name, global-name, type-name, elem-name, data-name, and tag-name indices, out-of-range function-section and imported-function type indices, function sections without code sections, code sections without function sections, mutable `global.get` uses inside constant global initializers and table initializers, non-constant active data and element offsets, shared memories without maxima, invalid tag type indices, descriptor metadata on non-struct function types, and datacount sections without data sections.
- With those additions, the checked-in AST invalid registry now has at least one deterministic mutation strategy for every current `ValidationIssueFamily`: type, import, function, table, memory, tag, global, element, data, datacount, start, export, code, name, and function-body.
- The binary invalid lane now also keeps one shared generator helper inside `src/fuzz/invalid_binary.mbt` that starts from either a random `gen_valid` seed or a minimal valid module before applying the chosen byte-corruption strategy.
- The binary lane now mirrors the AST lane's package boundary too: the fuzz package exports `GenInvalidBinaryParams`, `GenInvalidBinaryGenerated`, `gen_invalid_binary_seed_config`, `gen_invalid_binary_seed_module`, and `gen_invalid_binary_generate`, and checked-in wbtests lock the named `natural_seed(...)`, `coverage_forced_seed(...)`, `small_natural_seed(...)`, `small_coverage_forced_seed(...)`, `repro_seed(...)`, and `minimal_seed(...)` paths, including both validator-rejected and decode-rejected minimal-seed flows.
- Binary seed params now also retain a semantic profile label and expose `gen_invalid_binary_seed_mode_name(...)` plus `gen_invalid_binary_params_profile_name(...)`, which gives the repro/report layer a stable way to record whether a persisted case came from a generic `new(...)`/custom path or from one of the named presets.
- `GenInvalidBinaryParams` now also mirrors AST params semantically, not just structurally: all binary constructors now take `require_strategy_prereqs?`, defaulting to `true`, so callers can opt out of automatic seed widening when they explicitly want to fuzz or replay against a stricter hand-picked valid-generation profile. The shared `gen_invalid_binary_seed_config(...)` path currently uses that toggle to route `InvalidFuncTypeIndex` through the validate-side defined-function seed helper.
- The binary invalid lane also keeps one checked-in byte-corruption registry and distinguishes two rejection stages per strategy: decode rejected vs decode succeeded but validator rejected.
- The currently landed binary-invalid strategy set covers trailing garbage, truncated modules, duplicate type sections, wrong section order, bad magic headers, bad version headers, reserved section ids, malformed custom-section name UTF-8, out-of-range function-section type indices, and a second class of validator-rejected encoded modules built from deterministic AST invalid mutations: invalid start signatures, duplicate export names, out-of-range export func/table/global/tag indices, function sections without code sections, code sections without function sections, datacount sections without data sections, datacount mismatches in both too-small and too-large directions, and out-of-range function, table, global, type, elem, data, and tag name indices.
- The text invalid lane now keeps one checked-in inline text registry and distinguishes three stage outcomes per strategy: parse/lower rejected, validator rejected after lowering, and valid-before-link for unlinkable cases.
- The currently landed text-invalid strategy set now covers a malformed quoted module with a missing closing paren, a malformed quoted module with trailing garbage, malformed quoted modules with invalid float-const tokens in `f32`, `f64`, plus invalid `i64` and hex-`i32` const-token shapes, an invalid result-stack module, an invalid mutable-`global.get` const-initializer module, invalid parameterized, result-returning, and imported-parameterized start-function modules, an invalid duplicate-export-name module, and six valid-but-unlinkable inline modules that depend on unknown function, memory, global, or table imports or on typed incompatible function/global import surfaces.
- The spec-seed lane now samples selected `tests/spec` assertions from the `assert_malformed`, `assert_invalid`, and `assert_unlinkable` categories, extracts the raw target assertion S-expression, and then reuses the shared WAST static-assertion evaluator so corpus replay follows the same semantics as the spec harness.
- The curated spec-seed registry now includes multiple committed assertions per stage family instead of only one example of each: six malformed quote cases from `tests/spec/const.wast`, six invalid type-mismatch cases from `tests/spec/f32.wast`, and six unlinkable cases from `tests/spec/imports.wast`, including both unknown-import and incompatible-import-type failures.
- The current tree now also has one shared invalid repro surface in `src/fuzz/invalid_repro.mbt`: persisted reports record suite/profile/seed/attempt/strategy/source kind plus expected-vs-actual stage and diagnostic-family facts, public report builders now exist for AST, binary, text, and spec-seed stable ids, and one generic dispatcher `build_invalid_fuzz_failure_report_by_suite_and_stable_id(...)` now routes across those four source kinds from either full suite names or short aliases like `ast`, `binary`, `text`, and `spec-seed`. Saved AST/binary reports are built from the shared `gen_invalid` helpers instead of ad hoc mutation code, the default AST/binary report-builder path now uses the named compact `repro_seed(...)` helpers to keep persisted seed artifacts smaller while preserving the same rejection-family outcome, AST/binary report metadata now also records `seed_profile`, `seed_mode`, and `seed_require_strategy_prereqs`, AST/binary report artifacts keep both the invalid specimen and the valid seed that produced it, and saved artifacts can be reduced and replayed without rerunning the original random loop.
- The fuzz CLI now exposes that shared repro machinery directly through `--emit-invalid-repro`, which accepts a suite/source-kind selector, stable-id strategy, seed, attempt number, output directory, and optional profile name, then persists the full repro bundle using the same metadata and artifact layout already exercised by the library-level report builders.
- The bounded shrink surface now differs by source kind instead of pretending one reducer fits all cases:
  - AST strategies reduce to checked-in minimal invalid modules.
  - Binary strategies reduce to checked-in minimal corrupted wasm bytes.
  - Inline text strategies reduce to their exact canonical single-assertion source.
  - Spec-seed cases reduce the larger fixture down to the one extracted raw assertion S-expression.
- A rejected module only counts as meaningful coverage if the intended mutation ran and the diagnostic family matches the expected failure class.
- Heavy fuzz work stays in `src/fuzz`, not `moon test`.

## Main Gaps

- The shared config, valid-coverage, invalid-lane, repro-persistence, and wrapper truth surfaces from the original hardening plan are now all landed in-tree.
- Follow-up work is now about widening specific families rather than rebuilding the stack shape: richer binary corruption families beyond the current header/order/duplication/core/custom-name set (for example malformed LEBs, section-size corruption, and more UTF-8 corruption), more binary validator-rejected families beyond the current function/start/export/code/datacount/name coverage, even deeper per-family AST invalid breadth inside already-covered validator families beyond the now broader name-section map coverage, richer GC-shaped valid generation, and any newly exposed downstream parity holes from the broader generator.
- The binary lane intentionally still starts with a curated deterministic corruption core instead of the full malformed-byte matrix, so future widening should add new families without weakening the current stage-aware accounting and replay contract.

## Hardening Order

1. Keep the suite surface truthful: separate active suites from reserved future invalid ids, keep help/list output honest, and avoid stale generator names.
2. Add shared config/stats plumbing: centralize mode, size, feature, and exercised-fact bookkeeping before widening behavior.
3. Widen valid coverage: split broad sampling from forced-coverage generation and add richer topology, bodies, and measurable breadth.
4. Widen invalid coverage: add AST, binary, text, and spec-seed invalid lanes with diagnostic-aware accounting.
5. Improve CI ergonomics: keep persisted repro artifacts and machine-readable reporting stable while wrapper/docs surfaces stay aligned with the live runner.

## Practical Rule

- Treat coverage as four separate facts: strategy available, strategy exercised, strategy rejected, and strategy rejected for the right reason.
- Keep the generator broad enough to represent real valid modules; add mutation-friendly forcing as a separate mode instead of hard-wiring it into every run.
- Add new heavy or differential validator fuzz lanes as `src/fuzz` suites so smoke and deterministic developer loops stay small.

## Sources

- Archived research doc: [`../raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md`](../raw/research/0058-2026-03-23-validate-fuzz-hardening-plan.md)
- Active backlog slices: [`../../../agent-todo.md`](../../../agent-todo.md)
