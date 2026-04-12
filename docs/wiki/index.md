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
- [`binaryen/passes/duplicate-function-elimination/wat-shapes.md`](binaryen/passes/duplicate-function-elimination/wat-shapes.md) - Module and WAT shapes that create DFE merge candidates, rewrites, transitive unlocks, and deliberate non-merges.
- [`binaryen/passes/duplicate-function-elimination/binaryen-strategy.md`](binaryen/passes/duplicate-function-elimination/binaryen-strategy.md) - Upstream `version_129` DFE strategy: hash buckets, option-dependent iteration budget, and whole-module rewrite behavior.
- [`binaryen/passes/duplicate-function-elimination/starshine-hot-ir-strategy.md`](binaryen/passes/duplicate-function-elimination/starshine-hot-ir-strategy.md) - Current in-tree Starshine strategy for DFE, including the explicit reason it stays a module pass instead of a HOT-IR pass.
- [`binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md`](binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md) - DFE-specific rules for simple-type compaction, name handling, annotation-map rewrites, and compact element forms.
- [`binaryen/passes/remove-unused-module-elements/wat-shapes.md`](binaryen/passes/remove-unused-module-elements/wat-shapes.md) - Module layouts and instruction carriers that determine imported-parent retention, active-segment liveness, and survivor remaps for RUME.
- [`binaryen/passes/remove-unused-module-elements/binaryen-strategy.md`](binaryen/passes/remove-unused-module-elements/binaryen-strategy.md) - Upstream `version_129` RUME strategy: three-state liveness, module-wide reachability, and more than just dead-function removal.
- [`binaryen/passes/remove-unused-module-elements/starshine-hot-ir-strategy.md`](binaryen/passes/remove-unused-module-elements/starshine-hot-ir-strategy.md) - Current in-tree Starshine strategy for RUME and why it remains a module pass instead of a HOT-IR pass.
- [`binaryen/passes/remove-unused-module-elements/retention-and-index-rewrites.md`](binaryen/passes/remove-unused-module-elements/retention-and-index-rewrites.md) - Concrete rewrite surface for surviving func, global, table, memory, tag, elem, data, name, and annotation indices in RUME.
- [`binaryen/passes/tuple-optimization/wat-shapes.md`](binaryen/passes/tuple-optimization/wat-shapes.md) - Exact tuple-like raw-WAT and reduced HOT-native bridge families that should rewrite, the deliberate bailouts, and why each family matters.
- [`binaryen/passes/tuple-optimization/binaryen-strategy.md`](binaryen/passes/tuple-optimization/binaryen-strategy.md) - Upstream `version_129` tuple-local strategy: use counting, valid-use filtering, badness propagation, and tee-preserving scalar-local rewrites.
- [`binaryen/passes/tuple-optimization/starshine-hot-ir-strategy.md`](binaryen/passes/tuple-optimization/starshine-hot-ir-strategy.md) - Current in-tree HOT-native tuple-opt algorithm: seed collection, copy-group linking, rewrite suppression, carrier construction, and cleanup.
- [`binaryen/passes/tuple-optimization/scheduler-and-gates.md`](binaryen/passes/tuple-optimization/scheduler-and-gates.md) - Exact Binaryen slot and multivalue gate, plus the current reason Starshine keeps tuple-opt off public presets.
- [`binaryen/passes/code-pushing/wat-shapes.md`](binaryen/passes/code-pushing/wat-shapes.md) - Exact `code-pushing` WAT families that move today, including same-region sinks, reorders past result-producing `if` pushpoints, result-producing `if` arm sinks, safe explicit-exit prefixes, and dropped-carrier extraction shapes.
- [`binaryen/passes/code-pushing/binaryen-strategy.md`](binaryen/passes/code-pushing/binaryen-strategy.md) - Upstream `code-pushing` strategy from the repo's Binaryen study: SFA candidate discovery, push-point recognition, segment motion, and one-arm `if` sinking.
- [`binaryen/passes/code-pushing/starshine-hot-ir-strategy.md`](binaryen/passes/code-pushing/starshine-hot-ir-strategy.md) - Current in-tree HOT implementation strategy for `code-pushing`, including summary caches, explicit-exit guards, dropped-carrier extraction, and lowering-validity fences.
- [`binaryen/passes/code-pushing/artifact-frontiers.md`](binaryen/passes/code-pushing/artifact-frontiers.md) - Frontier ledger for the major debug-artifact mismatch families and the current `Func 1977` invalid-output blocker.
- [`binaryen/passes/code-pushing/validation-and-fuzzing.md`](binaryen/passes/code-pushing/validation-and-fuzzing.md) - The standing test, HOT-lowering, compare-pass, and artifact-replay workflow for advancing `code-pushing` safely.
- [`binaryen/passes/code-pushing/performance-and-runtime.md`](binaryen/passes/code-pushing/performance-and-runtime.md) - Runtime expectations, historical timing checkpoints, and the still-open secondary performance gap for `code-pushing`.
- [`binaryen/passes/remove-unused-brs/returned-ladder-hot-shapes.md`](binaryen/passes/remove-unused-brs/returned-ladder-hot-shapes.md) - Lifted HOT shape guide for the remaining returned-ladder `remove-unused-brs` families.
- [`custom-descriptors/static-fixtures.md`](custom-descriptors/static-fixtures.md) - Native static-harness policy and validator lessons for `descriptors.wast` and `exact.wast`.
- [`custom-descriptors/ref-get-desc-fixture-path.md`](custom-descriptors/ref-get-desc-fixture-path.md) - The full-stack parser, lowering, exactness, and bottom-null rules needed to keep `ref_get_desc.wast` green.
- [`custom-descriptors/exact-reference-equivalence.md`](custom-descriptors/exact-reference-equivalence.md) - Exact-reference rule: structural closure equivalence for exact struct and function refs, plus the passive typed `elem` front-end surface used by `exact.wast`.
- [`ir2/execution-plan.md`](ir2/execution-plan.md) - Current IR2 handoff contract, active registry surface, and preferred next slice order for future pass migration.
- [`ir2/pass-porting-checklist.md`](ir2/pass-porting-checklist.md) - Shared helper rules, mutation discipline, and validation floor for porting passes onto the IR2 pipeline.
- [`ir2/registry-map.md`](ir2/registry-map.md) - Current live pass registry categories, preset composition, and the caveat that the original March batch map is now partially stale.
- [`ir2/test-matrix.md`](ir2/test-matrix.md) - Shared helper and golden matrix for deterministic IR2 lift, analysis, lowering, and pass-trace coverage.
- [`strings/string-const-surface.md`](strings/string-const-surface.md) - Public surface, binary string-literal section, constant-expression rule, and IR payload handling for `string.const`.
- [`tooling/fuzz-runner.md`](tooling/fuzz-runner.md) - Repo rule that heavy fuzz belongs in `src/fuzz`, with reusable suite, profile, and seed workflow.
- [`tooling/tracing-playbook.md`](tooling/tracing-playbook.md) - Shared `key=value` trace contract, timing helper use, hotspot summaries, and the no-trace-only-tests rule.
- [`validation/moonbit-prove-strategy.md`](validation/moonbit-prove-strategy.md) - Current `moon prove` toolchain facts, the `9`-goal `src/validate_proof` helper kernel, and the blocker on proving `src/validate` directly.
- [`validate/fuzz-hardening.md`](validate/fuzz-hardening.md) - Current validator fuzz trust gaps and the staged hardening order for strategy accounting, generator breadth, and repro ergonomics.
- [`wast/gc-type-authoring.md`](wast/gc-type-authoring.md) - Higher-level WAST support for GC type defs, `rec` groups, descriptor metadata, and flat type indexing after grouped entries.

