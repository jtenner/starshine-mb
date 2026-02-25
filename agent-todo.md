# Agent Tasks

## Blockers
- [ ] `cmd.exe --optimize` still exits with non-zero status (`status=1`) on both `node_wasm/dist/starshine.release.wasm` and `node_wasm/dist/starshine.debug.wasm`; current `starshine.self-optimized.wasm` is a debug-copy fallback written after optimizer failure.
- [ ] Full wasm-target spec sweep (`node_wasm/scripts/run-wasm-spec-suite.mjs`) still reports 3 hard failures: `tests/spec/legacy/try_catch.wast`, `tests/spec/local_tee.wast`, `tests/spec/try_table.wast`.
- [ ] `moon test --target wasm` still cannot run directly in this environment (missing default WASI host wiring); only the custom Node/WASI runner path is currently available.
- [ ] CLI non-zero exits currently suppress `CmdError` details in native `main`, which blocks fast diagnosis of release optimization failures.

## Goal
Reach v0.1.0 “production-ready for MoonBit users” by end of March 2026: full native CLI, spec-test passing validator+optimizer, clean public API, and maintainable codebase.

## Scope
- This file tracks open work prioritized for v0.1 release.
- Recently completed items may remain checked until the next audit pass.

## Priority 1 (Release polish)
- [ ] Publish first release + MoonBit registry package (`moon publish` + GitHub Release binaries).
- [ ] Wire `moon test --target wasm` to a reproducible WASI host path (Node/Wasmtime) so wasm tests can run in CI without custom manual runners.
- [x] Remove `src/cmd/moon.pkg` unused-package warnings for non-WASI targets (split target-specific package wiring or conditional package structure).
- [x] Scaffold `node_wasm/` npm package with scripts that bootstrap `moon build --target wasm --release` and stage the release wasm artifact.
- [x] Ignore `wasm-gc` in npm wasm packaging flow (package scripts use `--target wasm --release` only).
- [x] Stage both wasm artifacts in `node_wasm/dist` (`starshine.debug.wasm`, `starshine.release.wasm`) and generate `starshine.self-optimized.wasm` via Starshine with failure diagnostics.
- [x] Add Node/Bun bootstrap runner for wasm artifacts (`node_wasm/scripts/bootstrap-optimized.mjs`) with WASI + `__moonbit_fs_unstable` host shims.
- [x] Add wasm-target spec-suite launcher (`node_wasm/scripts/run-wasm-spec-suite.mjs`) backed by `src/spec_runner` wasm package.
- [x] Add release-vs-optimized artifact comparison pipeline/report (`node_wasm/dist/compare.report.json`) with blocker diagnostics when optimizer fails.
- [x] Fix optimizer crash (`SIGSEGV`) so `node_wasm` no longer fails with signal 11 when optimizing release wasm modules.
- [x] Make native release CLI buildable again (target-specific dependency split for WASI imports in cmd package) so npm packaging can rebuild optimizer binary deterministically.
- [ ] Diagnose and fix remaining `--optimize` non-zero failure on starshine’s own wasm artifacts so true self-optimized output can replace fallback copy.
- [ ] Resolve the 3 failing wasm spec fixtures in the new Node/WASI runner path (`legacy/try_catch`, `local_tee`, `try_table`).
- [ ] Print `CmdError` diagnostics to stderr on non-zero CLI exits to make optimizer failures actionable in CI scripts.
- [ ] Replace wasm wildcard stub (`wasi_list_candidates`) with directory enumeration via WASI readdir to enable glob expansion under default WASI IO.
- [ ] Decide whether `wasm-gc` should share WASI default IO with `wasm` or remain an explicit non-WASI fallback, then codify with target-specific tests.
- [ ] Add CI coverage for `npm --prefix node_wasm run build:all` and `npm --prefix node_wasm run test:spec:wasm -- --limit <smoke>` to prevent packaging regressions.
- [ ] Audit native FFI wrappers in other packages (for example `src/wast/spec_harness.mbt`) for pointer-width-safe signatures (`FILE*`/`char*`/`size_t`) to prevent similar 32-bit truncation crashes.

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
