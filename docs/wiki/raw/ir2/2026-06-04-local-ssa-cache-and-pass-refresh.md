# IR2 Local SSA Cache And Pass-Use Refresh

_Status:_ immutable source bridge for [`docs/wiki/ir2/local-ssa-policy.md`](../../ir2/local-ssa-policy.md)
_Captured:_ 2026-06-04

## Primary / high-quality sources rechecked

1. Ron Cytron, Jeanne Ferrante, Barry K. Rosen, Mark N. Wegman, and F. Kenneth Zadeck, “Efficiently Computing Static Single Assignment Form and the Control Dependence Graph,” *ACM Transactions on Programming Languages and Systems* 13(4), 451–490, 1991. DOI: <https://doi.org/10.1145/115372.115320>.
   - Cross-checked with the Washington University Research Profiles entry <https://profiles.wustl.edu/en/publications/efficiently-computing-static-single-assignment-form-and-the-contr/> and IBM Research publication page <https://research.ibm.com/publications/efficiently-computing-static-single-assignment-form-and-the-control-dependence-graph>.
   - This remains algorithmic lineage only: dominance frontiers, def/use facts, and renaming vocabulary. It does not define Starshine's local cache, pass helper, destruction, or HOT ownership contracts.
2. Existing Starshine bridge [`2026-05-20-local-ssa-source-bridge.md`](2026-05-20-local-ssa-source-bridge.md), retained as the stable bibliographic and implementation bridge for the original local-SSA page.

## Repository evidence rechecked

- [`../../../../src/ir/analysis_cache.mbt`](../../../../src/ir/analysis_cache.mbt)
  - `HotAnalysisCache` stores `ssa : HotCacheEntry[HotLocalSsa]?` alongside CFG, orders, dominance, postdominance, loop info, use-def, liveness, and effects.
  - `cache_get_or_build_ssa(...)` first checks `built_at_revision == hot_revision_current(func)`, then builds dependencies in order: CFG, dominance, use-def, liveness, and finally `ssa_build_local(...)`.
  - `cache_invalidate_all(...)` clears SSA together with every other overlay.
- [`../../../../src/ir/analysis_cache_test.mbt`](../../../../src/ir/analysis_cache_test.mbt)
  - Proves unchanged-revision reuse for representative overlays.
  - Proves stale SSA rebuilds after a root mutation bumps the hot revision and refreshes dependent CFG/liveness entries.
  - Proves `cache_invalidate_all(...)` clears the SSA slot.
- [`../../../../src/ir/architecture.mbt`](../../../../src/ir/architecture.mbt)
  - `HotAnalysis::ssa()` is the pass-descriptor vocabulary for local SSA requirements/invalidations.
- [`../../../../src/passes/pass_common.mbt`](../../../../src/passes/pass_common.mbt)
  - `pass_require_ssa(...)` routes through the shared cache and records `analysis:ssa` timing plus dataflow/traversal counters only when the cached entry is stale.
  - `pass_mark_mutated(...)` invalidates the entire cache after a pass mutation, so any held `HotLocalSsa` must be treated as stale after mutation.
- Current pass declarations and direct users found in `src/passes/*.mbt`
  - Many active HOT passes declare `HotAnalysis::ssa()` as a requirement even when their first implementation slice is not deeply SSA-driven. This is a dependency declaration and cache-warmup behavior, not proof that every pass performs an SSA rewrite.
  - Concrete consumers include [`../../../../src/passes/ssa_nomerge.mbt`](../../../../src/passes/ssa_nomerge.mbt) and [`../../../../src/passes/precompute.mbt`](../../../../src/passes/precompute.mbt), which call `pass_require_ssa(...)` directly.
- [`../../../../src/ir/hot_verify.mbt`](../../../../src/ir/hot_verify.mbt)
  - `hot_verify_ssa(...)` currently delegates to `hot_verify_control(func)` and ignores the SSA object, so it is a control-shape checkpoint rather than a deep overlay consistency checker.
- [`../../../../src/ir/ssa_policy.mbt`](../../../../src/ir/ssa_policy.mbt), [`../../../../src/ir/ssa_local.mbt`](../../../../src/ir/ssa_local.mbt), and [`../../../../src/ir/ssa_destroy.mbt`](../../../../src/ir/ssa_destroy.mbt)
  - The May bridge remains accurate for local value origins, liveness-pruned dominance-frontier placement, normal-edge-only phi inputs, query APIs, and predecessor-copy destruction.

## Durable conclusions

- Local SSA is now best documented as both a locals-only overlay and a normal participant in the revision-keyed `HotAnalysisCache` lifecycle.
- Requesting `HotAnalysis::ssa()` in a pass descriptor means “build or reuse the local SSA overlay through the shared pass/cache path”; it does not imply the pass owns persistent SSA state or that it must call `ssa_destroy_into_hot(...)`.
- Any mutation that changes the `HotFunc` revision invalidates SSA ids, phi ids, block ids, liveness bitsets, and CFG-derived predecessor ordering. Passes must reacquire SSA after mutation instead of keeping a handle across `pass_mark_mutated(...)` or other revision-changing helpers.
- `hot_verify_ssa(...)` is not a comprehensive SSA-integrity validator today. Deep SSA correctness remains locked by focused `ssa_policy`, `ssa_local`, `ssa_destroy`, and `analysis_cache` tests plus the normal verify/lower/validate loop.
- No external source changes the existing Starshine design. The Cytron paper is stable lineage; current repository code and tests are authoritative for cache lifecycle, pass helper behavior, and destruction/writeback.

## Open interpretation boundaries

- This refresh does not certify that every pass declaring `HotAnalysis::ssa()` semantically depends on SSA. Future pass dossiers should say whether SSA is required for correctness, cache warmup, or historical descriptor symmetry.
- This refresh does not add exceptional-edge SSA, stack SSA, heap SSA, persistent HOT phi nodes, or deeper `hot_verify_ssa(...)` checks. Those remain new-design work requiring tests first and an IR2 contract update.
