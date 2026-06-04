---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../../raw/research/0709-2026-06-04-reorder-locals-preset-scheduling-reconciliation.md
  - ../../../raw/research/0552-2026-05-08-simplify-locals-nostructure-ordered-slot-replay.md
  - ../../../raw/binaryen/2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0434-2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0239-2026-04-21-tuple-optimization-starshine-code-map-followup.md
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-strategy.md
  - ./implementation-structure-and-tests.md
  - ./implementation-map.md
  - ./wat-shapes.md
  - ./scheduler-and-gates.md
  - ./reduced-repros-and-evidence.md
  - ./parity.md
---

# Starshine HOT-IR strategy for `tuple-optimization`

## First principle

- Starshine does not start from Binaryen's explicit tuple-local AST shape.
- HOT lift usually turns the same semantic situation into:
  - one multi-result producer
  - a spill ladder of scalar locals
  - optional copy groups rebuilt from those locals
  - optional host `local.tee` traffic
- So the local pass works backwards from scalar traffic to reconstruct the same safe-bundle idea that Binaryen expresses with tuple locals.

That is the central local teaching rule:

- upstream Binaryen is a tuple-local scalarizer
- Starshine is a HOT-native bundle recognizer and scalarizer

## Exact code-location map

For the full owner map, use [`./implementation-map.md`](./implementation-map.md).
The most important exact locations are:

### Public surface and wiring

- [`src/passes/tuple_optimization.mbt:97`](../../../../../src/passes/tuple_optimization.mbt)
  - `tuple_optimization_descriptor()`
- [`src/passes/tuple_optimization.mbt:114`](../../../../../src/passes/tuple_optimization.mbt)
  - `tuple_optimization_summary()`
- [`src/passes/pass_manager.mbt:8699`](../../../../../src/passes/pass_manager.mbt)
  - active hot-pass dispatch
