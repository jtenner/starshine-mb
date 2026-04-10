# 0059 - IR2 Architecture Rules

## Scope

Lock the optimizer rebuild around exactly two owned representations: boundary module form and hot function IR.

## Current Behavior

- Boundary parsing, validation, encode/decode, and debug surfaces already operate on `@lib.Module` and `@lib.Expr`.
- `src/ir` now has dedicated architecture, cache, CFG, SSA, lift/lower, and hot-storage modules, while `src/ir/hot.mbt` acts as a compatibility-free facade over them.
- Pass execution now routes through the real `jtenner/starshine/passes` hot pipeline, and deleted compatibility shims must not return.

## Architecture Rules

- `HotFunc` is the only owned optimizer body representation.
- Boundary decode/encode/validation/debug stay boundary-form only.
- Derived analyses are overlays keyed by `revision`, not owned IR:
  - CFG
  - dominance
  - post-dominance
  - liveness
  - use-def
  - effects
  - loop info
  - SSA
- Pass contract is `lift -> verify -> analyze -> mutate -> verify -> lower`.
- Semantic mutation must go through public mutation APIs and bump `revision`.
- No compatibility API may be added for deleted recursive optimizer-body ownership.

## Package Split

The `src/ir` package should continue to grow by dedicated modules, not by extending one monolithic file indefinitely.

- `architecture.mbt`: architecture helpers that later pass-manager and cache slices share now.
- `analysis_cache.mbt`: revision-keyed cached overlays for CFG, dominance, post-dominance, loop info, use-def, liveness, effects, and SSA.
- `cfg*.mbt`: CFG construction plus the locked control-flow contract and traversal-order helpers.
- `dominators.mbt`, `postdominators.mbt`, `loop_info.mbt`, `use_def.mbt`, `liveness.mbt`, `effects.mbt`: derived analysis overlays.
- `ssa_policy.mbt`, `ssa_local.mbt`, `ssa_destroy.mbt`: locals-only SSA policy, construction, and destruction.
- `hot_core.mbt`: owned dense storage contract.
- `hot_flags.mbt`: opcode-local raw flag model.
- `hot_types.mbt`: deterministic type interning.
- `hot_labels.mbt`: label ownership and control-region metadata.
- `hot_side_tables.mbt`: typed side-table ownership.
- `hot_builders.mbt`: safe public constructors.
- `hot_mutate.mbt`: authoritative semantic mutation surface.
- `hot_query.mbt`: stable structural queries.
- `hot_walk.mbt`, `hot_region_edit.mbt`, `hot_module_context.mbt`, `hot_verify.mbt`, `hot_lift.mbt`, and `hot_lower.mbt`: shared traversal, region-edit, module-context, verification, and boundary conversion layers.

`hot.mbt` now acts as facade glue over the split modules; it should keep shrinking, not re-accumulate ownership or analysis logic.

## Correctness Constraints

- No new owned optimizer IR beside `HotFunc`.
- Derived overlays must invalidate through `revision` semantics.
- Pass descriptors must truthfully declare requirements and invalidations.
- Public docs must not imply deleted typed-tree or recursive optimizer ownership layers still exist.

## Validation Plan

- Add `src/ir/architecture_test.mbt` coverage for `hot_revision_current` and pass-descriptor metadata helpers.
- Run README/API sync so the public package surface stays aligned with `pkg.generated.mbti`.
- Refresh package docs and `agent-todo.md` so the next slice starts from the agreed module map.

## Performance Impact

This slice is architectural only. Runtime impact is negligible because it adds read-only revision access and pass-descriptor metadata helpers.

## Open Questions

- Whether revision invalidation stays conservative for all semantic mutation in v1 or becomes more granular once analysis caches land.
- Whether the remaining facade helpers in `hot.mbt` should split further or stay as a thin convenience layer once downstream consumers stabilize.
