# Agent Tasks

## Blockers
- None currently.

## Goal
Reach v0.1.0 “production-ready for MoonBit users” by end of March 2026: full native CLI, spec-test passing validator+optimizer, clean public API, and maintainable codebase.

## Scope
- This file tracks open work prioritized for v0.1 release.
- Recently completed items may remain checked until the next audit pass.

## Metadata
- Last updated: `2026-02-25`
- Last audit run: `2026-02-25`

### Follow-up tasks from latest implementation
- [x] Fix `--optimize`/`coalesce_locals` aborts on representative WAT modules (including `examples/modules/simple.wat`, `feature_mix.wat`, `table_dispatch.wat`, `simd_lane_mix.wat`) and add regression coverage.
- [x] Extend in-process text-lowering bridge SIMD opcode coverage (for example `i8x16.add`) so `run_cmd_with_adapter` WAT fallback can lower SIMD fixtures without injected pre-lowered wasm.
- [x] Extend text-lowering bridge SIMD no-immediate opcode mapping beyond `i8x16.*` to cover `i16x8.*`, `i32x4.*`, `i64x2.*`, `f32x4.*`, and `f64x2.*` families routed through `wt_numeric_noarg`.
- [x] Add bridge-level regression tests for relaxed SIMD no-immediate opcodes (`i8x16.relaxed_swizzle`, `f32x4.relaxed_madd`, `i16x8.relaxed_dot_i8x16_i7x16_s`, etc.) to lock parser/lowering parity.
- [x] Add bridge-level assertions for representative non-`i8x16` and relaxed SIMD opcodes that verify exact lowered `@lib.Instruction` constructors, not only lowering success.
- [x] Make native CLI `main` return non-zero exit status when `run_cmd` returns `Err(...)` so CI and scripts fail fast on pipeline errors.
- [x] Extend table/elem typed-expression lowering beyond `ref.func` items (`ref.null` and additional typed `item` forms) for full spec `elem.wast`/`table_init*.wast` parity.
- [x] Update `module_to_wast` table emission for elem-abbreviation offsets/typed items so new parser forms roundtrip without normalization loss.
- [x] Add stronger end-to-end `re_reloop` assertions for truly internal `RRBrTable` targets once module-level construction can synthesize them directly (helper-level CFG scratch-path coverage already exists).
- [x] Add CI coverage for native target `cmd/fuzz_harness_test.mbt` so real `wasm-tools`/Binaryen differential checks run in automation (not only wasm-gc tests).
- [x] Implement full typed-heap value-type modeling in `wast` AST/lowering (`(ref $t)`/`(ref null $t)` to concrete `TypeIdx` refs), replacing current abstract-funcref approximation.
- [x] Extend `wast` heap-type modeling beyond typed `TypeIdx` refs to preserve non-func abstract heap kinds (`any`, `eq`, `i31`, `none`, `nofunc`, `noextern`, `noexn`) instead of defaulting to `func` in value-type lowering/printing paths.
- [x] Add `wast` roundtrip/lowering coverage for abstract heap refs in table/global/tag/import surface areas (not only function signatures and `ref.null` instructions).
- [x] Preserve explicit typed-element intent in lowering when all init expressions are `ref.func` (currently canonicalized to legacy `funcs` element kind).
- [x] Add workflow caching for `cargo install wasm-tools --locked` in native CI to reduce cold-start runtime.
- [x] Add a CI workflow contract/lint check that asserts native CI keeps `wasm-tools` cache + guarded install wiring intact.


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
- [ ] Add `re_reloop` end-to-end coverage for internal loop-target `br_table` cases carrying branch values (non-empty `values`) to lock in typed value-flow behavior.