- [`src/passes/optimize.mbt:212`](../../../../../src/passes/optimize.mbt)
  - registry entry
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - exact-slot prerequisite check plus the current public tuple/no-structure preset lane ending in `vacuum -> reorder-locals -> remove-unused-brs`
- [`src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
  - exact-slot tests for the tuple/no-structure neighborhood and the single public `reorder-locals` occurrence
- [`src/passes/registry_test.mbt:172-185`](../../../../../src/passes/registry_test.mbt)
  - active-hot-pass acceptance test

### Analysis and grouping

- [`src/passes/tuple_optimization.mbt:134`](../../../../../src/passes/tuple_optimization.mbt)
  - seed spill-group matcher
- [`src/passes/tuple_optimization.mbt:245-360`](../../../../../src/passes/tuple_optimization.mbt)
  - payload-source recovery helpers
- [`src/passes/tuple_optimization.mbt:515`](../../../../../src/passes/tuple_optimization.mbt)
  - result-block copy-group matcher
- [`src/passes/tuple_optimization.mbt:894`](../../../../../src/passes/tuple_optimization.mbt)
  - scalar-forward copy-group matcher
- [`src/passes/tuple_optimization.mbt:1118`](../../../../../src/passes/tuple_optimization.mbt)
  - query-summary builder
- [`src/passes/tuple_optimization.mbt:1264-1680`](../../../../../src/passes/tuple_optimization.mbt)
  - direct-use and forwarded-use predicates
- [`src/passes/tuple_optimization.mbt:1702`](../../../../../src/passes/tuple_optimization.mbt)
  - host-lane finalization
- [`src/passes/tuple_optimization.mbt:1864`](../../../../../src/passes/tuple_optimization.mbt)
  - badness propagation
- [`src/passes/tuple_optimization.mbt:1901-1935`](../../../../../src/passes/tuple_optimization.mbt)
  - analysis entry points

### Rewrite planning and execution

- [`src/passes/tuple_optimization.mbt:1955-2132`](../../../../../src/passes/tuple_optimization.mbt)
  - rewrite-eligibility and suppression rules
- [`src/passes/tuple_optimization.mbt:2282`](../../../../../src/passes/tuple_optimization.mbt)
  - rewrite-mask builder
- [`src/passes/tuple_optimization.mbt:2322-2676`](../../../../../src/passes/tuple_optimization.mbt)
  - split-local allocation and reuse policy
- [`src/passes/tuple_optimization.mbt:2684-2902`](../../../../../src/passes/tuple_optimization.mbt)
  - root-slot and passthrough-chain placement
- [`src/passes/tuple_optimization.mbt:2941-3564`](../../../../../src/passes/tuple_optimization.mbt)
  - source-host, host-result, and tuple-carrier builders
- [`src/passes/tuple_optimization.mbt:3628-4242`](../../../../../src/passes/tuple_optimization.mbt)
  - concrete rewrite entry points
- [`src/passes/tuple_optimization.mbt:4750`](../../../../../src/passes/tuple_optimization.mbt)
  - good-component rewrite driver
- [`src/passes/tuple_optimization.mbt:4866-5256`](../../../../../src/passes/tuple_optimization.mbt)
  - cleanup cluster
- [`src/passes/tuple_optimization.mbt:5268`](../../../../../src/passes/tuple_optimization.mbt)
  - top-level pass runner

### Test and oracle coverage

- [`src/passes/tuple_optimization_wbtest.mbt:120-1109`](../../../../../src/passes/tuple_optimization_wbtest.mbt)
  - focused pass analysis / rewrite coverage
- [`src/cmd/cmd_wbtest.mbt:1998-2369`](../../../../../src/cmd/cmd_wbtest.mbt)
  - CLI and lowered-module validity lane
- [`src/cmd/cmd_native_wbtest.mbt:404-1281`](../../../../../src/cmd/cmd_native_wbtest.mbt)
  - direct Binaryen-oracle lane

## Strategy phases

### 1. Cheap candidate screening

The pass is still meant to be cheap on scalar-only functions.
The early screen is the seed-group scan, not a whole extra CFG or effects analysis.

Local rule:

- if no multivalue spill bridge is visible, do nothing quickly

Relevant code:

- `tuple_optimization_collect_seed_group(...)`
- `tuple_optimization_collect_seed_groups(...)`

### 2. Reconstruct tuple-like groups from scalar traffic

The first real Starshine job is to recognize that some scalar locals still represent one tuple-like bundle.

It starts with direct spill bridges:

- one multi-result producer
- one defining `local.set` / `local.tee` per lane
- distinct lane locals

Then it widens to copy-connected groups through:

- result-block rebuilds
- scalar-forward bridges
- exact-copy payload recovery

This is the local equivalent of Binaryen's tuple-local copy-component reasoning.

Relevant code:

- `tuple_optimization_collect_seed_group(...)`
- `tuple_optimization_collect_result_block_copy_group(...)`
- `tuple_optimization_collect_scalar_forward_copy_group(...)`
- payload-source helpers at `:245-360`

### 3. Classify safe versus unsafe forwarded use

The local pass spends much more code here than upstream Binaryen because HOT input is less explicit.
The key question is not “is this still a tuple local?” but:

- “does this scalar traffic still behave like one safe nonescaping bundle?”

So the local implementation builds a query summary and then asks narrow questions about:

- direct non-scalar use
- direct non-drop use
- forwarded non-scalar use
- forwarded host-tee use
- invalid scalar copy-through shapes

Relevant code:

- `tuple_optimization_build_query_summary(...)`
- forwarded-use predicates at `:1264-1680`

### 4. Preserve host-lane semantics explicitly

The hardest local problem is usually not bundle discovery.
It is preserving the one scalar value that still has to flow through the surrounding expression after the tuple bundle is split.

That is why the host-lane helpers are central:

- `tuple_optimization_finalize_host_lanes(...)`
- `tuple_optimization_count_lane_traffic(...)`
- rewrite-mask and host-consumer predicates

This is the main local difference from the beginner-friendly upstream story.
Binaryen can talk in terms of tuple locals and `tuple.extract`; Starshine has to preserve a scalar host result across HOT root placement and later lowering.

### 5. Poison copy-connected components conservatively

Like Binaryen, Starshine keeps the conservative rule:

- copy-connected components succeed or fail together

The local explicit badness step is:

- `tuple_optimization_propagate_badness(...)`

That keeps the port honest.
The pass does not try to rescue half-safe groups once some copy-connected part escapes the approved surface.

### 6. Separate “safe” from “worth rewriting”

Starshine adds a practical layer that is much more visible than in upstream docs:

- some groups are safe
- but not all safe groups are worth rewriting

The rewrite-mask policy is the local answer to several artifact families where forcing a tuple carrier back into already-scalar traffic made things worse or harder to lower cleanly.

Relevant code:

- `tuple_optimization_group_should_rewrite(...)`
- `tuple_optimization_group_should_rewrite_in_func(...)`
- `tuple_optimization_build_group_rewrite_mask(...)`

### 7. Place rewritten carriers at legal root slots

The pass is often not replacing one expression with another.
It is staging a sequence of scalar writes while still preserving one visible result.
So root-slot and anchor placement are part of correctness, not just code style.

Relevant code:

- `tuple_optimization_find_root_slot_in_region(...)`
- `tuple_optimization_find_root_slot(...)`
- `tuple_optimization_pick_root_anchor_slot(...)`
- passthrough-root helpers at `:2830-2902`

### 8. Choose scalar lanes or tuple carriers based on shape

The local builders intentionally keep both options alive:

- stay on scalar locals when possible
- build a typed tuple carrier when root or copyback placement requires one

That split is one reason the local pass has more surface area than Binaryen's tuple-local AST rewrite.

Relevant code:

- `tuple_optimization_build_tuple_make_from_locals(...)`
- host-carrier builders at `:3155-3250`
- copy-carrier builders at `:3297-3564`

### 9. Clean up only the pass-owned debris

The cleanup rule is intentionally conservative.
The pass should erase the scaffolding it introduced, but it should not opportunistically reorder unrelated local layout just because it happens to be nearby.

Relevant code:

- `tuple_optimization_cleanup_drop_local_tees(...)`
- `tuple_optimization_cleanup_scalarized_tuple_locals(...)`
- `tuple_optimization_cleanup_unused_body_locals(...)`
- `tuple_optimization_cleanup_post_rewrite(...)`

## Main local differences from upstream Binaryen

Cross-check this section with [`./binaryen-strategy.md`](./binaryen-strategy.md).

### Same high-level goal

Both implementations try to:

- identify tuple-like scratch storage
- reject escaping copy components
- expose scalar locals so later cleanup can do more work

### Different representation and therefore different proof surface

Binaryen works from:

- tuple locals
- `tuple.make`
- `tuple.extract`

Starshine works from:

- multi-result producers
- scalar spill ladders
- scalar-forward bridges
- root-slot placement
- later lowering / writeback concerns

### Important local non-goals

The local pass should still not be described as:

- a generic multivalue lowering pass
- a general CFG tuple optimizer
- a proof that every safe group should always get a tuple carrier

## Where to go next

- Use [`./wat-shapes.md`](./wat-shapes.md) for concrete before/after families.
- Use [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream tuple-local oracle.
- Use [`./implementation-map.md`](./implementation-map.md) when you need the exact MoonBit owner file or test lane.
- Use [`./scheduler-and-gates.md`](./scheduler-and-gates.md) for why the explicit pass exists but the public presets still keep it off.
- Use [`./reduced-repros-and-evidence.md`](./reduced-repros-and-evidence.md) and [`./parity.md`](./parity.md) for current local proof state.

## Maintenance rule

- Keep this page focused on the local strategy and the most important exact code locations.
- Put deeper owner-file inventories and test-lane maps in [`./implementation-map.md`](./implementation-map.md).
- If a new parity fix changes the owning helper cluster, update this page, the implementation map, and either [`./reduced-repros-and-evidence.md`](./reduced-repros-and-evidence.md) or [`./parity.md`](./parity.md) in the same change.
