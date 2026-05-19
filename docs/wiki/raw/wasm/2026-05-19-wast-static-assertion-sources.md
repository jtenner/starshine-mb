# WAST Static Assertion And Spec Harness Source Snapshot

- Capture date: 2026-05-19
- Source family: WebAssembly reference interpreter / official test-suite script grammar plus current Starshine WAST harness evidence
- Primary sources:
  - WebAssembly/spec repository README, current `main`: <https://github.com/WebAssembly/spec>
  - WebAssembly reference interpreter README, `main`: <https://raw.githubusercontent.com/WebAssembly/spec/main/interpreter/README.md>
  - WebAssembly reference interpreter README, readable `wasm-3.0` mirror: <https://chromium.googlesource.com/external/github.com/WebAssembly/spec/+/refs/heads/wasm-3.0/interpreter>
- Repository evidence checked:
  - `src/wast/spec_harness.mbt`
  - `src/wast/parser.mbt`
  - `src/wast/types.mbt`
  - `src/spec_runner/spec_runner.mbt`
  - `src/fuzz/invalid_text.mbt`
  - `src/fuzz/invalid_text_wbtest.mbt`
  - `docs/wiki/validate/fuzz-hardening.md`
  - `docs/wiki/tooling/node-package-surface.md`

## Durable takeaways

- The official WebAssembly/spec repository is the canonical upstream home for the specification, the reference interpreter, and the official test suite.
- The reference interpreter treats WAST files as scripts for testing, not just as single-module text format. Scripts can define modules, register modules for imports, perform actions, use assertions, and use meta commands.
- The script assertion family includes runtime assertions such as `assert_return`, `assert_trap`, `assert_exception`, and `assert_exhaustion`, plus static module assertions such as `assert_malformed`, `assert_invalid`, and `assert_unlinkable`.
- The upstream script grammar has two intentionally failure-capable module forms: `(module binary "...")` for raw byte payloads and `(module quote "...")` for quoted text payloads. These are parsed/decoded when the command executes so that malformed and invalid expectations can be represented inside a valid outer script.
- The reference interpreter treats assertion failure strings as expected-error documentation with prefix checking against its own diagnostics. Starshine's current static evaluator records the assertion kind and rejection stage, but it does not require local diagnostics to match the upstream text exactly.
- `assert_malformed` means the payload should fail before or during static acceptance: malformed text/binary can fail parse/lower/decode, and Starshine currently also accepts validation rejection under the malformed umbrella for harness compatibility.
- `assert_invalid` means the module definition should compile/lower/decode successfully but fail validation.
- `assert_unlinkable` means the module should be valid before link time; Starshine has no runtime linker in this static path, so its local check is specifically "valid before link" rather than proof of an eventual link error.
- Starshine's `src/wast/parser.mbt` models `module`, `module binary`, `module quote`, `register`, `invoke`, `get`, all listed assertion commands, and result patterns including NaN and reference result forms.
- Starshine's `src/wast/spec_harness.mbt` deliberately implements only static conformance semantics today: it validates ordinary module directives and the static assertion trio, while runtime-only commands are skipped command-by-command instead of failing whole mixed scripts.
- `src/spec_runner/spec_runner.mbt` is a thin native CLI over `run_wast_spec_suite(...)`; it reads one or more WAST files, prints aggregate pass/skip/fail counts, and previews failing files.
- The validator text/spec-seed fuzzing lane reuses `evaluate_wast_static_assertion(...)`, so spec-seed replay and direct spec-harness checks share one stage model for malformed, invalid, and unlinkable assertions.
- The Node package currently does not expose `evaluate_wast_static_assertion(...)`, even though the MoonBit `wast` package exports it; that remains a small public API gap for JS-side spec-harness tooling.

## Starshine implications

- Treat WAST script support as a test-harness layer over the core WAT module grammar. Do not use the static harness as evidence that Starshine can execute exported functions, instantiate imports, or compare runtime values.
- When widening spec-suite coverage, preserve the command-scoped runtime skip policy: a file with runtime assertions and static assertions should still check the static assertions.
- Keep `assert_invalid` strict: parse/lower/decode failure is not a valid invalid-module result because the upstream category assumes a syntactically well-formed module that validation rejects.
- Keep `assert_unlinkable` strict in the opposite direction: parse/lower/decode and validation must succeed before the local static evaluator reports `ValidBeforeLink`.
- If Starshine later gains runtime execution or linking in the spec harness, split that work from the existing static evaluator so validator/spec-seed fuzzing can continue to rely on stable static-stage outcomes.

## Follow-up questions

- Should `assert_malformed` continue to accept validator rejection as a local compatibility shortcut, or should Starshine eventually split malformed parse/decode failures from invalid validation failures more strictly?
- If the Node package exposes `evaluateWastStaticAssertion(...)`, should it return the exact MoonBit enum names or a JS-friendly string-object result matching the text/spec-seed fuzz report terminology?
- If runtime execution support is added, which runtime-only commands should land first: `assert_return` with numeric values, `assert_trap`, registration/import linking, or module-instantiation traps?
