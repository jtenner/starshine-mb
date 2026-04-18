# Wasm Knowledge Base Index

This is the human-readable catalog for living wiki pages under `docs/wiki/`. Update it whenever a durable page is added, renamed, merged, or substantially reframed.

## Schema And Operations

- [`../../AGENTS.md`](../../AGENTS.md) - Short operational contract for repo work and wiki maintenance.
- [`../README.md`](../README.md) - Canonical docs and wiki schema for this repo.
- [`raw/README.md`](raw/README.md) - Rules for committed raw sources.
- [`raw/research/README.md`](raw/research/README.md) - Rules for the archived numbered research notes moved out of `docs/`.

## Concepts

- [`ir2/architecture-rules.md`](ir2/architecture-rules.md) - Single-owned `HotFunc` contract, overlay model, and module-split rule for IR2.
- [`binaryen/no-dwarf-default-optimize-path.md`](binaryen/no-dwarf-default-optimize-path.md) - Canonical phase split, ordered pass path, and nested rerun rules for Binaryen's no-DWARF `-O` / `-Os` optimize pipeline on the MoonBit debug artifact.
- [`binaryen/passes/late-pipeline-dispatch.md`](binaryen/passes/late-pipeline-dispatch.md) - Compact `-O4z` / `shrink` tail roster, ordered generated-artifact audit summary, and 2026-04-18 non-GitHub Binaryen terminology plus trunk-drift check, now including direct Debian manpage confirmation for `--heap-store-optimization` / `--remove-unused-brs`, the March 2026 `Precompute` GC-write drift, and the `version_126` upstream pass additions that are still outside Starshine's implemented subset.
- [`binaryen/passes/duplicate-function-elimination/wat-shapes.md`](binaryen/passes/duplicate-function-elimination/wat-shapes.md) - Module and WAT shapes that create DFE merge candidates, rewrites, transitive unlocks, and deliberate non-merges.
- [`binaryen/passes/duplicate-function-elimination/binaryen-strategy.md`](binaryen/passes/duplicate-function-elimination/binaryen-strategy.md) - Upstream `version_129` DFE strategy: hash buckets, option-dependent iteration budget, and whole-module rewrite behavior.
- [`binaryen/passes/duplicate-function-elimination/starshine-hot-ir-strategy.md`](binaryen/passes/duplicate-function-elimination/starshine-hot-ir-strategy.md) - Current in-tree Starshine strategy for DFE, including the explicit reason it stays a module pass instead of a HOT-IR pass.
- [`binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md`](binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md) - DFE-specific rules for simple-type compaction, name handling, annotation-map rewrites, and compact element forms.
- [`binaryen/passes/simplify-locals/wat-shapes.md`](binaryen/passes/simplify-locals/wat-shapes.md) - Exact WAT families that `simplify-locals` rewrites, preserves, or intentionally declines, including the maintained negative cases.
- [`binaryen/passes/simplify-locals/binaryen-strategy.md`](binaryen/passes/simplify-locals/binaryen-strategy.md) - Upstream staged sink, invalidation, equivalent-copy cleanup, and no-DWARF ordering rules for `simplify-locals`.
- [`binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md`](binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md) - Current no-structure-first HOT-IR and raw-lane port strategy for `simplify-locals`.
- [`binaryen/passes/simplify-locals/implementation-map.md`](binaryen/passes/simplify-locals/implementation-map.md) - Concrete map from the simplify-locals dossier to the owning helper clusters, pass-manager entry points, and test files in tree.
- [`binaryen/passes/simplify-locals/effect-ordering-and-barriers.md`](binaryen/passes/simplify-locals/effect-ordering-and-barriers.md) - The exact commutation and barrier model that decides when pending local values may still move.
- [`binaryen/passes/simplify-locals/raw-lane-and-writeback.md`](binaryen/passes/simplify-locals/raw-lane-and-writeback.md) - The raw exact rewrite lane, raw skip families, and post-lower exact cleanup boundary for `simplify-locals`.
- [`binaryen/passes/simplify-locals/validation-and-signoff.md`](binaryen/passes/simplify-locals/validation-and-signoff.md) - Detailed test-lane guide for reduced pass tests, whitebox raw tests, fuzz parity, and artifact replay.
- [`binaryen/passes/remove-unused-module-elements/wat-shapes.md`](binaryen/passes/remove-unused-module-elements/wat-shapes.md) - Module layouts and instruction carriers that determine imported-parent retention, active-segment liveness, and survivor remaps for RUME.
- [`binaryen/passes/remove-unused-module-elements/binaryen-strategy.md`](binaryen/passes/remove-unused-module-elements/binaryen-strategy.md) - Upstream `version_129` RUME strategy: three-state liveness, module-wide reachability, and more than just dead-function removal.
- [`binaryen/passes/remove-unused-module-elements/starshine-hot-ir-strategy.md`](binaryen/passes/remove-unused-module-elements/starshine-hot-ir-strategy.md) - Current in-tree Starshine strategy for RUME and why it remains a module pass instead of a HOT-IR pass.
- [`binaryen/passes/remove-unused-module-elements/retention-and-index-rewrites.md`](binaryen/passes/remove-unused-module-elements/retention-and-index-rewrites.md) - Concrete rewrite surface for surviving func, global, table, memory, tag, elem, data, name, and annotation indices in RUME.
- [`binaryen/passes/tuple-optimization/wat-shapes.md`](binaryen/passes/tuple-optimization/wat-shapes.md) - Exact tuple-like raw-WAT and reduced HOT-native bridge families that should rewrite, the deliberate bailouts, and why each family matters.
- [`binaryen/passes/tuple-optimization/binaryen-strategy.md`](binaryen/passes/tuple-optimization/binaryen-strategy.md) - Upstream `version_129` tuple-local strategy: use counting, valid-use filtering, badness propagation, and tee-preserving scalar-local rewrites.
- [`binaryen/passes/tuple-optimization/starshine-hot-ir-strategy.md`](binaryen/passes/tuple-optimization/starshine-hot-ir-strategy.md) - Current in-tree HOT-native tuple-opt algorithm: seed collection, copy-group linking, rewrite suppression, carrier construction, and cleanup.
- [`binaryen/passes/tuple-optimization/scheduler-and-gates.md`](binaryen/passes/tuple-optimization/scheduler-and-gates.md) - Exact Binaryen slot and multivalue gate, plus the current reason Starshine keeps tuple-opt off public presets.
- [`binaryen/passes/remove-unused-brs/pattern-catalog.md`](binaryen/passes/remove-unused-brs/pattern-catalog.md) - Exhaustive inventory of every raw skip, HOT rewrite, preservation rule, and detailed family page for `remove-unused-brs`.
- [`binaryen/passes/remove-unused-brs/binaryen-strategy.md`](binaryen/passes/remove-unused-brs/binaryen-strategy.md) - Upstream `RemoveUnusedBrs` phase model: flow cleanup, loop/block reshaping, and late optimizer cleanup.
- [`binaryen/passes/remove-unused-brs/starshine-hot-ir-strategy.md`](binaryen/passes/remove-unused-brs/starshine-hot-ir-strategy.md) - Current in-tree Starshine execution model for RUB, including the raw fast path, HOT fixpoint, and structural guards.
- [`binaryen/passes/remove-unused-brs/tail-and-return-cleanups.md`](binaryen/passes/remove-unused-brs/tail-and-return-cleanups.md) - Detailed rules for stripping redundant tail exits, cleaning return context, voidifying exit-only tails, and trimming trailing `nop`.
- [`binaryen/passes/remove-unused-brs/select-and-condition-rewrites.md`](binaryen/passes/remove-unused-brs/select-and-condition-rewrites.md) - Detailed rules for value-`if` to `select`, condition-child rewrites, nested condition folding, and `br_table` ladders.
- [`binaryen/passes/remove-unused-brs/branch-exit-and-payload-rewrites.md`](binaryen/passes/remove-unused-brs/branch-exit-and-payload-rewrites.md) - Detailed rules for `br_if`, local-set arm cleanup, payload-branch rewrites, suffix restructuring, and block-local chain flattening.
- [`binaryen/passes/remove-unused-brs/carried-guards-and-result-blocks.md`](binaryen/passes/remove-unused-brs/carried-guards-and-result-blocks.md) - Detailed rules for carried guards, result-block wrappers, `br_table` continuation wrappers, prefix payload branches, and deliberate parity-preserved carriers.
- [`binaryen/passes/remove-unused-brs/returned-ladder-hot-shapes.md`](binaryen/passes/remove-unused-brs/returned-ladder-hot-shapes.md) - Lifted HOT shape guide for the remaining returned-ladder `remove-unused-brs` families.
- [`binaryen/passes/remove-unused-brs/visit-order-and-bailouts.md`](binaryen/passes/remove-unused-brs/visit-order-and-bailouts.md) - Raw/hot skip rules, visit order, fixpoint limits, and analysis-cost controls for RUB.
- [`custom-descriptors/static-fixtures.md`](custom-descriptors/static-fixtures.md) - Native static-harness policy and validator lessons for `descriptors.wast` and `exact.wast`.
- [`custom-descriptors/ref-get-desc-fixture-path.md`](custom-descriptors/ref-get-desc-fixture-path.md) - The full-stack parser, lowering, exactness, and bottom-null rules needed to keep `ref_get_desc.wast` green.
- [`custom-descriptors/exact-reference-equivalence.md`](custom-descriptors/exact-reference-equivalence.md) - Exact-reference rule: structural closure equivalence for exact struct and function refs, plus the passive typed `elem` front-end surface used by `exact.wast`.
- [`ir2/execution-plan.md`](ir2/execution-plan.md) - Current IR2 handoff contract, active registry surface, and preferred next slice order for future pass migration.
- [`ir2/pass-porting-checklist.md`](ir2/pass-porting-checklist.md) - Shared helper rules, mutation discipline, and validation floor for porting passes onto the IR2 pipeline.
- [`ir2/registry-map.md`](ir2/registry-map.md) - Current live pass registry categories, preset composition, and the caveat that the original March batch map is now partially stale.
- [`ir2/test-matrix.md`](ir2/test-matrix.md) - Shared helper and golden matrix for deterministic IR2 lift, analysis, lowering, and pass-trace coverage.
- [`strings/string-const-surface.md`](strings/string-const-surface.md) - Public surface, binary string-literal section, constant-expression rule, and IR payload handling for `string.const`.
- [`tooling/fuzz-runner.md`](tooling/fuzz-runner.md) - Repo rule that heavy fuzz belongs in `src/fuzz`, with reusable suite/profile/seed workflow, the fully-active validator rejection suite inventory, and the now-aligned Moon/Bun discovery plus `--emit-gen-valid-batch` surfaces.
- [`tooling/cli-startup-path.md`](tooling/cli-startup-path.md) - Compact CLI startup audit: the old registry/help/config concerns are closed, and path normalization remains the live follow-up.
- [`tooling/tracing-playbook.md`](tooling/tracing-playbook.md) - Shared `key=value` trace contract, timing helper use, hotspot summaries, and the no-trace-only-tests rule.
- [`validation/moonbit-prove-strategy.md`](validation/moonbit-prove-strategy.md) - Current `moon prove` toolchain facts, the `9`-goal `src/validate_proof` helper kernel, and the blocker on proving `src/validate` directly.
- [`validate/fuzz-hardening.md`](validate/fuzz-hardening.md) - Current validator fuzz surface truth, including the live AST, binary, text, and spec-seed invalid suites, the shared invalid repro persistence/replay/shrinking surface, the aligned Moon/Bun runner contract, and the now-closed downstream `RUME` imported-function plus no-op `start`-section parity families exposed by widened `gen-valid` coverage.
- [`wast/gc-type-authoring.md`](wast/gc-type-authoring.md) - Higher-level WAST support for GC type defs, `rec` groups, descriptor metadata, and flat type indexing after grouped entries.