## Entities

- [`binaryen/passes/index.md`](binaryen/passes/index.md) - Namespace catalog for all active implemented Binaryen pass folders and their current documentation status.
- [`binaryen/passes/duplicate-function-elimination/index.md`](binaryen/passes/duplicate-function-elimination/index.md) - Hub page for DFE overview, shapes, upstream strategy, Starshine strategy, metadata rules, and parity status.
- [`binaryen/passes/remove-unused-module-elements/index.md`](binaryen/passes/remove-unused-module-elements/index.md) - Hub page for RUME overview, shapes, upstream strategy, Starshine strategy, retention and rewrite rules, and parity status.
- [`binaryen/passes/reorder-locals/index.md`](binaryen/passes/reorder-locals/index.md) - Folder now has a landing page plus parity and multivalue-call scope notes.
- [`binaryen/passes/ssa-nomerge/index.md`](binaryen/passes/ssa-nomerge/index.md) - Folder now has a landing page plus the current parity note for the fixed dead-param family and residual in-tree skip classification.
- [`binaryen/passes/tuple-optimization/index.md`](binaryen/passes/tuple-optimization/index.md) - Hub page for tuple-opt overview, WAT families, Binaryen strategy, Starshine HOT-native strategy, scheduler notes, reduced repros, and parity status.
- [`binaryen/passes/code-pushing/index.md`](binaryen/passes/code-pushing/index.md) - Hub page for `code-pushing` overview, exact transformed shapes, Binaryen strategy, HOT strategy, frontier notes, validation workflow, runtime notes, and parity status.
- [`binaryen/passes/dead-code-elimination/index.md`](binaryen/passes/dead-code-elimination/index.md) - Active hot-pass landing page; detailed `wat-shapes.md` / strategy / parity notes remain in progress.
- [`binaryen/passes/global-refining/index.md`](binaryen/passes/global-refining/index.md) - Active module-pass landing page; detailed `wat-shapes.md` / strategy / parity notes remain in progress.
- [`binaryen/passes/global-struct-inference/index.md`](binaryen/passes/global-struct-inference/index.md) - Folder now has a landing page plus the existing parity note.
- [`binaryen/passes/heap-store-optimization/index.md`](binaryen/passes/heap-store-optimization/index.md) - Active hot-pass landing page; detailed `wat-shapes.md` / strategy / parity notes remain in progress.
- [`binaryen/passes/heap2local/index.md`](binaryen/passes/heap2local/index.md) - Folder now has a landing page plus the current parity note.
- [`binaryen/passes/memory-packing/index.md`](binaryen/passes/memory-packing/index.md) - Active module-pass landing page; detailed `wat-shapes.md` / strategy / parity notes remain in progress.
- [`binaryen/passes/once-reduction/index.md`](binaryen/passes/once-reduction/index.md) - Active module-pass landing page; detailed `wat-shapes.md` / strategy / parity notes remain in progress.
- [`binaryen/passes/optimize-instructions/index.md`](binaryen/passes/optimize-instructions/index.md) - Active hot-pass landing page; detailed `wat-shapes.md` / strategy / parity notes remain in progress.
- [`binaryen/passes/pick-load-signs/index.md`](binaryen/passes/pick-load-signs/index.md) - Folder now has a landing page plus the current parity note.
- [`binaryen/passes/precompute/index.md`](binaryen/passes/precompute/index.md) - Active hot-pass landing page; detailed `wat-shapes.md` / strategy / parity notes remain in progress.
- [`binaryen/passes/remove-unused-brs/index.md`](binaryen/passes/remove-unused-brs/index.md) - Folder now has a landing page plus parity and returned-ladder-shape notes.
- [`binaryen/passes/remove-unused-names/index.md`](binaryen/passes/remove-unused-names/index.md) - Folder now has a landing page plus the current parser-gap note.
- [`binaryen/passes/simplify-locals/index.md`](binaryen/passes/simplify-locals/index.md) - Active hot-pass landing page; detailed `wat-shapes.md` / strategy / parity notes remain in progress.
- [`binaryen/passes/vacuum/index.md`](binaryen/passes/vacuum/index.md) - Active hot-pass landing page; detailed `wat-shapes.md` / strategy / parity notes remain in progress.

