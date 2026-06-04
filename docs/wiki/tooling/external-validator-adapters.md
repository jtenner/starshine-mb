---
kind: workflow
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/validation/2026-06-04-external-validator-adapters-source-refresh.md
  - ../../../src/cmd/fuzz_harness.mbt
  - ../../../src/cmd/fuzz_harness_wbtest.mbt
related:
  - fuzz-runner.md
  - pass-fuzz-compare.md
  - validation-gates.md
  - ../validate/fuzz-hardening.md
  - ../validate/diagnostics-and-invalid-repro.md
  - ../binary/leb128-and-integer-encoding.md
  - ../binary/module-section-map.md
---

# External Validator Adapters

## Overview

Use this page when a fuzz, command-harness, or validation report compares Starshine with `wasm-tools`, WABT, or Binaryen and you need to decide whether the result is a Starshine bug, a malformed input, a proposal/tool gap, or simply skipped evidence.

Starshine has two related but separate external-validator surfaces:

1. **The command-harness binary differential adapter surface** in [`src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt). It runs Starshine's own decode/validate path plus optional external adapters and classifies the aggregate result.
2. **The compare-pass validation steps** in [`pass-fuzz-compare.md`](pass-fuzz-compare.md). Those validate pass-fuzz inputs and Starshine outputs with `wasm-tools validate --features all`, may run optional skip-clean external validators, and then compare against Binaryen's pass oracle.

Do not merge those concepts. Command-harness adapters answer “how do validators classify these bytes?” Compare-pass answers “did a Starshine pass match the Binaryen pass oracle after the input and output were independently valid?”

The current source bridge is [`../raw/validation/2026-06-04-external-validator-adapters-source-refresh.md`](../raw/validation/2026-06-04-external-validator-adapters-source-refresh.md). It rechecked the official `wasm-tools`, WABT, and Binaryen surfaces plus the local MoonBit adapter and test code.

## Beginner Model

A WebAssembly binary can fail at different layers:

- **Decode failure:** the bytes are not a well-formed module. Examples include a bad magic header, truncated section payload, malformed LEB128, or invalid opcode byte.
- **Validation failure:** the bytes decode into a module, but the module is not valid WebAssembly. Examples include a type mismatch, out-of-range index, duplicate export name, or invalid constant expression.
- **Unsupported feature:** a tool understands the container but rejects the module because a proposal or feature is not enabled or implemented in that tool build.
- **Tool failure:** the external command crashed, timed out, failed to stage files, emitted unusable diagnostics, or otherwise did not produce trustworthy validator evidence.
- **Adapter unavailable:** the current target is not native or the external executable is missing. This is skipped evidence, not a semantic result.

Starshine's adapter schema keeps those separate so reports can point to the right owner.

## Adapter Matrix

| Adapter | Local function | External command shape | What success means | Main caveat |
| --- | --- | --- | --- | --- |
| Starshine local | `binary_differential_starshine_result(...)` | in-process `decode_module(...)` then `validate_module(...)` | Starshine decoded and validated the bytes. | This is the local owner, not an external oracle. |
| `wasm-tools` | `run_wasm_tools_binary_validation_adapter(...)` | `wasm-tools validate <temp.wasm>` in the command-harness adapter; compare-pass uses `wasm-tools validate --features all` for its own gates. | The installed `wasm-tools` validator accepted the bytes under the command line used by that surface. | Command-harness and compare-pass intentionally use different command lines; cite the exact surface. |
| WABT | `run_wabt_binary_validation_adapter(...)` | `wasm-validate <temp.wasm>` | WABT accepted the binary-format module. | Feature defaults depend on the installed WABT build; unsupported-feature results are proposal/tool evidence. |
| Binaryen | `run_binaryen_binary_validation_adapter(...)` | `wasm-opt --all-features --validate <temp.wasm> -o <temp.out.wasm>` | Binaryen accepted the module while writing a temporary output. | This is not byte-preservation or pass-oracle equivalence; compare-pass owns Binaryen optimizer parity. |

All three external command-harness adapters are native-only. Non-native builds and missing executables return `adapter-unavailable`, and checked-in tests allow that result.

## Classification Ladder

[`classify_binary_differential_results(...)`](../../../src/cmd/fuzz_harness.mbt) aggregates Starshine plus zero or more external adapter results in this order:

1. **Adapter unavailable wins first.** If any selected adapter cannot run, the case is `adapter-unavailable`. This protects default tests and non-native targets from pretending skipped evidence was a validator decision.
2. **Tool failure wins next.** A crashed or unusable external tool is `tool-failure`, not a Starshine validation result.
3. **Unsupported feature is handled before agreement.** If every available adapter reports unsupported/proposal diagnostics, the aggregate is `unsupported-feature`. If some adapters classify the bytes while another reports unsupported feature, the aggregate is `proposal-gap`.
4. **All-valid means `agree-valid`.** Every available adapter accepted the bytes.
5. **All-invalid at one stage means `agree-invalid`.** All available adapters rejected the bytes as decode-invalid, or all rejected them as validation-invalid.
6. **Mixed decode-invalid with any other stage means `decoder-stage-disagreement`.** At least one tool thinks the bytes are malformed while another decodes farther or accepts them.
7. **Remaining mixed validation outcomes mean `validator-stage-disagreement`.** The bytes decode locally but tools disagree on validation.

The helper [`binary_differential_failed_validation_result(...)`](../../../src/cmd/fuzz_harness.mbt) maps a failed external command into decode-invalid versus validate-invalid by reusing Starshine's decoder on the same bytes after checking for unsupported/proposal wording in diagnostics.

## Concrete Flow

For one binary corpus case, [`run_binary_differential_smoke(...)`](../../../src/cmd/fuzz_harness.mbt) does this:

```text
input bytes
  -> Starshine decode/validate adapter result
  -> optional wasm-tools result
  -> optional WABT result
  -> optional Binaryen result
  -> classify_binary_differential_results(...)
  -> aggregate counters
```

The report formatter [`format_binary_differential_smoke_report_json(...)`](../../../src/cmd/fuzz_harness.mbt) writes compact JSON counters for:

- `agree_valid`
- `agree_invalid`
- `proposal_gap`
- `decoder_stage_disagreement`
- `validator_stage_disagreement`
- `tool_failure`
- `unsupported_feature`
- `adapter_unavailable`
- `external_adapters`

Those counters are intentionally coarse. Persisted repro work should still keep the original bytes, selected adapter names, command diagnostics, Starshine decode/validation stage, and feature facts when available; use [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md) for durable invalid-repro metadata.

## How To Interpret Outcomes

| Outcome | Meaning | Report as | Next step |
| --- | --- | --- | --- |
| `agree-valid` | Starshine and selected available adapters accept the bytes. | External-validity support for this case. | If this was optimizer output, continue to pass-specific semantic comparison. |
| `agree-invalid` | All selected available adapters reject at decode stage or all reject at validation stage. | Shared invalidity evidence. | Route by stage: malformed bytes to binary/codec owners, validation-invalid modules to validator owners. |
| `proposal-gap` | At least one tool reports unsupported/proposal while another reaches a normal valid/invalid decision. | Tool/proposal support gap. | Check current proposal status and feature flags before filing a Starshine bug. |
| `decoder-stage-disagreement` | Tools disagree about whether the bytes are well formed. | Codec/canonicality disagreement. | Inspect LEB128, section framing, custom/name-section, and proposal-prefix encoding first. |
| `validator-stage-disagreement` | Tools decode the bytes but disagree on validity. | Validation-semantics disagreement. | Compare proposal support, feature gates, official spec text, and Starshine diagnostics. |
| `unsupported-feature` | Selected adapters only reported unsupported/proposal. | Unsupported evidence, not pass/fail. | Add a feature-gated repro or choose a tool/build with the needed proposal. |
| `tool-failure` | An external command failed operationally. | Tooling failure. | Retry, inspect stderr, or drop that adapter from the evidence lane. |
| `adapter-unavailable` | An adapter was selected but could not run. | Skipped evidence. | Install the executable or run a native target if external evidence is required. |

## Relationship To Compare-Pass

Compare-pass has a stricter and more specialized ladder:

- inputs are validated with `wasm-tools validate --features all` before either optimizer runs;
- Starshine raw outputs are validated the same way before canonical comparison;
- Binaryen runs `wasm-opt --all-features <pass flags>` as the optimizer oracle;
- optional `--external-validator wasm-tools|binaryen|wabt` checks are skip-clean add-ons and do not replace the main normalized-WAT oracle.

That means a command-harness `agree-valid` result is useful external evidence, but it does not sign off Binaryen pass parity. Conversely, a compare-pass normalized match is pass-oracle evidence, but it does not prove every external validator would classify arbitrary raw bytes the same way under a different command line.

## Edge Cases And Invariants

- **Adapter unavailability is explicit.** Do not silently drop selected adapters from aggregate counts.
- **Do not classify proposal gaps as Starshine bugs without source review.** External tools can lag or lead Starshine on GC, strings, exception handling, memory64, threads, SIMD, relaxed SIMD, custom descriptors, or other proposal surfaces.
- **Decode-vs-validation stage matters.** A malformed LEB or section-size underflow is a binary codec issue; a decoded `call_indirect` type mismatch is validator semantics.
- **Binaryen validation is optimizer-backed.** The current adapter uses `wasm-opt --all-features --validate` and writes a temporary output, so it can expose Binaryen parser/validator behavior but does not preserve original bytes.
- **WABT command-harness evidence is not all-features evidence.** The local adapter invokes `wasm-validate` without additional feature flags today.
- **Compare-pass `--features all` wording belongs to compare-pass and self-opt gates.** Do not retrofit it onto the command-harness adapter unless the code changes.
- **Canonicality disagreements need local policy context.** For bounded-overlong LEB128 and other accepted-noncanonical inputs, pair reports with [`../binary/leb128-and-integer-encoding.md`](../binary/leb128-and-integer-encoding.md) before claiming either side is wrong.

## Maintenance Guidance

- Update this page whenever `BinaryValidationOutcome`, `BinaryDifferentialClassification`, native adapter command lines, non-native fallback behavior, or binary-differential report fields change.
- Update [`validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) for broad invalid-lane coverage claims; keep this page focused on external adapter semantics.
- Update [`pass-fuzz-compare.md`](pass-fuzz-compare.md) when pass-fuzz input/output validation, optional external validators, or Binaryen oracle behavior changes.
- If an external tool's feature defaults become important to a claim, capture a fresh raw source note and record whether the evidence came from command-harness adapters, compare-pass, self-opt validation, or a one-off manual repro.

## Sources

- Current source bridge: [`../raw/validation/2026-06-04-external-validator-adapters-source-refresh.md`](../raw/validation/2026-06-04-external-validator-adapters-source-refresh.md)
- Adapter implementation: [`../../../src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt)
- Adapter and classifier tests: [`../../../src/cmd/fuzz_harness_wbtest.mbt`](../../../src/cmd/fuzz_harness_wbtest.mbt)
- Related workflows: [`fuzz-runner.md`](fuzz-runner.md), [`pass-fuzz-compare.md`](pass-fuzz-compare.md), [`validation-gates.md`](validation-gates.md), [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md), [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md)