## Entities

- [`binaryen/passes/index.md`](binaryen/passes/index.md) - Namespace catalog for all active implemented Binaryen pass folders and their current documentation status, with an explicit boundary between Starshine's implemented subset and newer upstream-only Binaryen passes.
- [`binaryen/passes/duplicate-function-elimination/index.md`](binaryen/passes/duplicate-function-elimination/index.md) - Hub page for DFE overview, shapes, strategy pages, metadata rules, and parity status.
- [`binaryen/passes/simplify-locals/index.md`](binaryen/passes/simplify-locals/index.md) - Hub page for simplify-locals overview, shapes, strategies, implementation map, validation, performance, and parity.
- [`binaryen/passes/remove-unused-module-elements/index.md`](binaryen/passes/remove-unused-module-elements/index.md) - Hub page for RUME overview, shapes, strategy pages, retention rules, and parity status.
- [`binaryen/passes/reorder-locals/index.md`](binaryen/passes/reorder-locals/index.md) - Folder now has a landing page plus parity and multivalue-call scope notes.
- [`binaryen/passes/ssa-nomerge/index.md`](binaryen/passes/ssa-nomerge/index.md) - Folder now has a landing page plus the current parity note for the fixed dead-param family and residual in-tree skip classification.
- [`binaryen/passes/tuple-optimization/index.md`](binaryen/passes/tuple-optimization/index.md) - Hub page for tuple-opt overview, shapes, strategies, scheduler notes, reduced repros, and parity status.
- [`binaryen/passes/dead-code-elimination/index.md`](binaryen/passes/dead-code-elimination/index.md) - Active hot-pass landing page; notes the current Binaryen `Dce` naming alignment until strategy pages land.
- [`binaryen/passes/global-refining/index.md`](binaryen/passes/global-refining/index.md) - Active module-pass landing page; now also records the current non-GitHub `--global-refining` terminology sanity check.
- [`binaryen/passes/global-struct-inference/index.md`](binaryen/passes/global-struct-inference/index.md) - Folder now has a landing page plus the existing parity note.
- [`binaryen/passes/heap-store-optimization/index.md`](binaryen/passes/heap-store-optimization/index.md) - Active hot-pass landing page; now also records the direct Debian manpage plus `wasm_opt::Pass` evidence for the current `HeapStoreOptimization` terminology.
- [`binaryen/passes/heap2local/index.md`](binaryen/passes/heap2local/index.md) - Folder now has a landing page plus the current parity note.
- [`binaryen/passes/memory-packing/index.md`](binaryen/passes/memory-packing/index.md) - Active module-pass landing page; now also records the current non-GitHub `--memory-packing` terminology sanity check.
- [`binaryen/passes/once-reduction/index.md`](binaryen/passes/once-reduction/index.md) - Active module-pass landing page; now also records the current non-GitHub `--once-reduction` terminology sanity check.
- [`binaryen/passes/optimize-instructions/index.md`](binaryen/passes/optimize-instructions/index.md) - Active hot-pass landing page; see the landing page until strategy pages land.
- [`binaryen/passes/pick-load-signs/index.md`](binaryen/passes/pick-load-signs/index.md) - Folder now has a landing page plus the current parity note.
- [`binaryen/passes/precompute/index.md`](binaryen/passes/precompute/index.md) - Active hot-pass landing page; records the current `precompute` versus `precompute-propagate` alias boundary plus the newer upstream child-retention, March 2026 GC-write handling, GC-atomic no-fold, and multibyte-array `array.load` no-fold drift notes until strategy pages land.
- [`binaryen/passes/remove-unused-brs/index.md`](binaryen/passes/remove-unused-brs/index.md) - Hub page for RUB overview, shape catalog, strategies, bailout notes, the retired slot-14 large-condition guard, and current parity status.
- [`binaryen/passes/remove-unused-names/index.md`](binaryen/passes/remove-unused-names/index.md) - Folder now has a landing page plus the current parser-gap note.
- [`binaryen/passes/vacuum/index.md`](binaryen/passes/vacuum/index.md) - Active hot-pass landing page; records the paired ordered-slot blockers plus the newer upstream `unreachable`-preservation note until strategy pages land.

