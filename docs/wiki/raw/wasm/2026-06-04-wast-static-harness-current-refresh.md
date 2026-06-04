# WAST Static Harness Current Refresh

- Capture date: 2026-06-04
- Source family: official WebAssembly reference-interpreter WAST script contract plus current Starshine static harness and multi-module fuzz evidence
- Primary sources:
  - WebAssembly reference interpreter README, current `main`: <https://github.com/WebAssembly/spec/blob/main/interpreter/README.md>
  - WebAssembly reference interpreter README, `wasm-3.0` mirror: <https://chromium.googlesource.com/external/github.com/WebAssembly/spec/+/refs/heads/wasm-3.0/interpreter/README.md>
  - WebAssembly Core 3.0 embedding / instantiation model, current generated docs: <https://webassembly.github.io/spec/core/appendix/embedding.html>
- Repository evidence checked:
  - `src/wast/spec_harness.mbt`
  - `src/wast/parser.mbt`
  - `src/wast/module_wast.mbt`
  - `src/fuzz/main.mbt`
  - `src/fuzz/main_wbtest.mbt`
  - `src/fuzz/invalid_repro.mbt`
  - `src/fuzz/invalid_text_wbtest.mbt`
  - `docs/wiki/wast/static-assertion-harness.md`
  - `docs/wiki/validate/fuzz-hardening.md`
  - `docs/wiki/tooling/fuzz-runner.md`
  - `docs/wiki/validate/import-export-and-external-type-matching.md`

## Durable takeaways

- The current official reference-interpreter script contract still treats WAST as a script language: module definitions, registrations, actions, runtime assertions, and static module assertions share one command stream.
- Official `register`, `invoke`, and `get` are runtime/action surfaces. They belong to an interpreter or embedding environment, not to pure module validation.
- Official `assert_malformed`, `assert_invalid`, and `assert_unlinkable` are still the static assertion trio Starshine can use without executing exports. The first two distinguish malformed versus validation-rejected modules. `assert_unlinkable` means the module is statically accepted but is expected to fail when linked or instantiated.
- The official embedding model keeps module validation and instantiation/import resolution separate. Module validation checks the module in isolation; instantiation asks whether external values are supplied and match the imports.
- Starshine's current `src/wast/spec_harness.mbt` deliberately remains a static harness. `spec_is_runtime_only_command(...)` skips `Register`, `Action`, `AssertReturn`, `AssertTrap`, `AssertExhaustion`, `AssertException`, and `AssertSuspension`. `AssertUnlinkable` compiles/lowers/decodes the module and returns `ValidBeforeLink` after `validate_module(...)` succeeds; it does not consult earlier `register` commands or match host/provider exports.
- Starshine's parser and printer do roundtrip `register` commands, named modules, actions, and assertion commands, so those script shapes are useful parser/printer fixtures even when they are not link/execution evidence.
- The `valid-multi-module-linking` fuzz suite name and JSON counters are historical terminology. In current code, `run_valid_multi_module_linking_fuzz(...)` parses generated provider/consumer scripts, independently validates each inline module, then calls the same static `run_wast_spec_file(...)`. A `link_passed` counter therefore means "the static WAST harness passed the script"; it does not prove provider/consumer import resolution.
- `classify_multi_module_wast_case(...)` likewise classifies duplicate script module ids, duplicate register aliases, `AssertUnlinkable`, static suite pass/skip/fail, and single-module validation failures. It is a script-shape classifier, not a full host linker.
- The `gen_unlinkable_multi_module_wast_case(...)` and `build_fuz1055b4_unlinkable_failure_report(...)` surfaces intentionally record `valid-before-link` and import/provider metadata. They preserve future linker facts to replay, but the current replay predicate remains a property-stage marker rather than an actual link mismatch check.

## Starshine implications

- Keep `ValidBeforeLink` as the stable static-stage name for inline text invalid and spec-seed fuzzing. Do not reinterpret it as "link failed" unless a real linker/embedding API is added and documented.
- When reporting the `valid-multi-module-linking` suite today, spell out that it validates link-shaped scripts through the static harness. The suite is useful for preserving provider/consumer script syntax, `register` commands, per-module validation, duplicate-name classification, and future unlinkable metadata, but it is not conformance evidence for host import matching.
- If Starshine adds real import resolution, host matching, or runtime execution, keep that as a new layer above the current static harness. The existing static assertion evaluator should remain available for validator fuzzing so malformed/invalid/unlinkable stage accounting stays stable.
- The external-type matching guide remains the right place to document reusable import/export compatibility rules for a future linker. The WAST static harness page should route readers there rather than implying the static spec runner already performs host matching.

## Follow-up questions

- Should the `valid-multi-module-linking` suite be renamed or should docs keep the historical suite id but define "link" as a static, link-shaped script pass until a real linker lands?
- Should JSON details add a new `static_script_passed` or `pre_link_passed` alias next to `link_passed` to reduce future overclaims while preserving compatibility?
- If a linker lands, should `assert_unlinkable` first support missing-import detection, type-mismatch detection through `Match for ExternType`, or full `register`-driven provider resolution?
