---
kind: raw-source
status: current
last_reviewed: 2026-06-04
sources:
  - https://www.st.cs.uni-saarland.de/papers/tse2002/
  - https://github.com/csmith-project/creduce
  - https://github-wiki-see.page/m/WebAssembly/binaryen/wiki/Fuzzing
  - https://github.com/WebAssembly/binaryen
  - https://codebrowser.dev/dart_sdk/dart_sdk/third_party/binaryen/src/src/tools/wasm-reduce.cpp.html
  - ../../../fuzzing/reduction-backends.md
  - ../../../../scripts/lib/fuzz-reducers.ts
  - ../../../../scripts/test/fuzz-reducers.ts
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../scripts/test/pass-fuzz-compare-command.ts
  - ../../../../src/cmd/fuzz_harness.mbt
  - ../../../../src/fuzz/invalid_repro.mbt
related:
  - ../../../fuzzing/reduction-backends.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../validate/diagnostics-and-invalid-repro.md
---

# Reduction Backends Source Refresh (2026-06-04)

## Why this note exists

The living reducer page had grown by appended `[FUZ]1043*` slices, but it did not yet explain the shared model behind Starshine's script-side reducers, Moon command-harness reducers, invalid-fuzz shrinkers, and pass-fuzz mismatch artifacts. This refresh grounds that model in primary/high-quality reduction sources and current repository evidence.

## External source refresh

Checked on 2026-06-04:

- Zeller and Hildebrandt's delta-debugging paper page remains the primary academic source for automated simplification and isolation of failure-inducing input. Its durable lesson for Starshine is that a reducer repeatedly tests changed candidates and keeps only candidates that preserve the chosen failure condition; the reducer does not decide the failure condition by itself.
- C-Reduce's current repository describes the same practical contract in compiler-reducer terms: start from a large program with a property of interest, run an external interestingness test, and keep a smaller program with the same property. Its README also calls out that tests run in fresh temporary directories, so predicates must either copy required support files or use absolute paths.
- Binaryen's fuzzing wiki and `wasm-reduce` source give the WebAssembly-specific shape: reduction preserves a command's observable result, `wasm-reduce` is strongest on parseable valid wasm because it can use module structure, and Binaryen interleaves destructive shrinking with optimizer-pass shrinking to make large wasm reductions faster.
- Binaryen's README still presents `wasm-reduce` as a testcase reducer for wasm files; this is a useful orientation source, but Starshine's concrete artifact schema comes from local code.

## Starshine local evidence

- `scripts/lib/fuzz-reducers.ts` exposes predicate-only deletion reducers for module fields, bytes, text tokens, and text lines. Each has a report-returning variant with original/final sizes, predicate-evaluation count, and deletion-step metadata, plus compatibility wrappers that return only the reduced artifact.
- `scripts/lib/fuzz-reducers.ts` also owns `formatReductionReportLog(...)` and `parseReductionReportLog(...)`, the script-side `key=value` / `step=...` shrink-log schema.
- `scripts/test/fuzz-reducers.ts` proves byte, token, line, and module-field reducers preserve the caller predicate, leave inputs unchanged when no deletion reproduces, and roundtrip shrink logs including custom artifact-path keys.
- `src/cmd/fuzz_harness.mbt` exposes the Moon-side deletion loop plus byte, token, and WAST-module-field adapters. It also attaches `FuzzReductionStep` / `FuzzReductionReport` metadata to command-harness artifacts.
- `src/fuzz/invalid_repro.mbt` stores invalid-fuzz reduced artifacts, reduction sizes, predicate-evaluation counts, deletion steps, metadata fields, and `reduction.txt` logs beside the original repro artifact.
- `scripts/lib/pass-fuzz-compare-task.ts` attempts byte-slice reduction for fresh `gen-valid` compare-pass mismatches and writes `reduced-input.wasm`, `reduction.txt`, and a `reduction` block in `failure-metadata.json` without replacing the original `input.wasm` replay artifact.

## Durable conclusions

1. Treat reducers as **predicate preservers**, not semantic judges. The caller owns validation, replay, oracle comparison, crash detection, or diagnostic-family matching.
2. Keep the original artifact immutable. Reduced artifacts are aids for debugging and corpus triage; replay defaults must continue to identify the original input unless an operator explicitly chooses the reduced input.
3. Record shrink evidence in both machine-readable metadata and human-readable logs: original size, final size, predicate evaluations, and ordered deletion steps.
4. Use the narrowest structural unit that is safe for the caller's predicate: module fields before tokens for WAST modules, tokens before bytes for text, bytes for opaque wasm mismatch repros, and lines for log/manifest-like artifacts.
5. Do not overclaim Binaryen-style `wasm-reduce` parity. Starshine's current reducers are simple deletion backends; they do not yet do parse-aware wasm instruction rewrites, optimizer-pass interleaving, or all-valid-wasm structural minimization.
6. Reducer predicates must be deterministic and side-effect aware. If a predicate depends on support files or environment state, preserve those inputs explicitly; otherwise a candidate can be kept or rejected for the wrong reason.