## Decisions

- [`binaryen/passes/reorder-locals/multivalue-call-scope.md`](binaryen/passes/reorder-locals/multivalue-call-scope.md) - Current project decision: non-converging Binaryen multivalue-call writeback stays out of scope for `reorder-locals` parity.
- [`ir2/cfg-contract.md`](ir2/cfg-contract.md) - Normative IR2 CFG boundary, successor, and exceptional-edge policy for `HotFunc`.
- [`ir2/local-ssa-policy.md`](ir2/local-ssa-policy.md) - Normative locals-only SSA overlay policy, phi ownership rule, and predecessor-copy destruction rule.

## Comparisons

- [`binaryen/passes/duplicate-function-elimination/parity.md`](binaryen/passes/duplicate-function-elimination/parity.md) - Current module-wide merge contract, metadata rewrite rules, and remaining artifact parity gap for `duplicate-function-elimination`.
- [`binaryen/passes/remove-unused-module-elements/parity.md`](binaryen/passes/remove-unused-module-elements/parity.md) - Current RUME signoff state, focused rewrite coverage, and the remaining non-semantic compare noise.
- [`binaryen/passes/heap2local/parity.md`](binaryen/passes/heap2local/parity.md) - Current Binaryen parity surface, in-tree coverage, and remaining fixup gap for `heap2local`.
- [`binaryen/passes/global-struct-inference/parity.md`](binaryen/passes/global-struct-inference/parity.md) - Closed-world direct-global slice, current parity result, and scope limit for `global-struct-inference`.
- [`binaryen/passes/pick-load-signs/parity.md`](binaryen/passes/pick-load-signs/parity.md) - Active rewrite rules, current signoff, and pass-manager fast-skip behavior for `pick-load-signs`.
- [`binaryen/passes/remove-unused-brs/parity.md`](binaryen/passes/remove-unused-brs/parity.md) - Current Binaryen phase model, in-tree coverage, the fixed carried-wrapper `br_table` slice, the direct one-arm payload `br_table` parity guard, the later no-op retirements, the fixed 2026-04-18 slot-14 generated-artifact `if br` corruption, the still-open slot-40 ordered replay leak, and the newer upstream branches-to-traps drift note.
- [`binaryen/passes/ssa-nomerge/parity.md`](binaryen/passes/ssa-nomerge/parity.md) - Current `ssa-nomerge` signoff state after fixing the dead-param parity family: the reduced `Func 523` unreachable compare-carrier follow-up is now checked in, but fresh artifact replay still records the same `Func 523` `writeback-validate` skip plus `228` `suspicious-escape-carrier` bailouts.
- [`binaryen/passes/reorder-locals/parity.md`](binaryen/passes/reorder-locals/parity.md) - Exact Binaryen ordering rule, module-pass scope, and current stable-boundary signoff rule for `reorder-locals`.
- [`binaryen/passes/tuple-optimization/reduced-repros-and-evidence.md`](binaryen/passes/tuple-optimization/reduced-repros-and-evidence.md) - The reduced repro families, retired artifact blockers, current exact-shape drift families, and where the evidence lives in-tree.
- [`binaryen/passes/tuple-optimization/parity.md`](binaryen/passes/tuple-optimization/parity.md) - Current tuple-opt Binaryen signoff state: green isolated compare lanes, red exact-shape families, unscheduled preset slot, and open artifact/runtime debt.
- [`binaryen/passes/simplify-locals/parity.md`](binaryen/passes/simplify-locals/parity.md) - Current Binaryen parity state for simplify-locals, including retired reducer families, rejected ideas, and the active exact-path frontier.
- [`binaryen/passes/simplify-locals/performance-and-artifact-frontiers.md`](binaryen/passes/simplify-locals/performance-and-artifact-frontiers.md) - Skip-reason taxonomy, retired artifact hotspots, timer interpretation, and the dated large-artifact performance frontier for simplify-locals.
- [`binaryen/passes/remove-unused-names/invalid-tag-index-parser-gap.md`](binaryen/passes/remove-unused-names/invalid-tag-index-parser-gap.md) - Treat `invalid tag index` `remove-unused-names` failures as Binaryen parser-family gaps, not Starshine semantic mismatches.
- [`validate/trace-benchmark-baseline.md`](validate/trace-benchmark-baseline.md) - Committed corpus-specific `phase_totals`, `helper_totals`, and hotspot baselines for validator trace work.

## Sessions

- No pages yet.
