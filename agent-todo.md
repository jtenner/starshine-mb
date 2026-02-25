# Agent Tasks

## Blockers
- `--optimize` currently aborts in `coalesce_locals` for several example modules (`simple.wat`, `feature_mix.wat`, `table_dispatch.wat`, `simd_lane_mix.wat`), so broad optimize-preset example sweeps are not yet reliable.

## Goal
Reach v0.1.0 “production-ready for MoonBit users” by end of March 2026: full native CLI, spec-test passing validator+optimizer, clean public API, and maintainable codebase.

## Scope
- This file tracks open work prioritized for v0.1 release.
- Recently completed items may remain checked until the next audit pass.

## Metadata
- Last updated: `2026-02-25`
- Last audit run: `2026-02-25`

### Follow-up tasks from latest implementation
- [ ] Fix `--optimize`/`coalesce_locals` aborts on representative WAT modules (including `examples/modules/simple.wat`, `feature_mix.wat`, `table_dispatch.wat`, `simd_lane_mix.wat`) and add regression coverage.
- [x] Make native CLI `main` return non-zero exit status when `run_cmd` returns `Err(...)` so CI and scripts fail fast on pipeline errors.
- [x] Extend table/elem typed-expression lowering beyond `ref.func` items (`ref.null` and additional typed `item` forms) for full spec `elem.wast`/`table_init*.wast` parity.
- [x] Update `module_to_wast` table emission for elem-abbreviation offsets/typed items so new parser forms roundtrip without normalization loss.
- [ ] Add stronger end-to-end `re_reloop` assertions for truly internal `RRBrTable` targets once module-level construction can synthesize them directly (helper-level CFG scratch-path coverage already exists).
- [x] Add CI coverage for native target `cmd/fuzz_harness_test.mbt` so real `wasm-tools`/Binaryen differential checks run in automation (not only wasm-gc tests).
- [ ] Implement full typed-heap value-type modeling in `wast` AST/lowering (`(ref $t)`/`(ref null $t)` to concrete `TypeIdx` refs), replacing current abstract-funcref approximation.
- [ ] Preserve explicit typed-element intent in lowering when all init expressions are `ref.func` (currently canonicalized to legacy `funcs` element kind).
- [ ] Add workflow caching for `cargo install wasm-tools --locked` in native CI to reduce cold-start runtime.


### Release quality gates
- [ ] Make `module_to_wast` output reliably parser-consumable in roundtrip tests.
- [ ] Reach `>=75%` line coverage on hot paths (decoder, IR lift, top passes).

## Priority 1 (Release polish)
- [ ] Publish first release + MoonBit registry package (`moon publish` + GitHub Release binaries).

## Deferred After v0.1
- [ ] `Poppify`
- [ ] `Outlining` as a standalone pass (beyond current inlining partial-splitting behavior)
- [ ] Broad Binaryen pass parity backlog (medium/low priority pass list)
- [ ] Large refactors: file splits (`typecheck`/`env`/`transformer`/`optimize`/`remove_unused`/`parser`) and `decode_instruction` helper decomposition
- [ ] Long-horizon platform/features: Component Model/WIT, streaming decoder API, custom sections/source maps, plugin system
- [ ] Replace conservative legacy-exception lowering with semantic-preserving lowering to `try_table`/`throw_ref` (current path is static-validation oriented).
- [ ] Tune/replace `gen_valid_module` candidate generation for harness throughput so fewer candidates are discarded before the 100k valid target.
