---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./binaryen-strategy.md
  - ./scheduler-and-gates.md
  - ./reduced-repros-and-evidence.md
  - ./parity.md
---

# Starshine HOT-IR Strategy For `tuple-optimization`

## First Principle

- Starshine does not start from Binaryen's explicit tuple-local AST shape.
- HOT lift usually turns the same semantic situation into:
  - one multi-result producer
  - a set of scalar spill locals
  - optional copy groups rebuilt from those locals
  - optional host `local.tee` traffic
- The Starshine pass therefore works backwards from local traffic, not from explicit tuple nodes.

## Pass Entry And Cheap No-Op Screen

The pass descriptor in `src/passes/tuple_optimization.mbt`:

- requires `use_def`
- invalidates CFG, dominance, liveness, use-def, effects, loop-info, and SSA

The initial fast screen is `tuple_optimization_may_have_candidates(...)`.

What it checks:

- some live node has `result_arity > 1`
- some live node writes locals through `LocalSet` or `LocalTee`

Why this screen exists:

- tuple-opt belongs in an early local-cleanup slot
- it must skip scalar-only functions quickly
- the pass should not pay analysis cost on functions with no plausible multivalue bridge traffic

## Phase 1: Seed Group Discovery

The first concrete object is `HotTupleOptimizationGroup`.

Each group tracks:

- `producer`
- `lane_locals`
- `defining_nodes`
- optional `host_lane`
- optional `copy_source`
- optional `copy_payload_locals`
- `uses`
- `valid_uses`
- `neighbors`
- `bad`

Seed groups come from `tuple_optimization_collect_seed_group(...)`.

That function requires:

- a producer with `result_arity > 1`
- exactly one child use per result lane
- every use to be a `LocalSet` or `LocalTee`
- all lane locals to be distinct

Why this matches the Binaryen spirit:

- it identifies the initial multi-result spill bridge
- it already refuses ambiguous or duplicated lane ownership
- it derives the first host lane from the first defining `LocalTee`

## Phase 2: Local-To-Group Ownership

`tuple_optimization_build_local_group_ids(...)` maps each lane local to its group id.

Why this matters:

- later analysis needs to recognize when a scalar local read is really reading one lane of an already-known tuple-like component
- copy groups and forwarded-lane groups are discovered from those local relationships

## Phase 3: Copy-Payload Resolution

The pass has a dedicated set of helpers for lane-source recovery:

- `tuple_optimization_try_payload_source_read(...)`
- `tuple_optimization_resolve_copy_payload_local(...)`
- `tuple_optimization_collect_copy_payload_lane_nodes(...)`
- `tuple_optimization_pick_copy_lane_source_node(...)`

What these do:

- follow trivial `local.get` and tee-backed reads
- recover which source lane local is feeding each copied lane
- tolerate one-hop alias and forwarding cases that are still semantically just tuple-lane transport

Why this exists at all:

- real HOT input does not always rebuild a copy group as a neat `block (result ...)`
- some debug-artifact families forward one or more lanes directly through scalar locals before reconstructing another group
- without payload resolution, those families fall out of analysis before rewrite

## Phase 4: Discover Additional Copy Groups

Starshine extends beyond the simple seed groups through two major collectors:

- `tuple_optimization_collect_result_block_copy_group(...)`
- `tuple_optimization_collect_scalar_forward_copy_group(...)`

The first handles:

- explicit result-block rebuilds of a copied lane bundle
- exact-copy carriers that still look tuple-like in HOT

The second handles:

- one-hop scalar-forward copies
- mixed direct-and-forwarded bridges
- chained scalar-forward families that still preserve one coherent lane bundle

The corresponding graph-linking helpers are:

- `tuple_optimization_link_result_block_copy_groups(...)`
- `tuple_optimization_link_scalar_forward_copy_groups(...)`
- `tuple_optimization_add_neighbor(...)`

Practical effect:

- Starshine reconstructs the same connected-component idea Binaryen uses, but from lifted scalar traffic instead of explicit tuple locals

## Phase 5: Validate Uses Conservatively

The pass contains many local-traffic predicates because the safety question in HOT is not "is this a tuple local?" but "is this scalar local traffic still representing one unescaped lane bundle?"

Important validators include:

