---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-04
sources:
  - https://github.com/bytecodealliance/wasm-tools/blob/main/README.md
  - https://github.com/WebAssembly/wabt/blob/main/docs/wabt.md#wasm-validate
  - https://github.com/WebAssembly/binaryen/blob/main/src/tools/wasm-opt.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/tools/wasm-opt-options.h
  - ../../../../src/cmd/fuzz_harness.mbt
  - ../../../../src/cmd/fuzz_harness_wbtest.mbt
related:
  - ../../tooling/external-validator-adapters.md
  - ../../tooling/fuzz-runner.md
  - ../../tooling/pass-fuzz-compare.md
  - ../../validate/fuzz-hardening.md
---

# External validator adapter source refresh

This source bridge captures the current external-tool and Starshine evidence for optional binary differential validation adapters.

## Primary external tools checked

- `wasm-tools validate` remains the Bytecode Alliance validation CLI documented in the official `wasm-tools` README. The same README documents explicit feature toggles and proposal/default behavior; Starshine's pass-fuzz and self-opt gates continue to use an explicit `--features all` policy where those scripts own the command line.
- WABT documents `wasm-validate` as the validation tool for files in the WebAssembly binary format. Starshine's command-harness adapter calls the executable without extra feature flags, so proposal support and default feature policy are tool-version-dependent evidence, not an all-features guarantee.
- Binaryen's `wasm-opt` source owns the optimizer/validator command surface used by Starshine's Binaryen adapter. Starshine stages a temporary output path and invokes `wasm-opt --all-features --validate <input> -o <out>`, then deletes the temporary output. This makes Binaryen evidence an optimizer-backed validation probe, not a byte-preservation check.

## Starshine implementation evidence

- `src/cmd/fuzz_harness.mbt` defines `BinaryValidationOutcome` with valid, decode-invalid, validate-invalid, tool-failure, unsupported-feature, and adapter-unavailable cases.
- `classify_binary_differential_results(...)` treats adapter unavailability and tool failure as explicit skip/failure buckets, keeps unsupported-feature alone separate from proposal gaps, and splits decode-stage disagreements from validator-stage disagreements.
- `binary_differential_failed_validation_result(...)` uses Starshine's own decoder to decide whether an external failure was decode-stage or validation-stage after checking for unsupported/proposal diagnostics.
- Native adapter functions exist for `wasm-tools`, WABT, and Binaryen. Non-native targets return `adapter-unavailable`; default tests therefore do not require external executables to be installed.
- `run_binary_differential_smoke(...)` always includes the Starshine decode/validate result and appends any injected external adapters before aggregating counters into a compact JSON report.
- `src/cmd/fuzz_harness_wbtest.mbt` locks the classification schema, decoder/validator disagreement split, optional `wasm-tools` valid/malformed behavior, WABT and Binaryen optional adapters, and compact report formatting without making installed tools mandatory.

## Durable wiki takeaways

- External validator adapters are differential evidence, not the canonical validator. Starshine remains the local decode/validate owner; external tools are optional cross-checks that can disagree because of proposal support, canonicality policy, parser acceptance, or tool availability.
- Treat `adapter-unavailable` as skipped evidence, not a passing or failing validation result.
- Treat `unsupported-feature` as a tool support fact. If another adapter accepts or rejects the same bytes, classify the case as a proposal gap before claiming a Starshine bug.
- Decode-stage disagreement and validator-stage disagreement should be reported separately. A malformed byte stream and a structurally decodable but type-invalid module have different owners and different repro routes.
- Binaryen adapter success only says that `wasm-opt --all-features --validate` accepted and wrote an output. It does not prove byte equality, custom-section placement preservation, or pass-oracle equivalence; those remain compare-pass responsibilities.
