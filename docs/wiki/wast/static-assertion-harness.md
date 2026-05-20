---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-19-wast-static-assertion-sources.md
  - ../raw/wasm/2026-05-20-wast-static-harness-skip-policy-refresh.md
  - ../../../src/wast/spec_harness.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/types.mbt
  - ../../../src/spec_runner/spec_runner.mbt
  - ../../../src/fuzz/invalid_text.mbt
  - ../../../src/fuzz/invalid_text_wbtest.mbt
related:
  - index.md
  - ../validate/fuzz-hardening.md
  - ../validate/diagnostics-and-invalid-repro.md
  - ../tooling/fuzz-runner.md
  - ../tooling/node-package-surface.md
  - identifier-name-and-annotation-authoring.md
  - element-segment-authoring.md
---

# WAST Static Assertions And Spec Harness

## Overview

WAST is more than the text format for one module. The official WebAssembly test suite uses WAST as a **script language**: a file can define modules, register modules for imports, invoke exports, read globals, and state what should pass or fail. The source snapshots in [`../raw/wasm/2026-05-19-wast-static-assertion-sources.md`](../raw/wasm/2026-05-19-wast-static-assertion-sources.md) and [`../raw/wasm/2026-05-20-wast-static-harness-skip-policy-refresh.md`](../raw/wasm/2026-05-20-wast-static-harness-skip-policy-refresh.md) record the current upstream reference-interpreter script model plus Starshine's local implementation and skip policy.

Starshine currently implements a **static** spec-harness subset:

- ordinary `module`, `module binary`, and `module quote` directives are parsed/lowered/decoded and validated;
- `assert_malformed`, `assert_invalid`, and `assert_unlinkable` are evaluated by [`evaluate_wast_static_assertion(...)`](../../../src/wast/spec_harness.mbt);
- runtime-only commands such as `assert_return`, `assert_trap`, `assert_exception`, `assert_exhaustion`, `invoke`, `get`, and `register` are parsed but skipped by the static harness.

That distinction is intentional. Starshine can use official spec files and spec-seeded invalid-fuzz fixtures as **validation evidence** without claiming to execute WebAssembly or to link imports in the WAST harness.

## Command Layers

| Script surface | Beginner meaning | Current Starshine behavior | Main code |
| --- | --- | --- | --- |
| `(module ...)` | Inline text module in the script. | Lowers through the WAST AST and then validates the resulting `@lib.Module`. | [`WastCommand::Module`](../../../src/wast/parser.mbt), [`wast_ast_to_binary_module(...)`](../../../src/wast/lower_to_lib.mbt), [`spec_check_command(...)`](../../../src/wast/spec_harness.mbt) |
| `(module binary "...")` | Raw binary bytes embedded in a script. | Decodes bytes through `src/binary`, then validates the decoded module. | [`ModuleBinary`](../../../src/wast/parser.mbt), [`@binary.decode_module(...)`](../../../src/wast/spec_harness.mbt) |
| `(module quote "...")` | Quoted text that may itself be malformed. | Joins quoted lines and reparses through `wast_to_binary_module(...)`. | [`ModuleQuote`](../../../src/wast/parser.mbt), [`spec_quote_lines_to_source(...)`](../../../src/wast/spec_harness.mbt) |
| `assert_malformed` | The payload should not become an accepted module. | Passes if parse/lower/decode fails; also currently accepts validation rejection as harness-compatible malformed rejection. | [`evaluate_wast_static_assertion(...)`](../../../src/wast/spec_harness.mbt) |
| `assert_invalid` | The module is syntactically well-formed but validation must reject it. | Requires compile/lower/decode success, then requires `validate_module(...)` failure. | [`evaluate_wast_static_assertion(...)`](../../../src/wast/spec_harness.mbt) |
| `assert_unlinkable` | The module validates, but should fail when linked/instantiated. | Requires compile/lower/decode success and validation success; reports `ValidBeforeLink` because no linker is run. | [`evaluate_wast_static_assertion(...)`](../../../src/wast/spec_harness.mbt) |
| Runtime assertions/actions | Execute exports, compare values, traps, or exhaustion. | Counted as skipped by the static harness, command by command. | [`spec_is_runtime_only_command(...)`](../../../src/wast/spec_harness.mbt) |

## Static Assertion Stage Model

The exported stage model has three outcomes:

1. `ParseOrLowerRejected` - text parse, WAST lowering, or binary decode rejected the module definition.
2. `ValidateRejected` - the module was built but Starshine validation rejected it.
3. `ValidBeforeLink` - the module was built and validated; this is the only successful local outcome for `assert_unlinkable`.

The kind model is the assertion family: `Malformed`, `Invalid`, or `Unlinkable`. The pair `(kind, stage)` is the stable result used by the spec harness and by validator fuzzing.

### Why `assert_invalid` is stricter than `assert_malformed`

```wasm
(assert_malformed (module quote "(module (func") "expected closing paren")
(assert_invalid (module quote "(module (func (result i32) nop))") "type mismatch")
```

The first assertion is about failing to accept the quoted module text, so a parse/lower rejection is enough. The second assertion is about a validly formed module that should fail validation, so Starshine treats parse/lower failure as the wrong result. This prevents invalid-fuzz seeds from accidentally counting parser gaps as validator coverage.

### Why `assert_unlinkable` does not prove a link error locally

```wasm
(assert_unlinkable
  (module (import "env" "missing" (func)))
  "unknown import")
```

The current static evaluator does not instantiate modules or resolve imports. It only proves the pre-link half: the module compiles and validates. That is still useful because it separates core validation from import-resolution failures, but it is not runtime/linker evidence.

## Spec Runner Flow

[`src/spec_runner/spec_runner.mbt`](../../../src/spec_runner/spec_runner.mbt) is a native CLI wrapper around the same library path:

1. read each requested WAST file;
2. call [`run_wast_spec_suite(...)`](../../../src/wast/spec_harness.mbt);
3. print aggregate `total`, `passed`, `skipped`, and `failed` file counts;
4. preview up to twenty failed files and return a nonzero exit code if any file failed.

A file with only runtime commands can be skipped. A mixed file should still validate its static commands: tests in [`src/wast/spec_harness.mbt`](../../../src/wast/spec_harness.mbt) cover command-scoped runtime skipping so `assert_exception` or `assert_return` does not hide later static validation checks.

## Skip, Unsupported, And Known-Mismatch Policy

The spec runner reports file-level `Passed`, `Skipped(reason)`, or `Failed(msg)`. Treat those states separately:

| State | Meaning | What it proves |
| --- | --- | --- |
| `Passed` | At least one static command was checked, every checked command succeeded, and any runtime-only commands were skipped command-by-command. | Static parse/lower/decode/validation evidence for the checked commands. |
| `Skipped(reason)` from runtime-only content | The script parsed, but no static command was checked because all commands were runtime actions/assertions such as `invoke`, `register`, or `assert_return`. | Script compatibility only; no validation evidence. |
| `Skipped(reason)` from known unsupported errors | The script or command needs a parser/lowerer/static-category behavior Starshine does not currently model well enough. | Backlog signal; not conformance evidence. |
| `Skipped(reason)` from known `tests/spec` mismatches | A narrow path-and-message allowlist tolerated a known mismatch so broad suite runs can keep moving. | Temporary debt with an explicit reason. |
| `Failed(msg)` | A non-allowlisted parse, lower, validation, or assertion-stage mismatch happened. | The file should block a strict run until investigated. |

[`spec_is_known_unsupported_error(...)`](../../../src/wast/spec_harness.mbt) currently converts outer script parse failures, module-lowering failures, quoted-module parse/lower failures, and pre-compilation failures in `assert_invalid` / `assert_unlinkable` into `Skipped(...)`. This is intentionally conservative: those cases often mean the current WAST front end cannot reach the upstream assertion category, so marking the whole file failed would hide later suite signal behind one known gap.

[`spec_is_known_specsuite_mismatch(...)`](../../../src/wast/spec_harness.mbt) is narrower. It only applies to committed `tests/spec/...` paths and exact message families, currently covering:

- stack-underflow mismatches in `if.wast`, `loop.wast`, and `block.wast`;
- unexpected local validation success in `br.wast`, `i32.wast`, `load.wast`, `store.wast`, `labels.wast`, `return.wast`, and `local_set.wast`;
- duplicate-export-name divergence in `names.wast`.

Do **not** cite skipped files as green conformance. When reporting `starshine spec` or native `spec_runner` output, include `total`, `passed`, `skipped`, and `failed`, and preserve the first skipped/failing reason when it is relevant. If a new known-mismatch skip is unavoidable, update this page, [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) if fuzz/spec-seed semantics are affected, and [`../raw/wasm/2026-05-20-wast-static-harness-skip-policy-refresh.md`](../raw/wasm/2026-05-20-wast-static-harness-skip-policy-refresh.md) or a later raw refresh with the exact retiring condition.

