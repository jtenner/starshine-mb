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
- [x] Extend table abbreviation support to additional text forms used in spec files (`(elem func ...)`, typed ref element expressions, and non-zero active offsets where applicable).
- [x] Add an end-to-end `re_reloop` fixture that exercises non-direct `RRBrTable` targets via module reconstruction (not only helper-level CFG tests) and keeps scratch-local insertion covered.
- [x] Add explicit parser/lowering behavior coverage for `(tag (export "...") (import ...))` shorthand (diagnostic or supported lowering), matching `func` shorthand rules.
- [x] Audit downstream optimizer/type-refinement assumptions after `ref.func` now typechecks as non-null `(ref func)` and update notes/tests accordingly.
- [ ] Extend table/elem typed-expression lowering beyond `ref.func` items (`ref.null` and additional typed `item` forms) for full spec `elem.wast`/`table_init*.wast` parity.
- [ ] Update `module_to_wast` table emission for elem-abbreviation offsets/typed items so new parser forms roundtrip without normalization loss.
- [ ] Add stronger end-to-end `re_reloop` assertions for truly internal `RRBrTable` targets once module-level construction can synthesize them directly (helper-level CFG scratch-path coverage already exists).
- [ ] Add CI coverage for native target `cmd/fuzz_harness_test.mbt` so real `wasm-tools`/Binaryen differential checks run in automation (not only wasm-gc tests).
- [x] Consolidate duplicated `RRBrTable` dispatch-building logic in `re_reloop` (dup-safe and scratch-local branches) to reduce divergence/regression risk.
- [x] Decide and document parser behavior for `(func (export "...") (import ...))` shorthand; add explicit parse/lowering diagnostics or support tests.
- [x] Add lowering + validation regression tests for table abbreviation semantics (implicit active elem segment index ordering with explicit `(elem ...)` segments).
- [x] Add direct parser/lowering regression tests for legacy invalid-label diagnostics (`delegate` depth/name targets and `rethrow` catch-depth checks), independent of spec-harness fixtures.
- [ ] Add a lightweight corpus/minimizer flow for fuzz-harness failures (persist failing wasm + seed + pass set for deterministic repro).
- [ ] Tune/replace `gen_valid_module` candidate generation for harness throughput so fewer candidates are discarded before the 100k valid target.
- [ ] Implement full typed-heap value-type modeling in `wast` AST/lowering (`(ref $t)`/`(ref null $t)` to concrete `TypeIdx` refs), replacing current abstract-funcref approximation.
- [x] Add focused tests for `try_table` catch label-depth semantics covering numeric and named labels across nested blocks plus implicit function-return label resolution.
- [x] Add explicit regression tests for inline exports across `func`/`table`/`memory`/`global` fields to lock in the shared inline-export lowering path.
- [ ] Replace conservative legacy-exception lowering with semantic-preserving lowering to `try_table`/`throw_ref` (current path is static-validation oriented).

### Release quality gates
- [x] Add differential testing vs `wasm-tools` / Binaryen.
- [x] Add wasm-smith fuzz harness (`decode -> validate -> optimize -> encode -> roundtrip`).
- [ ] Make `module_to_wast` output reliably parser-consumable in roundtrip tests.
- [ ] Reach `>=75%` line coverage on hot paths (decoder, IR lift, top passes).

## Priority 1 (Release polish)
- [ ] Expand `README.md` with architecture diagram and benchmark table.
- [ ] Add dedicated CLI command examples (`starshine` flags + config + env overlays).
- [ ] Add generated/verified API drift check so README signatures stay in sync with `pkg.generated.mbti`.
- [ ] Add `examples/` directory with real-world snippets.
- [ ] Publish first release + MoonBit registry package (`moon publish` + GitHub Release binaries).

## Deferred After v0.1
- [ ] `Poppify`
- [ ] `Outlining` as a standalone pass (beyond current inlining partial-splitting behavior)
- [ ] Broad Binaryen pass parity backlog (medium/low priority pass list)
- [ ] Large refactors: file splits (`typecheck`/`env`/`transformer`/`optimize`/`remove_unused`/`parser`) and `decode_instruction` helper decomposition
- [ ] Long-horizon platform/features: Component Model/WIT, streaming decoder API, custom sections/source maps, plugin system