## Decisions

- [`binaryen/passes/reorder-locals/multivalue-call-scope.md`](binaryen/passes/reorder-locals/multivalue-call-scope.md) - Current project decision: non-converging Binaryen multivalue-call writeback stays out of scope for `reorder-locals` parity.
- [`ir2/cfg-contract.md`](ir2/cfg-contract.md) - Normative IR2 CFG boundary, successor, and exceptional-edge policy for `HotFunc`.
- [`ir2/local-ssa-policy.md`](ir2/local-ssa-policy.md) - Normative locals-only SSA overlay policy, phi ownership rule, and predecessor-copy destruction rule.

## Comparisons

- [`binaryen/passes/duplicate-function-elimination/parity.md`](binaryen/passes/duplicate-function-elimination/parity.md) - Current module-wide merge contract, metadata rewrite rules, and remaining artifact parity gap for `duplicate-function-elimination`.
- [`binaryen/passes/remove-unused-module-elements/parity.md`](binaryen/passes/remove-unused-module-elements/parity.md) - Current RUME signoff state, focused rewrite coverage, and the remaining non-semantic compare noise.
- [`binaryen/passes/code-pushing/parity.md`](binaryen/passes/code-pushing/parity.md) - Current direct-pass parity state for `code-pushing`, including the Binaryen no-op finding on printed `func $127`, the restored `Func 148` fence, and the remaining artifact/runtime signoff work.
- [`binaryen/passes/heap2local/parity.md`](binaryen/passes/heap2local/parity.md) - Current Binaryen parity surface, in-tree coverage, and remaining fixup gap for `heap2local`.
- [`binaryen/passes/global-struct-inference/parity.md`](binaryen/passes/global-struct-inference/parity.md) - Closed-world direct-global slice, current parity result, and scope limit for `global-struct-inference`.
- [`binaryen/passes/pick-load-signs/parity.md`](binaryen/passes/pick-load-signs/parity.md) - Active rewrite rules, current signoff, and pass-manager fast-skip behavior for `pick-load-signs`.
- [`binaryen/passes/remove-unused-brs/parity.md`](binaryen/passes/remove-unused-brs/parity.md) - Current Binaryen phase model, in-tree coverage, and the remaining final-shape gap for `remove-unused-brs`.
- [`binaryen/passes/ssa-nomerge/parity.md`](binaryen/passes/ssa-nomerge/parity.md) - Current `ssa-nomerge` signoff state after fixing the dead-param parity family: the reduced `Func 523` unreachable compare-carrier follow-up is now checked in, but fresh artifact replay still records the same `Func 523` `writeback-validate` skip plus `228` `suspicious-escape-carrier` bailouts.
- [`binaryen/passes/reorder-locals/parity.md`](binaryen/passes/reorder-locals/parity.md) - Exact Binaryen ordering rule, module-pass scope, and current stable-boundary signoff rule for `reorder-locals`.
- [`binaryen/passes/tuple-optimization/reduced-repros-and-evidence.md`](binaryen/passes/tuple-optimization/reduced-repros-and-evidence.md) - The reduced repro families, retired artifact blockers, current exact-shape drift families, and where the evidence lives in-tree.
- [`binaryen/passes/tuple-optimization/parity.md`](binaryen/passes/tuple-optimization/parity.md) - Current tuple-opt Binaryen signoff state: green isolated compare lanes, red exact-shape families, unscheduled preset slot, and open artifact/runtime debt.
- [`binaryen/passes/remove-unused-names/invalid-tag-index-parser-gap.md`](binaryen/passes/remove-unused-names/invalid-tag-index-parser-gap.md) - Treat `invalid tag index` `remove-unused-names` failures as Binaryen parser-family gaps, not Starshine semantic mismatches.
- [`validate/trace-benchmark-baseline.md`](validate/trace-benchmark-baseline.md) - Committed corpus-specific `phase_totals`, `helper_totals`, and hotspot baselines for validator trace work.