- `tuple_optimization_node_has_direct_non_scalar_use(...)`
- `tuple_optimization_node_has_direct_non_drop_use(...)`
- `tuple_optimization_local_has_forwarded_non_scalar_use(...)`
- `tuple_optimization_local_has_forwarded_non_drop_use(...)`
- `tuple_optimization_local_has_forwarded_drop_use(...)`
- `tuple_optimization_local_has_forwarded_any_use(...)`
- `tuple_optimization_local_has_forwarded_host_tee_use(...)`
- `tuple_optimization_read_is_invalid_scalar_copy_through(...)`

These are the HOT-native equivalents of Binaryen's `uses` versus `validUses` distinction.

What they guard against:

- a lane escaping to unsupported consumers
- a copied lane being mixed with unrelated scalar traffic
- mistaking a scalar convenience alias for a safe tuple-copy lane when it actually changes semantics

## Phase 6: Finalize Host-Lane And Traffic Facts

Additional analysis helpers determine how much of a component still behaves like a tuple bundle:

- `tuple_optimization_finalize_host_lanes(...)`
- `tuple_optimization_find_overlap_lane_between_groups(...)`
- `tuple_optimization_count_lane_traffic(...)`

Why host-lane tracking is central:

- many of the hard repros are not about whether the bundle is safe
- they are about whether the one live host lane must remain yielded as a scalar tee result while the other lanes are dropped or copied

Why overlap tracking is central:

- overlapping exact-copy groups can write back into a source lane
- that is still valid sometimes, but only if the rewrite preserves read-before-write semantics

## Phase 7: Propagate Badness

`tuple_optimization_propagate_badness(...)` is the explicit Binaryen-style component poison step.

What becomes bad:

- any group with invalid traffic
- any group connected by copy edges to such a group

What this preserves from Binaryen exactly:

- connected components succeed or fail together
- the pass stays conservative instead of trying to patch through half-safe copy chains

## Phase 8: Decide What Actually Rewrites

Not every good analysis group is rewritten.

Key rewrite-decision helpers:

- `tuple_optimization_group_should_rewrite(...)`
- `tuple_optimization_group_should_rewrite_in_func(...)`
- `tuple_optimization_copy_group_has_mixed_direct_and_forwarded_lanes(...)`
- `tuple_optimization_copy_group_redundant_with_source_host_chain(...)`
- `tuple_optimization_group_has_nested_rootslot_host_copy_wrapper(...)`
- `tuple_optimization_has_nested_rootslot_host_copy_wrapper_group(...)`
- `tuple_optimization_source_group_has_host_copy_consumer(...)`
- `tuple_optimization_source_group_has_rewritten_host_copy_consumer(...)`
- `tuple_optimization_source_group_has_rewritten_copy_consumer(...)`
- `tuple_optimization_source_group_host_copy_consumer_needs_preserved_lanes(...)`

Why Starshine needs this extra suppression layer:

- Binaryen's literal tuple-local rewrite is simpler because the tuple local is the carrier.
- In HOT, some groups are already "scalar enough" or become worse if we force them back through an unnecessary carrier.
- The pass therefore distinguishes:
  - safe group
  - safe and worth rewriting
  - safe but better left scalarized

Important conservative suppressions surfaced by the current branch:

- nested rootslot host-copy wrapper guard
- copy groups that are redundant with a rewritten upstream host chain
- terminal families where only one lane survives and the rest only feed drops

## Phase 9: Plan Rewrite Order And Local Allocation

Once the rewrite mask exists, the pass plans execution order and fresh locals with:

- `tuple_optimization_build_group_rewrite_mask(...)`
- `tuple_optimization_collect_rewrite_order_visit(...)`
- `tuple_optimization_collect_rewrite_order(...)`
- `tuple_optimization_ensure_split_locals(...)`
- `tuple_optimization_require_local_type(...)`

Two important Starshine-specific choices happen here:

- Some groups reuse existing lane locals instead of allocating fresh split locals.
- Some groups allocate dedicated split locals or typed carriers because reusing the existing scalar lanes would perturb ordering or alias semantics.

That decision is mediated by helpers such as:

- `tuple_optimization_group_needs_dedicated_split_locals(...)`
- `tuple_optimization_split_reuses_group_lanes(...)`
- `tuple_optimization_lane_locals_are_strictly_increasing(...)`
- `tuple_optimization_copy_group_has_local_overlap(...)`
- `tuple_optimization_no_host_copy_group_can_scalarize_directly(...)`

## Phase 10: Find The Correct Root Or Anchor Slot

The pass then has to place rewritten code in a legal HOT region slot.

Key helpers:

- `tuple_optimization_find_root_slot_in_region(...)`
- `tuple_optimization_find_root_slot(...)`
- `tuple_optimization_pick_root_anchor_slot(...)`
- `tuple_optimization_find_passthrough_root_chain_step(...)`
- `tuple_optimization_find_passthrough_root_chain(...)`
- `tuple_optimization_wrap_passthrough_root_chain(...)`

Why this placement problem is hard:

- the pass is not just replacing one expression with another
- it often needs to emit a sequence of scalar sets and still preserve one scalar host result
- the result may belong to a function root, a block result, or a branch exit

## Phase 11: Build Replacements

The rewrite builders divide roughly into source-group rewrites and copy-group rewrites.

Important source-group builders:

- `tuple_optimization_build_source_host_replacement(...)`
- `tuple_optimization_build_source_passthrough_init_root(...)`
- `tuple_optimization_build_source_root_anchor_replacement(...)`
- `tuple_optimization_build_source_root_carrier_replacement(...)`
- `tuple_optimization_build_source_nested_root_tuple_carrier_replacement(...)`
- `tuple_optimization_build_root_carrier_replacement_from_producer(...)`

Important copy-group builders:

- `tuple_optimization_build_copy_host_replacement(...)`
- `tuple_optimization_build_copy_root_anchor_replacement(...)`
- `tuple_optimization_build_copy_root_anchor_tuple_carrier_replacement(...)`
- `tuple_optimization_build_copy_root_carrier_replacement(...)`
- `tuple_optimization_build_host_carrier_replacement_from_locals(...)`
- `tuple_optimization_build_host_carrier_replacement_from_producer(...)`

Shared carrier helpers:

- `tuple_optimization_build_tuple_make_from_locals(...)`
- `tuple_optimization_lane_copy_needs_tuple_carrier(...)`
- `tuple_optimization_copy_rewrite_needs_tuple_carrier(...)`

What these builders are trying to preserve:

- Binaryen-equivalent scalarization when the group can stay scalar
- a typed multivalue carrier when root or copyback placement needs one
- original host-tee semantics when a lane is simultaneously a tuple carrier and a scalar result value

## Phase 12: Apply Root Rewrites

The concrete root rewrite entry points include:

- `tuple_optimization_try_rewrite_root_host_copy_group_defs(...)`
- `tuple_optimization_try_rewrite_root_no_host_copy_group_defs(...)`
- `tuple_optimization_try_rewrite_root_no_host_source_group_defs(...)`
- `tuple_optimization_try_rewrite_anchor_host_copy_group_defs(...)`
- `tuple_optimization_try_rewrite_direct_scalar_copy_group_defs(...)`
- `tuple_optimization_rewrite_group_defs(...)`
- `tuple_optimization_rewrite_good_components(...)`

These are where the recent bug-fix history has concentrated:

- non-canonical root carriers
- overlap-aware exact-copy copyback
- nested branch-exit source roots
- terminal host-drop tails
- chained host-copy `tail-live0`

## Phase 13: Cleanup After Rewrite

The rewrite intentionally leaves cleanup to a smaller local pass stage inside the implementation:

- `tuple_optimization_cleanup_drop_local_tees(...)`
- `tuple_optimization_cleanup_scalarized_tuple_locals(...)`
- `tuple_optimization_cleanup_unused_body_locals(...)`
- `tuple_optimization_prune_nops_in_region(...)`
- `tuple_optimization_cleanup_post_rewrite(...)`

Important current rule:

- cleanup preserves unused original body locals
- cleanup only prunes unused locals appended by tuple-opt itself

Why that rule exists:

- earlier cleanup was too aggressive and changed unrelated body-local layout
- that broke direct native parity checks even when the tuple rewrite itself was otherwise correct

## Current Durable Design Conclusions

- The Starshine port is a HOT-native component-analysis pass, not an AST translation of Binaryen's tuple local pass.
- The most important Binaryen contract being preserved is conservative component safety, not explicit tuple syntax.
- Host-lane preservation and root-slot placement are the hardest parts of the Starshine implementation.
- Several exact-shape failures now live past the tuple rewrite itself and into later lowering or final emitted local-order shape, which means future work must separate "analysis bug," "rewrite bug," and "post-rewrite/lowering drift" much more carefully.

## Practical Rule For Future Work

- If a bug shows the HOT graph was already correct before lowering, treat it as a lowering or final-shape bug, not a tuple-analysis bug.
- If a bug disappears when a group is left scalarized, check rewrite-mask suppression before inventing a new carrier.
- If a bug only appears when one host lane survives and all other lanes become drops, inspect host-lane staging and anchor-root placement first.

