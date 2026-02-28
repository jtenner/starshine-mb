# Agent Tasks

## Goal
Reach v0.1.0 "production-ready for MoonBit users" by end of March 2026: full native CLI, spec-test passing validator+optimizer, clean public API, and maintainable codebase.

## Scope
- This file tracks open work split into publishing blockers and post-0.1.0 follow-up.
- Items are ordered highest priority first within each section.
- Recent completed items are retained at the bottom until the next audit pass.

## Publishing blockers
- [ ] Diagnose and fix the remaining `--optimize` non-zero failure on Starshine's own wasm artifacts so true self-optimized output can replace the fallback copy.
- [ ] Resolve the 3 failing wasm spec fixtures in the Node/WASI runner path (`tests/spec/legacy/try_catch.wast`, `tests/spec/local_tee.wast`, `tests/spec/try_table.wast`).
- [ ] Add a focused `to_texpr` regression fixture for `Stack underflow during tree conversion` on valid large modules and fix stack-polymorphic control-flow handling in `validate/env.mbt`.
- [ ] Wire `moon test --target wasm` to a reproducible WASI host path (Node/Wasmtime) so wasm tests can run in CI without custom manual runners.
- [ ] Replace the wasm wildcard stub (`wasi_list_candidates`) with directory enumeration via WASI readdir so glob expansion works under default WASI I/O.
- [ ] Re-enable full Binaryen post-pass parity in default optimize scheduling by implementing `dae-optimizing` parity (or a safe equivalent) and fixing high-opt inlining argument-mismatch failures; the current scheduler intentionally skips those two passes to keep `--optimize` stable.
- [ ] Fix the `RedundantSetElimination` pass abort.
- [ ] Replace deep-recursive native decode with a recursion-free control-instruction path for robust cross-platform behavior when `setrlimit` is unavailable.
- [ ] Add a native regression test for deep nested-control decode (or an equivalent non-recursive decoder benchmark fixture) to prevent stack-overflow regressions.
- [ ] Audit native FFI wrappers in other packages (for example `src/wast/spec_harness.mbt`) for pointer-width-safe signatures (`FILE*`/`char*`/`size_t`) to prevent similar 32-bit truncation crashes.
- [ ] Add a no-op wasm copy fast-path in `src/cmd` for empty scheduled pass lists so wasm input can skip decode+optimize+encode when no optimization work is requested.
- [ ] Publish the first release and MoonBit registry package (`moon publish` plus GitHub Release binaries).

## Post 0.1.0 Features
- [ ] Add a JS-friendly `Name` construction path in the Node API (for example `Name.fromString(...)` or an equivalent `StringView` bridge) so exports/custom sections can be authored from scratch without opaque handle hacks.
- [ ] Add JS-facing constructors/helpers for immediate wrapper types that are currently read-only in the Node API (`I32`, `I64`, `U32`, `U64`, and any other literal/index wrappers needed by instruction/module builders).
- [ ] Add any missing JS-facing constructors/helpers for typed block/result wrappers used by the structural builders (for example `ResultType` if it remains required by nontrivial block construction).
- [ ] Add a published Node example that constructs a nontrivial WebAssembly module from scratch via `lib` builders, including at least one exported function, then validates and encodes it.
- [ ] Add Node smoke/example coverage for the from-scratch module-construction path so the builder surface stays usable after future generator/runtime changes.
- [ ] Make `moduleToWast` output reliably parser-consumable in roundtrip tests.
- [ ] Reach `>=75%` line coverage on hot paths (decoder, IR lift, top passes).
- [ ] Investigate performance issues with `CodeFolding` on large modules.
- [ ] Investigate performance issues with `PrecomputePropagate` on large modules.
- [ ] Profile and optimize `MergeLocals`.
- [ ] Profile and optimize `DeadCodeElimination`.
- [ ] Profile and optimize `SimplifyLocals`.
- [ ] Profile and optimize `MergeBlocks`.
- [ ] Add incremental or cached body fingerprints to `DuplicateFunctionElimination` so it does not re-hash nearly every active body each iteration on large modules.
- [ ] Add a shared memarg-alignment helper (`byte width -> alignment exponent`) and migrate pass code that still emits byte-count alignments directly.
- [ ] Audit asyncify-generated `MemArg` alignments across all rewritten instruction paths (including non-tail-call entrypoints) and add validator-backed tests per pointer width (`i32`/`i64` memory).
- [ ] Add `re_reloop` end-to-end coverage for internal loop-target `br_table` cases carrying branch values (non-empty `values`) to lock in typed value-flow behavior.
- [ ] Tune or replace `gen_valid_module` candidate generation for harness throughput so fewer candidates are discarded before the 100k valid target.
- [ ] Replace conservative legacy-exception lowering with semantic-preserving lowering to `try_table`/`throw_ref` (the current path is static-validation oriented).
- [ ] `Poppify`.
- [ ] `Outlining` as a standalone pass (beyond current inlining partial-splitting behavior).
- [ ] Broad Binaryen pass parity backlog (medium/low priority pass list).
- [ ] Large refactors: file splits (`typecheck`/`env`/`transformer`/`optimize`/`remove_unused`/`parser`) and `decode_instruction` helper decomposition.
- [ ] Long-horizon platform/features: Component Model/WIT, streaming decoder API, custom sections/source maps, plugin system.

## Recently Completed
- [x] Remove `src/cmd/moon.pkg` unused-package warnings for non-WASI targets (split target-specific package wiring or conditional package structure).
- [x] Scaffold `tests/node/` npm package with scripts that bootstrap `moon build --target wasm --release` and stage the optimized wasm artifact.
- [x] Ignore `wasm-gc` in npm wasm packaging flow (package scripts use `--target wasm --release` only).
- [x] Stage both wasm artifacts in `tests/node/dist` (`starshine-debug-wasi.wasm`, `starshine-optimized-wasi.wasm`) and generate `starshine-self-optimized-wasi.wasm` via Starshine with failure diagnostics.
- [x] Add Node/Bun bootstrap runner for wasm artifacts (`tests/node/scripts/bootstrap-optimized.mjs`) with WASI + `__moonbit_fs_unstable` host shims.
- [x] Add wasm-target spec-suite launcher (`tests/node/scripts/run-wasm-spec-suite.mjs`) backed by `src/spec_runner` wasm package.
- [x] Add optimized-vs-self-optimized artifact comparison pipeline/report (`tests/node/dist/compare.report.json`) with blocker diagnostics when optimizer fails.
- [x] Fix optimizer crash (`SIGSEGV`) so `tests/node` no longer fails with signal 11 when optimizing release wasm modules.
- [x] Make native release CLI buildable again (target-specific dependency split for WASI imports in cmd package) so npm packaging can rebuild optimizer binary deterministically.
- [x] Print `CmdError` diagnostics to stderr on non-zero CLI exits to make optimizer failures actionable in CI scripts.
- [x] Decode/encode elem segment header `6` with explicit reftype payloads so self-hosted wasm artifacts no longer fail early with `DecodeAt(InvalidInstruction, ...)`.
- [x] Raise native process stack soft limit to hard limit at startup to avoid deep-decode SIGSEGV on large self-hosted modules.
