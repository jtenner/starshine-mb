# WAST Static Harness Skip Policy Refresh

- Capture date: 2026-05-20
- Source family: official WebAssembly reference-interpreter script contract plus current Starshine spec-harness skip/mismatch evidence
- Primary sources:
  - WebAssembly/spec repository, current `main`: <https://github.com/WebAssembly/spec>
  - WebAssembly reference interpreter README, `wasm-3.0` mirror: <https://chromium.googlesource.com/external/github.com/WebAssembly/spec/+/refs/heads/wasm-3.0/interpreter>
  - WebAssembly reference interpreter README search/open result, 2026-05-20: the script grammar still lists runtime assertions and static module assertions, `assert_unlinkable` as a link-failure expectation, expected failure-string checking by the reference interpreter, and delayed decode/parse for `module binary` / `module quote` so malformed assertions can be represented inside an outer script.
- Repository evidence checked:
  - `src/wast/spec_harness.mbt`
  - `src/spec_runner/spec_runner.mbt`
  - `src/cmd/cmd.mbt`
  - `src/cmd/cmd_wbtest.mbt`
  - `docs/wiki/wast/static-assertion-harness.md`
  - `docs/wiki/validate/fuzz-hardening.md`
  - `docs/wiki/tooling/cli-command-and-dispatcher.md`

## Durable takeaways

- The official reference-interpreter script model still distinguishes static module assertions (`assert_malformed`, `assert_invalid`, `assert_unlinkable`) from runtime/action assertions (`assert_return`, `assert_trap`, `assert_exception`, `assert_exhaustion`, `invoke`, `get`, `register`). Starshine's static harness remains intentionally narrower than the full upstream interpreter because it does not instantiate, link, run actions, or compare runtime results.
- Upstream `assert_unlinkable` is a link/instantiation expectation after static module acceptance. Starshine's local static result `ValidBeforeLink` is therefore only the pre-link half of the upstream assertion, not proof that a future linker would reject the imports.
- Starshine has two skip concepts that should not be conflated with passing conformance:
  - **runtime-only command skips**: command-scoped skips for action/runtime commands inside otherwise parseable scripts;
  - **unsupported/mismatch file skips**: whole-file skips when the current parser/lowerer/validator is known not to model a required upstream feature or when a small allowlisted `tests/spec/...` mismatch is temporarily tolerated.
- `src/wast/spec_harness.mbt` currently classifies the following as known unsupported errors and returns `Skipped(...)` instead of `Failed(...)`: outer script parse failure, module lowering failure, quoted-module parse/lower failure, `assert_invalid` payloads that fail before a module is compilable, and `assert_unlinkable` payloads that fail before a module is compilable. These skips preserve suite usability while keeping the skipped reason visible.
- `spec_is_known_specsuite_mismatch(...)` is deliberately narrower than the generic unsupported-error skip: it only applies to paths with the `tests/spec/` prefix and only to specific message/suffix families. As of this refresh the allowlist covers stack-underflow failures in `if.wast`, `loop.wast`, and `block.wast`; unexpected local validation success in `br.wast`, `i32.wast`, `load.wast`, `store.wast`, `labels.wast`, `return.wast`, and `local_set.wast`; and duplicate-export-name divergence in `names.wast`.
- `run_wast_spec_file(...)` can return `Passed`, `Skipped(reason)`, or `Failed(msg)`. A file with only runtime-only commands is skipped with the reason `script only contains runtime-only assertions`; a mixed file can still pass if its static commands pass and runtime commands are merely skipped.
- `src/spec_runner/spec_runner.mbt` and `starshine spec` in `src/cmd/cmd.mbt` both report aggregate `total`, `passed`, `skipped`, and `failed` file counts, so wiki claims about spec-suite health should name both the pass count and the skip count.

## Starshine implications

- Treat skipped spec files as backlog signals, not green conformance evidence. When reporting spec-runner coverage, preserve the skipped-file count and the first skipped/failing reason.
- Do not add broad new known-mismatch skips without a dated wiki/log update explaining why the mismatch is temporary, which source file or feature owns it, and what would retire it.
- Keep `spec_is_known_specsuite_mismatch(...)` path-gated to committed upstream spec fixtures. A locally authored WAST fixture should fail loudly unless its unsupported behavior is intentionally covered by a test-specific assertion or a narrower parser/validator caveat.
- If Starshine adds runtime execution or link/import resolution to the spec harness, keep the current static evaluator available for text-invalid/spec-seed fuzzing so `assert_invalid` and `assert_unlinkable` stage accounting stays stable.

## Follow-up questions

- Should the current known-mismatch allowlist move from hard-coded suffix/message checks into data fixtures so skips can be audited without editing `src/wast/spec_harness.mbt`?
- Which allowlisted `tests/spec` families should be retired first: stack-underflow control fixtures, unexpected local validation success fixtures, or duplicate-export-name divergence?
- If `starshine spec` gains a machine-readable output mode, should skipped-file reasons be emitted per file so CI dashboards can track skip retirement over time?
