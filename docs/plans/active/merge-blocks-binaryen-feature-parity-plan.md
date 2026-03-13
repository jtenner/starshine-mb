# MergeBlocks Feature Parity Plan (Binaryen vs starshine-mb)

Date: 2026-03-13  
Owner: Compiler passes team  
Status: Active

## 1. Scope and Objective

This plan defines how we will reach practical feature parity with Binaryen's `MergeBlocks` pass while improving pass runtime and preserving soundness.

Parity target source:
- Binaryen `main`: `src/passes/MergeBlocks.cpp`
- Snapshot validated on 2026-03-13
- Latest file-touch commit from GitHub API: `f9dd59e971678c2d05712e7d358eccc72a0153b4` (2025-01-16)

Local implementation target:
- `src/passes/merge_blocks.mbt`

Out of scope:
- Non-`MergeBlocks` pass behavior changes unless needed for correctness API support.
- Broad optimizer pipeline reordering not directly required by MergeBlocks parity.

## 2. Decision Log (Explicit)

Decision D-001: **Parity means behavior parity, not code-shape parity.**  
We will match transformation legality and enabled opportunities, but we will not mirror Binaryen's C++ allocator/list APIs.

Decision D-002: **Safety first in ambiguous cases.**  
If a movement case is uncertain, we keep conservative behavior and add a test + follow-up issue instead of forcing equivalence.

Decision D-003: **Adopt strict TDD for each parity item.**  
For every feature gap or correctness risk below, we add a failing test first, then implementation.

Decision D-004: **Preserve typed IR soundness guarantees.**  
Existing stack-signature and type-preservation checks are retained unless replaced by demonstrably equivalent cheaper checks.

Decision D-005: **Keep one parity matrix in-tree and update it per change.**  
The matrix in this file is the source of truth for open/closed parity work.

Decision D-006: **Use two tiers of parity acceptance.**
- Tier A: semantic equivalence on targeted fixtures.
- Tier B: comparable optimization enablement (same transformation opportunities on fixture corpus).

Decision D-007: **Effect modeling is an explicit correctness boundary.**  
Any motion logic change must include effect-classification audit against opcode inventory used by MergeBlocks.

Decision D-008: **Refinalization policy should run at most once per function.**  
Current double-refinalize paths are treated as performance debt and must be collapsed safely.

Decision D-009: **No broad speculative rewrites.**  
We will stage changes in narrow slices (drop-path parity, core block merge parity, restructure parity, then perf passes).

Decision D-010: **Use deterministic fixtures for parity verification.**  
No randomized test-only loops in `moon test`; use explicit IR fixtures.

Decision D-011: **Conservative mismatch handling is documented as a gap, not hidden.**  
If we keep a conservative divergence intentionally, we document reason, expected impact, and revisit criteria.

Decision D-012: **Performance work must be measured, not inferred.**  
Each optimization task below has a concrete runtime metric gate.

## 3. Current Parity Matrix

Legend:
- `Match`: functionally aligned
- `Gap`: behavior/opportunity mismatch
- `Risk`: potential correctness issue

### 3.1 Core Merge Features

1. Parent-child block merge loop
- Binaryen: `optimizeBlock`
- Local: `optimize_block`
- Status: Match

2. Partial merge for named blocks (head-only up to first branch)
- Status: Match (conservative)

3. Loop tail extraction from `(loop (block ...))`
- Status: Match (shape-compatible)

4. `(drop (block ...))` optimization
- Status: Match

5. Break-value stripping for dropped named blocks
- Status: Match with gap
- Gap: local `problem_finder` is invoked per top-level child, not once over entire dropped block body. This is more conservative and can reject optimizations Binaryen allows.

6. `try_table` special handling in dropped-block path
- Status: Match intent; requires directed parity fixtures for all catch forms.

### 3.2 Restructure Features

1. Pull block-prefix code out of non-control expressions
- Status: Match

2. `if` condition block extraction
- Status: Match

3. `throw` operand extraction guarded by side effects
- Status: Match

### 3.3 Type/Finalization Behavior

1. Block/back type compatibility checks before extraction
- Status: Match intent