## Research

- [`raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md`](raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md) - Binaryen-side reread and direct artifact slice proving that `--code-pushing` leaves printed `func $127` unchanged, so the old `44251` frontier was a Starshine-only fence question.
- [`raw/research/0077-2026-04-11-code-pushing-result-if-sink.md`](raw/research/0077-2026-04-11-code-pushing-result-if-sink.md) - Reduced Binaryen probe plus debug-artifact corroboration showing that `code-pushing` does sink into result-producing `if` arms, so Starshine's old blanket result-`if` fence was over-conservative.
- [`raw/research/0078-2026-04-11-code-pushing-result-if-reorder.md`](raw/research/0078-2026-04-11-code-pushing-result-if-reorder.md) - Reduced Binaryen probe plus debug-artifact corroboration showing that `code-pushing` also reorders past result-producing `if` pushpoints, so Starshine's old blanket result-`if` pushpoint fence was over-conservative.
- [`raw/research/0079-2026-04-12-code-pushing-one-off-alias-tail-prefix.md`](raw/research/0079-2026-04-12-code-pushing-one-off-alias-tail-prefix.md) - Reduced Binaryen probe plus artifact slice showing that the one-off alias-if-tail fence was still too broad unless an earlier explicit-exit carrier actually feeds the moved alias source local.

## Sessions

- No pages yet.
