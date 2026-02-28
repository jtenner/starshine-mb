# Agent Tasks

## Blockers
- [ ] Re-enable full Binaryen post-pass parity in default optimize scheduling by implementing `dae-optimizing` parity (or safe equivalent) and fixing high-opt inlining argument-mismatch failures; current scheduler intentionally skips those two passes to keep `--optimize` stable.
- [ ] Investage performance issues with `CodeFolding` on large modules
- [ ] Investage performance issues with `PrecomputePropagate` on large modules
- [ ] `RedundantSetElimination` pass aborts
- [ ] Add a no-op wasm copy fast-path in `src/cmd` for empty scheduled pass lists (skip decode+optimize+encode when input format is already wasm) to cut large-module startup latency.
- [ ] Full wasm-target spec sweep (`tests/node/scripts/run-wasm-spec-suite.mjs`) still reports 3 hard failures: `tests/spec/legacy/try_catch.wast`, `tests/spec/local_tee.wast`, `tests/spec/try_table.wast`.
- [ ] `moon test --target wasm` still cannot run directly in this environment (missing default WASI host wiring); only the custom Node/WASI runner path is currently available.
- [ ] Native decode still uses deep recursive control-instruction parsing; `main` now raises stack soft-limit to avoid Linux SIGSEGV, but a recursion-free decoder path is still needed for robust cross-platform behavior.

## Goal
Reach v0.1.0 “production-ready for MoonBit users” by end of March 2026: full native CLI, spec-test passing validator+optimizer, clean public API, and maintainable codebase.

## Scope
- This file tracks open work prioritized for v0.1 release.
- Recently completed items may remain checked until the next audit pass.

## Priority 1 (Release polish)
- [ ] Publish first release + MoonBit registry package (`moon publish` + GitHub Release binaries).
- [ ] Wire `moon test --target wasm` to a reproducible WASI host path (Node/Wasmtime) so wasm tests can run in CI without custom manual runners.
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
- [ ] Diagnose and fix remaining `--optimize` non-zero failure on starshine’s own wasm artifacts so true self-optimized output can replace fallback copy.
- [ ] Resolve the 3 failing wasm spec fixtures in the new Node/WASI runner path (`legacy/try_catch`, `local_tee`, `try_table`).
- [ ] Add a focused `to_texpr` regression fixture for `Stack underflow during tree conversion` on valid large modules and fix stack-polymorphic control-flow handling in `validate/env.mbt`.
- [ ] Add a native regression test for deep nested-control decode (or equivalent non-recursive decoder benchmark fixture) to prevent stack-overflow regressions when `setrlimit` is unavailable.
- [ ] Replace wasm wildcard stub (`wasi_list_candidates`) with directory enumeration via WASI readdir to enable glob expansion under default WASI IO.
- [ ] Audit native FFI wrappers in other packages (for example `src/wast/spec_harness.mbt`) for pointer-width-safe signatures (`FILE*`/`char*`/`size_t`) to prevent similar 32-bit truncation crashes.
- [ ] Profile and optimize `MergeLocals`

## Deferred After v0.1
- [ ] Make `module_to_wast` output reliably parser-consumable in roundtrip tests.
- [ ] Reach `>=75%` line coverage on hot paths (decoder, IR lift, top passes).
- [ ] `Poppify`
- [ ] `Outlining` as a standalone pass (beyond current inlining partial-splitting behavior)
- [ ] Broad Binaryen pass parity backlog (medium/low priority pass list)
- [ ] Large refactors: file splits (`typecheck`/`env`/`transformer`/`optimize`/`remove_unused`/`parser`) and `decode_instruction` helper decomposition
- [ ] Long-horizon platform/features: Component Model/WIT, streaming decoder API, custom sections/source maps, plugin system
- [ ] Replace conservative legacy-exception lowering with semantic-preserving lowering to `try_table`/`throw_ref` (current path is static-validation oriented).
- [ ] Tune/replace `gen_valid_module` candidate generation for harness throughput so fewer candidates are discarded before the 100k valid target.
- [ ] Add `re_reloop` end-to-end coverage for internal loop-target `br_table` cases carrying branch values (non-empty `values`) to lock in typed value-flow behavior.
- [ ] Audit asyncify-generated `MemArg` alignments across all rewritten instruction paths (including non-tail-call entrypoints) and add validator-backed tests per pointer width (`i32`/`i64` memory).
- [ ] Add a shared memarg-alignment helper (`byte width -> alignment exponent`) and migrate pass code that still emits byte-count alignments directly.
- [ ] `DuplicateFunctionElimination` still re-hashes nearly every active body each iteration after the single-remap rewrite; add incremental/cached body fingerprints keyed by canonical callee roots to reduce fixed-point hashing cost on large wasm modules.
- [ ] Profile and optimize `DeadCodeElimination`
- [ ] Profile and optimize `SimplifyLocals`
- [ ] Profile and optimize `MergeBlocks`