2. Finalization/refinalization strategy
- Status: Gap
- Gap: local implementation can refinalize twice per changed function (`changed` path + `needs_refinalize` path), while Binaryen performs a single gated `ReFinalize`.

### 3.4 Runtime/Implementation Efficiency

1. Per-function parallelism
- Status: Gap (Binaryen marks pass function-parallel)

2. Allocation-efficient list assembly
- Status: Gap (Binaryen uses `SmallVector` and in-place mutation)

3. Effect analysis reuse
- Status: Gap (local recomputes `compute_effects` repeatedly; no memoized pass-local cache)

4. Branch query caching
- Status: Partial Match (local cache exists but is structural-hash based and not integrated like `BranchSeekerCache`)

## 4. Correctness Issues and Risks

Severity legend: `S1` high, `S2` medium, `S3` low.

### C-001 (`S2`): Dropped-block `br_if` accounting scope mismatch

Issue:
- Binaryen runs `ProblemFinder` over the entire dropped block expression once.
- Local code runs `problem_finder` separately for each top-level instruction in block body.

Impact:
- Conservative false negatives (missed optimization opportunities) and parity mismatch.

Decision:
- Change local path to analyze the whole dropped block body as one expression for parity.

Tests to add first:
- Fixture with two sibling subtrees where dropped/non-dropped `br_if` usage balance only globally.

### C-002 (`S1`): Effect model coverage drift risk

Issue:
- Merge legality depends on `mb_collect_shallow_effects`; this is hand-maintained and easy to desync from opcode surface.

Impact:
- Missing effect flags can permit unsafe motion (semantic bug).

Decision:
- Add opcode coverage audit and tests for movement barriers for each side-effect/trap/branch class relevant to MergeBlocks.

Tests to add first:
- A table-driven suite asserting "movement blocked/allowed" per representative opcode family.

### C-003 (`S2`): Loop partial-merge guard divergence from Binaryen

Issue:
- Local loop gate conditions differ from Binaryen's `keepEnd/childList.back()->type.isConcrete()` logic.

Impact:
- Likely optimization gap; requires directed tests to exclude hidden unsound moves.

Decision:
- Port Binaryen-compatible gating logic and validate with typed loop fixtures.

### C-004 (`S3`): Fixed optimization round cap (`20`) may stop before convergence

Issue:
- Local optimizer hard-stops after 20 rounds.

Impact:
- Deterministic but potentially misses valid merges on deep nests.

Decision:
- Replace with convergence criterion + safety cap instrumentation (warn/metric) to avoid silent truncation.

## 5. Performance Optimization Opportunities

### P-001: Single-pass function refinalization

Current:
- Local may run refinalization twice on same function.

Change:
- Collapse to one `needs_refinalize || changed` gate and run once.

Expected gain:
- Lower post-transform traversal cost on high-change functions.

Metric:
- `merge_blocks_refinalize_passes_per_func` average drops from up to 2.0 to <= 1.0.

### P-002: Effect analysis memoization cache

Current:
- `compute_effects(instr)` recomputed frequently for same nodes inside loops and checks.

Change:
- Add per-function cache keyed by stable instruction identity hash or node id.

Expected gain:
- Lower asymptotic overhead in large expressions with repeated checks.

Metric:
- Wall time in pass benchmark decreases by >= 15% on deep nested synthetic fixture.

### P-003: Branch query cache refinement

Current:
- Branch cache key includes whole instruction structure + depth.

Change:
- Move to id-based cache and explicit invalidation boundary after rewrites, mirroring `BranchSeekerCache` intent.

Expected gain:
- Lower hashing and comparison cost.

Metric:
- `branch_query_cache_hit_rate` >= 90% on representative modules.

### P-004: Child traversal allocation reduction

Current:
- `mb_eval_children` materializes arrays repeatedly.

Change:
- Introduce lightweight child iterator API for non-control ops used in restructure path.

Expected gain:
- Fewer temporary allocations and copies.

Metric:
- Allocation count sample in profiling reduced by >= 20% in hot parity fixtures.

### P-005: Merge list construction simplification

Current:
- Rebuild arrays repeatedly each round.

