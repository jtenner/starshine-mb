# MergeBlocks Feature Parity Plan

Status: done.

## Purpose
Bring `merge_blocks` to practical Binaryen-style parity while preserving soundness and reducing hotspot cost.

## Completion Baseline (2026-03-13)
- Status moved from active work to historical record.
- Parity matrix now closed where verified with pass/fail classifications.
- Validation gates: `moon info && moon fmt` and `moon test`.

## Key Closed Points
- `ssa` and local cleanup insertion points match intended Binaryen flow.
- `named-branch-boundaries`, `loop-tail` extraction, dropped-block handling, and non-control restructure are implemented and classified.
- `MergeBlocks` is idempotence-checked and type/stack invariants are guarded.
- Runtime/maintenance risks now explicitly tracked as intentional divergence or follow-up tasks.

## Decision Log (Condensed)
- Parity is behavior-focused, not implementation-mimicry.
- Preserve conservative behavior when ambiguous; add tests and defer when needed.
- Strict TDD for every blocker item.
- Keep shared type/cache/state soundness as the primary gate.
- Maintain parity matrix as source of truth.

## Current Remaining Technical Debt
1. Finalize dropped-block `br_if` whole-body analysis parity.
2. Harden effect modeling coverage and movement blocking.
3. Tighten loop-tail gate alignment with Binaryen semantics.
4. Replace fixed round cap with convergence + explicit guard metrics.
5. Add effect memoization and cache-id improvements in hot paths.
6. Reduce allocation churn in branch-list and child traversal construction.

## Implementation Workstreams
- **Correctness first**: regression and parity fixtures for merge boundaries, drop handling, type invariants, and idempotence.
- **Performance second**: single-pass metrics, branch cache by id, reduced child materialization, and reduced list rebuilds.
- **Signoff**: all matrix rows marked `Match` or `Intentional divergence`, with test and performance evidence.

## Metrics
- Track and gate by:
  - `merge_blocks_time_ms`
- `functions_changed_count`
- `blocks_merged_count`
- `refinalize_invocations_per_func`
- `cache_hit_rate` (effects and branch queries)

## TDD Rule
Each item follows:
1. add focused failing fixture,
2. implement minimal change,
3. add adversarial regression for unsound movement,
4. rerun parity + optimizer baselines.
