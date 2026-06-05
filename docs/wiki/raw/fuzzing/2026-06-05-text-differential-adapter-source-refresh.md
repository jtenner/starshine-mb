---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-06-05
sources:
  - https://github.com/bytecodealliance/wasm-tools#examples
  - https://github.com/bytecodealliance/wasm-tools#tools-included
  - https://github.com/WebAssembly/wabt#readme
  - ../../../../scripts/lib/fuzz-text-adapters.ts
  - ../../../../scripts/lib/fuzz-text-adapters.test.ts
  - ../../../../src/cmd/fuzz_harness.mbt
  - ../../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../../../src/fuzz/main.mbt
  - ../../../../src/fuzz/main_wbtest.mbt
related:
  - ../../fuzzing/text-differential-adapters.md
  - ../../tooling/fuzz-runner.md
  - ../../fuzzing/recipe-schema.md
  - ../../wast/text-surface-gap-ledger.md
---

# Text Differential Adapter Source Refresh - 2026-06-05

## Why this note exists

The wiki mentioned the opt-in `text-differential` suite and its WABT / `wasm-tools` skip counters, but there was no focused source bridge explaining the two separate implementation layers: the TypeScript optional external adapter scaffold and the MoonBit in-tree smoke suite that currently runs only the Starshine-local parse/print/reparse/lower matrix while reporting external text adapters as unavailable placeholders.

## External primary sources checked

Checked on 2026-06-05:

- The Bytecode Alliance `wasm-tools` README documents `wasm-tools parse foo.wat -o foo.wasm` as the command that converts WebAssembly text to binary, lists `wasm-tools parse` as the `wat` / `wast`-backed text-to-binary subcommand, and notes that text-format support is enabled independently from validation feature defaults.
- The WABT README documents `wat2wasm` as the tool that translates WebAssembly text format to WebAssembly binary format, while WABT's proposal table records that text support and validation support are separate per-feature columns.
- These sources prove command shape and tool-role vocabulary only. They do not prove that a local host has those executables installed, that the MoonBit fuzz runner currently invokes them, or that either external text parser accepts every proposal-local syntax Starshine can parse.

## Starshine repository reconciliation

- [`scripts/lib/fuzz-text-adapters.ts`](../../../../scripts/lib/fuzz-text-adapters.ts) owns the current optional external text-adapter scaffold with schema `starshine.fuzz.text-adapters.v1`, `TextAdapterClassification` values `accepted`, `parse-error`, `unsupported-syntax`, `adapter-unavailable`, and `adapter-error`, WABT invocation through `wat2wasm <case.wat> -o <case.wasm>`, and `wasm-tools` invocation through `wasm-tools parse <case.wat> -o <case.wasm>`.
- [`scripts/lib/fuzz-text-adapters.test.ts`](../../../../scripts/lib/fuzz-text-adapters.test.ts) proves accepted, unavailable, unsupported-syntax, and fake n-way classification behavior with fake executables; it does not require real WABT or `wasm-tools` binaries.
- [`src/cmd/fuzz_harness.mbt`](../../../../src/cmd/fuzz_harness.mbt) owns the MoonBit local matrix and aggregate model: `run_local_text_parse_print_lower_matrix(...)`, `TextAggregateAdapterResult`, `TextAggregateClassification`, `classify_n_way_text_aggregate(...)`, and `persist_text_differential_artifacts(...)`.
- [`src/cmd/fuzz_harness_wbtest.mbt`](../../../../src/cmd/fuzz_harness_wbtest.mbt) locks the local matrix, aggregate classification ladder, and artifact persistence with focused tests.
- [`src/fuzz/main.mbt`](../../../../src/fuzz/main.mbt) owns the runnable `text-differential` suite. It generates tiny deterministic `(module (func (export "answer") ...))` cases, runs the Starshine-local parse/lower/encode/print/reparse/relower/encode equality check, accepts profiles `smoke`, `ci`, and `stress`, and currently reports `external_adapters = ["wabt-unavailable", "wasm-tools-unavailable"]` rather than invoking the TypeScript optional adapter scaffold from MoonBit.
- [`src/fuzz/main_wbtest.mbt`](../../../../src/fuzz/main_wbtest.mbt) proves the suite is opt-in, `text-differential-smoke` is a standard recipe, the suite is not in the default active suite set, and the smoke details include one local stable roundtrip plus two unavailable external-adapter placeholders.

## Durable conclusions

1. Use `text-differential` for Starshine text-surface regression smoke, not as a general external parser conformance gate.
2. Treat WABT and `wasm-tools` text-adapter results as optional evidence. `adapter-unavailable` means skipped evidence, not a parse success/failure.
3. Keep the TypeScript adapter schema and the MoonBit fuzz-suite details separate until a future integration explicitly wires real optional external adapter execution into the MoonBit runner or shared script wrapper.
4. `wasm-tools parse` and WABT `wat2wasm` are text-to-binary tools; they are not the same evidence as `wasm-tools validate`, WABT `wasm-validate`, or Binaryen `wasm-opt --validate` in the binary external-validator adapter guide.
5. If future text-differential runs start comparing broad WAST syntax, feature/proposal disagreements must route through the WAST text-surface gap ledger and the WebAssembly feature-status boundary before being labeled Starshine bugs.

## Follow-up questions

- Should the MoonBit `text-differential` suite grow native optional external command execution, or should the TypeScript adapter scaffold remain a separate script-level helper?
- If external text adapters become runnable in the fuzz suite, should persisted text repro artifacts be emitted by default for parse/print/lower disagreements, or only behind an output directory flag?
- Which WAST surface should be the first nontrivial corpus beyond the current tiny exported-constant module: scalar numeric, ordinary control flow, or a focused gap-ledger family?