Change:
- Use staged mutable buffers and swap strategy closer to Binaryen's merged-list approach.

Expected gain:
- Lower copy overhead in large block lists.

Metric:
- `optimize_block` per-round copy volume (items copied) reduced by >= 25%.

## 6. Implementation Workstreams

## WS-0 Baseline and Measurement Harness

Tasks:
1. Add parity fixture corpus under `src/passes/merge_blocks_parity_test.mbt` (or append existing file if preferred).
2. Add timing harness helper for `run_merge_blocks` on fixed fixture set.
3. Record baseline metrics for current implementation.

Exit criteria:
- Baseline CSV/log checked into CI artifact path or documented in PR notes.

## WS-1 Correctness and Parity Gaps

Tasks:
1. Fix C-001 by changing dropped-block analysis scope to whole-body traversal.
2. Port loop-tail gating semantics to match Binaryen behavior where safe.
3. Add exhaustive drop-path fixtures for `try_table` variants.
4. Add regression tests for branch/value drop legality around `br_if` and nested drops.

Exit criteria:
- All new tests fail before code changes and pass after.
- No regressions in existing MergeBlocks tests.

## WS-2 Effect Model Hardening

Tasks:
1. Create explicit opcode-effect checklist relevant to MergeBlocks motion barriers.
2. Fill missing effect tags in `mb_collect_shallow_effects`.
3. Add movement-blocking tests per effect class.

Exit criteria:
- Checklist complete.
- All effect barrier tests pass.

## WS-3 Performance Passes

Tasks:
1. Implement P-001 (single refinalize gate).
2. Implement P-002 (effects memoization).
3. Implement P-003 (branch cache refinement).
4. Implement P-004/P-005 (allocation and rebuild reductions).

Exit criteria:
- Target metric deltas reached on benchmark set.
- No correctness test regressions.

## WS-4 Final Parity Signoff

Tasks:
1. Re-run parity matrix and mark each row Match/Intentional divergence.
2. Document intentional conservative differences with reasons.
3. Run final local gate:
   - `moon info && moon fmt`
   - `moon test`

Exit criteria:
- Tier A and Tier B parity acceptance met.
- Plan moved from `active` to `done` with result summary.

## 7. Test Strategy (TDD)

For each item:
1. Add failing test with minimal fixture.
2. Implement smallest change to pass.
3. Add adversarial fixture to defend against unsound movement.
4. Run full pass tests.

Required test buckets:
- Named block merge boundaries.
- Loop tail partial extraction.
- Dropped block + branch value removal.
- `try_table` catch mode permutations.
- Non-control restructure with dependency/effect collisions.
- Type-preservation and stack-signature invariants.
- Idempotence (`run_merge_blocks` once vs twice).

## 8. Metrics and Reporting

Report per iteration:
- `merge_blocks_time_ms` on fixed corpus.
- `functions_changed_count`.
- `blocks_merged_count` (if instrumentation added).
- `dropped_block_optimized_count`.
- `refinalize_invocations_per_func`.
- Cache hit rates (effects, branch queries).

Pass/fail metric gates:
- No correctness regressions.
- >= 15% pass runtime improvement on chosen stress fixture.
- Parity fixture transformations match expected output patterns.

## 9. Risks and Mitigations

Risk R-001: Overfitting to Binaryen internals rather than semantics.  
Mitigation: Keep semantics-first acceptance criteria and fixture-based validation.

Risk R-002: Performance wins regress type safety checks.  
Mitigation: Keep invariant tests and add pre/post stack-signature assertions in tests.

Risk R-003: Cache invalidation bugs after rewrites.  
Mitigation: Keep caches function-local and rebuild caches after structural rewrites where necessary.

Risk R-004: Plan drift.  
Mitigation: Update this plan in every MergeBlocks parity PR.

## 10. Definition of Done

Done when all are true:
1. All parity matrix rows are `Match` or `Intentional divergence` with written rationale.
2. C-001..C-004 are resolved or formally deferred with issue IDs.
3. Performance gates are met with recorded measurements.
4. `moon info && moon fmt` and `moon test` pass.
5. Plan moved from `docs/plans/active` to `docs/plans/done` with completion notes.