## Fuzzing And Spec-Seed Reuse

The text invalid and spec-seed lanes reuse this same static evaluator:

- [`src/fuzz/invalid_text.mbt`](../../../src/fuzz/invalid_text.mbt) defines the local stage names `parse-or-lower-rejected`, `validate-rejected`, and `valid-before-link` by mapping from `WastStaticAssertionStage`.
- `validate-invalid-text` uses inline `assert_malformed`, `assert_invalid`, and `assert_unlinkable` strategies to prove the parser/lowerer/validator stage split.
- `validate-invalid-spec-seed` extracts selected assertions from `tests/spec/*.wast` and replays the raw assertion S-expression through `evaluate_wast_static_assertion(...)`. Its `smoke` profile stays curated and deterministic, while `ci` / `stress` also scan committed `tests/spec` dynamically and require successful malformed, invalid, unlinkable, and multi-family matches from the scanned inventory; see [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) for suite breadth and [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md) for expected stage/family metadata.

The practical rule for maintainers is: **do not fork assertion semantics between the spec runner and fuzzing.** If a static assertion category changes, update `src/wast/spec_harness.mbt`, the fuzz stage mapping, and the wiki together.

## Current Boundaries And Caveats

- **No runtime execution yet.** `assert_return`, `assert_trap`, `assert_exception`, `assert_exhaustion`, `invoke`, `get`, and `register` are parsed for script compatibility but are not semantic evidence in Starshine's current static harness.
- **No diagnostic-text parity promise.** Upstream test assertions carry expected error strings. Starshine currently checks kind and stage, not exact upstream diagnostic text.
- **Skips are visible debt, not hidden passes.** Runtime-only scripts, unsupported parser/lowerer gaps, and narrow `tests/spec` mismatches all report `Skipped(...)` with a reason. Preserve those counts in summaries.
- **`assert_malformed` is broad locally.** The current static evaluator accepts either parse/lower/decode rejection or validation rejection for malformed assertions. If Starshine wants stricter upstream category fidelity, split that as a deliberate validator/spec-harness change.
- **`assert_unlinkable` is pre-link only.** `ValidBeforeLink` means the module survived core validation. It does not prove a future link-time error until Starshine has a linker/runtime harness.
- **Node package gap.** The MoonBit `wast` package exports `evaluate_wast_static_assertion(...)`, but the checked-in Node package does not yet expose `evaluateWastStaticAssertion(...)`; see [`../tooling/node-package-surface.md`](../tooling/node-package-surface.md).

## Validation Guidance

When touching WAST script support or static assertions:

1. Run focused `src/wast` tests around `wast spec harness ...` cases in [`spec_harness.mbt`](../../../src/wast/spec_harness.mbt).
2. If parser command coverage changes, update [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) and the lexer keywords in [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt) together.
3. If stage semantics change, update [`src/fuzz/invalid_text.mbt`](../../../src/fuzz/invalid_text.mbt), [`src/fuzz/invalid_text_wbtest.mbt`](../../../src/fuzz/invalid_text_wbtest.mbt), [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md), [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md), and this page.
4. For broad confidence, run the `spec_runner` on selected `tests/spec/*.wast` files and the `validate-invalid-text` / `validate-invalid-spec-seed` fuzz suites through the wrapper described in [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md).

## Sources

- Primary-source snapshots: [`../raw/wasm/2026-05-19-wast-static-assertion-sources.md`](../raw/wasm/2026-05-19-wast-static-assertion-sources.md), [`../raw/wasm/2026-05-20-wast-static-harness-skip-policy-refresh.md`](../raw/wasm/2026-05-20-wast-static-harness-skip-policy-refresh.md)
- Parser and AST: [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/types.mbt`](../../../src/wast/types.mbt), [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt)
- Static evaluator and tests: [`../../../src/wast/spec_harness.mbt`](../../../src/wast/spec_harness.mbt)
- CLI wrapper: [`../../../src/spec_runner/spec_runner.mbt`](../../../src/spec_runner/spec_runner.mbt)
- Fuzz reuse: [`../../../src/fuzz/invalid_text.mbt`](../../../src/fuzz/invalid_text.mbt), [`../../../src/fuzz/invalid_text_wbtest.mbt`](../../../src/fuzz/invalid_text_wbtest.mbt), [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md), [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md)
