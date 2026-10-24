# Starshine consolidation ledger
base origin/master: dc9e0099ef7af67bec5bd64f7c15665f61f3e9ab
started: 2026-10-24T15:04:46-04:00
## Merge pass 1 2026-10-24T15:07:48-04:00
candidates: 30
HELD-CONFLICT fix/flatten-trap-flow-cache files: docs/wiki/log.md,src/passes/flatten.mbt,
HELD-CONFLICT codex/name-debug-comparison-fix files: docs/README.md,docs/wiki/tooling/pass-fuzz-compare.md,scripts/lib/pass-fuzz-compare-command-failure.test.ts,scripts/lib/pass-fuzz-compare-debug-policy.test.ts,scripts/lib/pass-fuzz-compare-task.test.ts,scripts/lib/pass-fuzz-compare-task.ts,
HELD-CONFLICT codex/proposal-runtime-observation files: docs/wiki/fuzzing/semantic-optimizer-campaigns.md,docs/wiki/tooling/pass-fuzz-compare.md,
HELD-CONFLICT audit/optimize-casts-abstract-lattice files: docs/wiki/binaryen/passes/optimize-casts/implementation-structure-and-tests.md,docs/wiki/binaryen/passes/optimize-casts/starshine-strategy.md,src/cmd/cmd.mbt,src/passes/optimize_casts_test.mbt,
HELD-CONFLICT fix/ssa-continuation-liveness files: docs/wiki/binaryen/passes/ssa-nomerge/starshine-hot-ir-strategy.md,docs/wiki/log.md,
HELD-CONFLICT audit/duplicate-import-host-contract files: docs/wiki/binary/custom-and-name-sections.md,docs/wiki/binaryen/passes/duplicate-import-elimination/implementation-structure-and-tests.md,docs/wiki/binaryen/passes/duplicate-import-elimination/index.md,docs/wiki/binaryen/passes/duplicate-import-elimination/starshine-strategy.md,docs/wiki/ir2/architecture-rules.md,src/cmd/cmd_wbtest.mbt,src/passes/duplicate_import_elimination.mbt,src/passes/duplicate_import_elimination_test.mbt,tests/optimizer/regressions/host-identity.test.ts,
HELD-CONFLICT audit/die-annotation-preservation-after-host-contract files: docs/wiki/binary/custom-and-name-sections.md,docs/wiki/binaryen/passes/duplicate-import-elimination/index.md,docs/wiki/ir2/architecture-rules.md,docs/wiki/wast/code-metadata-and-function-annotations.md,src/cmd/cmd_wbtest.mbt,src/passes/duplicate_import_elimination.mbt,src/passes/duplicate_import_elimination_test.mbt,tests/optimizer/regressions/host-identity.test.ts,
HELD-CONFLICT audit/shared-gc-atomic-runtime files: scripts/lib/optimizer-shared-gc-atomic-runtime.test.ts,scripts/lib/optimizer-shared-gc-atomic-runtime.ts,
HELD-CONFLICT audit/memory64-atomic-runtime-20260923 files: docs/wiki/fuzzing/semantic-optimizer-campaigns.md,docs/wiki/wasm-linear-memory-threads-boundary.md,scripts/lib/optimizer-atomic-runtime.test.ts,scripts/lib/optimizer-atomic-runtime.ts,
HELD-CONFLICT fix/proposal-runtime-boundaries-47 files: docs/wiki/fuzzing/semantic-optimizer-campaigns.md,docs/wiki/log.md,scripts/lib/optimizer-runtime-executor.test.ts,scripts/lib/optimizer-runtime-executor.ts,scripts/lib/optimizer-semantic-cache.ts,src/cmd/optimizer_reports_wbtest.mbt,
HELD-CONFLICT codex/atomic-outcomes-20260922 files: docs/wiki/fuzzing/semantic-optimizer-campaigns.md,docs/wiki/wasm-linear-memory-threads-boundary.md,scripts/lib/optimizer-atomic-runtime-worker.ts,scripts/lib/optimizer-atomic-runtime.test.ts,scripts/lib/optimizer-atomic-runtime.ts,
HELD-CONFLICT audit/item48-weaker-fence-20260922 files: docs/wiki/fuzzing/semantic-optimizer-campaigns.md,docs/wiki/log.md,docs/wiki/wasm-linear-memory-threads-boundary.md,docs/wiki/wasm-relaxed-atomics-boundary.md,scripts/lib/optimizer-atomic-runtime.test.ts,
HELD-CONFLICT audit/memory64-atomic-wait-runtime-20260923 files: docs/wiki/fuzzing/semantic-optimizer-campaigns.md,docs/wiki/wasm-linear-memory-threads-boundary.md,scripts/lib/optimizer-atomic-runtime.test.ts,
HELD-CONFLICT codex/case437-simplify-typed-loop files: docs/wiki/binaryen/passes/simplify-locals/raw-lane-and-writeback.md,
HELD-CONFLICT codex/rub-seven-pass-larger-parity-home files: docs/wiki/binaryen/passes/precompute/fuzzing.md,docs/wiki/binaryen/passes/remove-unused-brs/fuzzing.md,src/cmd/precompute_seven_pass_br_table_parity_wbtest.mbt,src/passes/precompute.mbt,src/passes/precompute_test.mbt,
HELD-CONFLICT fix/vacuum-case31-dead-struct-type files: docs/wiki/binaryen/passes/precompute/fuzzing.md,src/passes/vacuum_deep_audit_test.mbt,
HELD-CONFLICT agent/case29-lcse-nonnull-1790144588 files: agent-todo.md,docs/wiki/binaryen/passes/local-cse/starshine-strategy.md,docs/wiki/log.md,src/passes/local_cse.mbt,src/passes/local_cse_test.mbt,
HELD-CONFLICT codex/mooncakes-readme files: agent-todo.md,docs/wiki/index.md,docs/wiki/log.md,docs/wiki/tooling/release-process.md,
MERGED codex/research-5-oracle-20261012 dc9e0099e -> 1d228d03e
MERGED codex/research-24-proof-gate-20261012 1d228d03e -> e64438501
MERGED codex/research-27-cost-provenance-20261012 e64438501 -> a7558397f
HELD-CONFLICT codex/research-29-validation-premises-20261012 files: docs/wiki/validate/module-validation-phases.md,
MERGED codex/research-30-hot-conversion-20261012 a7558397f -> dc8ba65c4
MERGED codex/research-9-live-dataflow-20261012 dc8ba65c4 -> b1875e0cf
HELD-CONFLICT codex/wago-bulk-cli files: agent-todo.md,component/moon.mod,docs/wiki/log.md,docs/wiki/tooling/cli-command-and-dispatcher.md,docs/wiki/tooling/node-package-surface.md,docs/wiki/tooling/tracing-playbook.md,scripts/lib/component-task.test.ts,scripts/lib/component-task.ts,src/cmd/cmd.mbt,src/passes/merge_similar_functions_test.mbt,src/passes/offset_metadata_guard_wbtest.mbt,src/passes/rse_test.mbt,
HELD-CONFLICT codex/research-6-rule-recipes-20261012 files: docs/wiki/binaryen/passes/dead-argument-elimination/fuzzing.md,docs/wiki/binaryen/passes/optimize-instructions/fuzzing.md,src/fuzz/main.mbt,src/validate/gen_valid.mbt,
MERGED codex/research-25-pass-order-20261013 b1875e0cf -> 0665a935f
MERGED codex/research-28-r3-replay-20261013 0665a935f -> f442e31e3
HELD-CONFLICT research/optimization-campaign-pre-rebase-2026-10-14 files: agent-todo.md,docs/wiki/binaryen/passes/duplicate-function-elimination/fuzzing.md,docs/wiki/binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md,docs/wiki/binaryen/passes/remove-unused-module-elements/fuzzing.md,docs/wiki/binaryen/passes/remove-unused-module-elements/roots-reference-only-and-nullification.md,docs/wiki/binaryen/passes/reorder-functions/starshine-strategy.md,docs/wiki/log.md,scripts/lib/fuzz-task.ts,src/cmd/cmd.mbt,src/fuzz/cmd_harness.mbt,src/passes/optimize.mbt,src/passes/pass_manager.mbt,src/passes/precompute.mbt,src/rume/host_roots.mbt,src/rume/remove_unused_module_elements.mbt,
HELD-CONFLICT codex/pass-audit-red-green-fixes files: agent-todo.md,docs/wiki/binaryen/passes/dae2/starshine-strategy.md,docs/wiki/binaryen/passes/i64-to-i32-lowering/index.md,docs/wiki/binaryen/passes/i64-to-i32-lowering/starshine-port-readiness-and-validation.md,docs/wiki/binaryen/passes/i64-to-i32-lowering/starshine-strategy.md,docs/wiki/binaryen/passes/string-gathering/index.md,docs/wiki/ir2/architecture-rules.md,docs/wiki/log.md,src/ir/effects.mbt,src/passes/binaryen133_i64_lowering_red_wbtest.mbt,src/passes/dae2_raw_analysis_wbtest.mbt,src/passes/dead_code_elimination.mbt,src/passes/dead_code_elimination_test.mbt,src/passes/i64_to_i32_lowering.mbt,src/passes/i64_to_i32_lowering_noop_perf_wbtest.mbt,src/passes/intrinsic_lowering.mbt,src/passes/merge_blocks.mbt,src/passes/merge_locals_preflight_wbtest.mbt,src/passes/optimize.mbt,src/passes/optimize_test.mbt,src/passes/pass_manager.mbt,src/passes/remove_unused_brs.mbt,
PASS1 DONE head=f442e31e32d64922aba85fe9af684ddc0d6c0c9c
## Resolve pass 2026-10-24T15:09:31-04:00
STOPPED at fix/flatten-trap-flow-cache awaiting manual resolution
HOLD fix/flatten-trap-flow-cache reason: design-level conflict in src/passes/flatten.mbt (8+ conflict hunks in a 12261-line pass file; the Aug 4 trap-order and scratch redesign collides with 2.5 months of master evolution of the same pass; needs an owner decision, not a mechanical merge)
## Resolve pass 2026-10-24T15:10:34-04:00
SKIP-HELD fix/flatten-trap-flow-cache
STOPPED at codex/name-debug-comparison-fix awaiting manual resolution
SKIPPED-DUPLICATE codex/name-debug-comparison-fix evidence: unique commit 92fee8a6b (fix: preserve names in strip-debug comparisons) already landed in origin/master as 68d82071a (same subject) and evolved by fa2b2ab43 (fix: stabilize Binaryen comparison projections); master task.ts already contains comparisonDebugPolicy/comparisonProjectionFlags/schema-v2-debug-preserving; branch file versions are stale (Binaryen 132 vs master 133). git cherry could not detect it because the landed copy differs textually.
## Resolve pass 2026-10-24T15:13:12-04:00
SKIP-HELD fix/flatten-trap-flow-cache
SKIP-HELD codex/name-debug-comparison-fix
MERGED-UNIONDOCS codex/proposal-runtime-observation -> 8f787b9a1
STOPPED at audit/optimize-casts-abstract-lattice awaiting manual resolution
MERGED-MANUAL audit/optimize-casts-abstract-lattice: cmd.mbt kept master test block (branch dispatcher test already present at line 9465); optimize_casts_test.mbt kept BOTH string rows (no_extern from master, none from branch) pending package-test verification
## Resolve pass 2026-10-24T15:16:01-04:00
SKIP-HELD fix/flatten-trap-flow-cache
SKIP-HELD codex/name-debug-comparison-fix
MERGED-UNIONDOCS fix/ssa-continuation-liveness -> 2841f233d
STOPPED at audit/duplicate-import-host-contract awaiting manual resolution
SKIPPED-DUPLICATE audit/duplicate-import-host-contract evidence: unique commit 3d831aab5 (fix: preserve repeated import resolution in direct DIE) is identical in stat (14 files, 253+/207-) and code diff to origin/master commit d53b6f1d1 (same subject); tip commit 9bc1c90f8 patch-equivalent per cherry; audit closure docs in master as 804134745.
SKIPPED-DUPLICATE batch (verified by subject match in origin/master + full-patch comparison; differing lines are only doc wording/context drift from the rebase, sampled and confirmed):
- audit/die-annotation-preservation-after-host-contract = d53b6f1d1 (symdiff 6)
- audit/shared-gc-atomic-runtime = 82cb893b3 (patch IDENTICAL)
- audit/memory64-atomic-runtime-20260923 = 9b734a133 (symdiff 4)
- fix/proposal-runtime-boundaries-47 = 389865173 (patch IDENTICAL)
- codex/atomic-outcomes-20260922 = 239f2ec58 (symdiff 5)
- audit/item48-weaker-fence-20260922 = 7ec41eb9c (symdiff 2)
- audit/memory64-atomic-wait-runtime-20260923 = ede701b63 (symdiff 6)
- codex/case437-simplify-typed-loop = e56186d53 (symdiff 2)
- codex/rub-seven-pass-larger-parity-home = 9dcdc9cdb (symdiff 2)
- fix/vacuum-case31-dead-struct-type = 59d4d55e9 (symdiff 2)
- agent/case29-lcse-nonnull-1790144588 = 31a0091d0 (patch IDENTICAL)
- research/optimization-campaign-pre-rebase-2026-10-14 = 60dae835e,72881dc9d,d5b2e6c27,d630d2b03,e2dd9f2bf (all 5 unique commits re-landed; one IDENTICAL, rest symdiff 2-11 doc drift)
## Resolve pass 2026-10-24T15:19:29-04:00
SKIP-HELD fix/flatten-trap-flow-cache
SKIP-HELD codex/name-debug-comparison-fix
SKIP-HELD audit/duplicate-import-host-contract
SKIP-HELD audit/die-annotation-preservation-after-host-contract
SKIP-HELD audit/shared-gc-atomic-runtime
SKIP-HELD audit/memory64-atomic-runtime-20260923
SKIP-HELD fix/proposal-runtime-boundaries-47
SKIP-HELD codex/atomic-outcomes-20260922
SKIP-HELD audit/item48-weaker-fence-20260922
SKIP-HELD audit/memory64-atomic-wait-runtime-20260923
SKIP-HELD codex/case437-simplify-typed-loop
SKIP-HELD codex/rub-seven-pass-larger-parity-home
SKIP-HELD fix/vacuum-case31-dead-struct-type
SKIP-HELD agent/case29-lcse-nonnull-1790144588
MERGED-UNIONDOCS codex/mooncakes-readme -> 39a3589c3
MERGED-UNIONDOCS codex/research-29-validation-premises-20261012 -> 3139714cf
STOPPED at codex/wago-bulk-cli awaiting manual resolution
MERGED-MANUAL codex/wago-bulk-cli: component staging manifests + renderGeneratedMoonModule + syncConvertedPackageManifests call taken from branch; fmt step kept master (release) sequencing since bindings are copied to componentRoot before plan[1] runs; moon.mod kept 0.3.0; cmd.mbt hunk1 combined (master try-table guard + branch unvalidated-candidate append), hunk2 combined (trim_program_name + abort on failure), hunk3 branch nop fixture; passes test files kept master versions (paired with master pass code; branch added no tests there)
## Resolve pass 2026-10-24T15:24:18-04:00
SKIP-HELD fix/flatten-trap-flow-cache
SKIP-HELD codex/name-debug-comparison-fix
SKIP-HELD audit/duplicate-import-host-contract
SKIP-HELD audit/die-annotation-preservation-after-host-contract
SKIP-HELD audit/shared-gc-atomic-runtime
SKIP-HELD audit/memory64-atomic-runtime-20260923
SKIP-HELD fix/proposal-runtime-boundaries-47
SKIP-HELD codex/atomic-outcomes-20260922
SKIP-HELD audit/item48-weaker-fence-20260922
SKIP-HELD audit/memory64-atomic-wait-runtime-20260923
SKIP-HELD codex/case437-simplify-typed-loop
SKIP-HELD codex/rub-seven-pass-larger-parity-home
SKIP-HELD fix/vacuum-case31-dead-struct-type
SKIP-HELD agent/case29-lcse-nonnull-1790144588
STOPPED at codex/research-6-rule-recipes-20261012 awaiting manual resolution
