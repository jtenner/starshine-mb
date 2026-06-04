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

# External validator surface split

This source bridge records a repository-evidence refresh for the two similarly named external validation surfaces in `src/cmd/fuzz_harness.mbt` and the separate compare-pass validator lane. It supplements, but does not replace, [`2026-06-04-external-validator-adapters-source-refresh.md`](2026-06-04-external-validator-adapters-source-refresh.md).

## Primary external sources checked

- The official `wasm-tools` README documents `wasm-tools validate` and feature toggles. Starshine's compare-pass and self-opt gates use explicit `--features all`; the command-harness adapter does not.
- WABT documents `wasm-validate` as the binary-format validator. Starshine invokes it without extra feature flags in the WABT adapter and in the legacy per-case agreement helper's currently misnamed `binaryen_validate` slot.
- Binaryen's `wasm-opt` source and option definitions own the `--all-features --validate` validation probe used by the newer Binaryen binary adapter. Because that command writes an output module, its evidence is optimizer-backed validation, not raw byte preservation.

## Repository evidence checked

- `DifferentialAdapters` and `differential_validate_wasm(...)` are the older per-case agreement helper. They record `internal_valid`, `wasm_tools_valid`, `binaryen_valid`, timeout flags, and optional external booleans. They do not produce `BinaryDifferentialClassification` stage buckets.
- In native builds, `default_differential_adapters()` wires `wasm_tools_validate` to `wasm-tools validate` and currently wires the `binaryen_validate` field to `wasm-validate`. That means the field/report label is historical and should not be read as Binaryen `wasm-opt` evidence unless the implementation changes.
- `BinaryDifferentialAdapterResult`, `classify_binary_differential_results(...)`, `run_wasm_tools_binary_validation_adapter(...)`, `run_wabt_binary_validation_adapter(...)`, `run_binaryen_binary_validation_adapter(...)`, and `run_binary_differential_smoke(...)` are the newer FUZ1044 surface. They distinguish valid, decode-invalid, validation-invalid, unsupported-feature, tool-failure, and adapter-unavailable outcomes, then aggregate agree/proposal/stage-disagreement counters.
- The newer Binaryen adapter is the surface that actually invokes `wasm-opt --all-features --validate <input> -o <out>`. The WABT adapter invokes `wasm-validate <input>`. The `wasm-tools` adapter invokes `wasm-tools validate <input>`.
- `src/cmd/fuzz_harness_wbtest.mbt` locks both surfaces: the legacy helper reports mismatches/timeouts through `DifferentialValidationReport`, while the FUZ1044 tests lock the classified result schema and optional `wasm-tools`, WABT, and Binaryen adapter behavior without requiring installed external tools.
- `tooling/pass-fuzz-compare.md` remains separate. Compare-pass validates inputs and Starshine outputs with `wasm-tools validate --features all`, runs Binaryen as the optimizer oracle, optionally records skip-clean extra validators, and compares normalized WAT. It should not inherit command-harness adapter labels or command lines.

## Durable wiki takeaways

- When a report says `binaryen_valid` from `DifferentialValidationReport`, inspect the source surface before treating it as Binaryen evidence. Current native defaults route that historical slot through WABT `wasm-validate`.
- When a report says `run_binaryen_binary_validation_adapter(...)`, it is the newer FUZ1044 classified adapter and currently uses Binaryen `wasm-opt --all-features --validate`.
- The wiki should name all three surfaces explicitly: legacy per-case agreement helper, classified command-harness binary-differential smoke, and compare-pass validation/oracle gates.
- A docs-only wiki run should not rename fields or adapters in code. If the legacy `binaryen_validate` slot is renamed or rewired later, update this bridge, the external-validator adapter page, `fuzz-runner.md`, `validate/fuzz-hardening.md`, and any report-schema consumers together.

## Uncertainty and non-goals

- This note does not judge whether the legacy field name should be changed. It only prevents readers from over-interpreting current evidence.
- External-tool feature defaults remain version-dependent unless the Starshine command line pins explicit feature flags for that surface.
- No new validation run was performed; this was a source and wiki alignment pass.
