---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-unsubtyping-current-main-recheck.md
  - ../../../raw/research/0444-2026-05-05-unsubtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md
  - ../../../raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./descriptor-squares-casts-and-js-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../abstract-type-refining/index.md
  - ../type-refining/index.md
  - ../global-struct-inference/index.md
  - ../remove-unused-types/index.md
  - ../tracker.md
---

# Starshine port-readiness and validation for `unsubtyping`

Use this page together with the overview in [`./index.md`](./index.md), the Binaryen strategy in [`./binaryen-strategy.md`](./binaryen-strategy.md), the implementation-and-test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), the descriptor and JS boundary guide in [`./descriptor-squares-casts-and-js-boundaries.md`](./descriptor-squares-casts-and-js-boundaries.md), the shape catalog in [`./wat-shapes.md`](./wat-shapes.md), and the current Starshine status map in [`./starshine-strategy.md`](./starshine-strategy.md).

This page answers a narrower question: **what is the safest route from today's boundary-only Starshine status to a validated future port?**

## Current local starting point

`unsubtyping` is still a **boundary-only** compatibility name in Starshine.
The local code accepts the spelling but refuses to run a transform.
The current code surfaces are still only:

- boundary-only pass-name tracking: [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
- boundary-only request rejection: [`src/passes/optimize.mbt#L519-L523`](../../../../../src/passes/optimize.mbt#L519-L523)
- module-pass dispatcher gap: [`src/passes/pass_manager.mbt#L8912-L8940`](../../../../../src/passes/pass_manager.mbt#L8912-L8940)
- type graph representation: [`src/lib/types.mbt#L29-L130`](../../../../../src/lib/types.mbt#L29-L130)
- type-section and descriptor roundtrip fixtures: [`src/wast/module_wast_tests.mbt#L308-L407`](../../../../../src/wast/module_wast_tests.mbt#L308-L407)
- exact / bottom descriptor refs: [`src/wast/ref_null_exact_surface_test.mbt#L1-L85`](../../../../../src/wast/ref_null_exact_surface_test.mbt#L1-L85)
- pass-port batch breadcrumb: [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L59`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L59)
- active backlog gap: [`agent-todo.md`](../../../../../agent-todo.md)

There is still no owner file or dedicated `unsubtyping` request test.

## Why this is not a HOT peephole

Binaryen's `unsubtyping` is a module-wide type-graph rewrite.
A faithful Starshine port therefore needs module-level work:

1. collect validation-driven subtype and descriptor requirements;
2. preserve public heap types and other public boundaries;
3. model JS boundary flow and descriptor exposure narrowly;
4. preserve ordinary and exact cast observability correctly;
5. keep descriptor-square completion in the fixed point;
6. fix descriptor-bearing allocations before rewriting private types;
7. rewrite private `SubType` / `TypeMetadata` relations consistently;
8. refinalize after the graph changes.

A HOT-only tree rewrite under the `unsubtyping` name would misrepresent the upstream contract.

## First implementation slice

The safest first slice is a **type-graph planner with no rewrite**.
It should compute the required relation closure and expose it to tests before it mutates the module.

Minimum planner responsibilities:

- seed required relations from validation, casts, descriptors, JS boundaries, and public edges
- distinguish ordinary casts from exact casts
- track descriptor-square closure explicitly
- keep nullable descriptor traps visible when `trapsNeverHappen` does not apply
- treat `ref.eq`-style non-flow constraints as non-edges for user-type unsubtyping
- report which private relations would be removed or retained

Local source surfaces already available:

- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt) has the `HeapType`, `RefType`, `SubType`, `RecType`, and descriptor graph representation needed for the planner.
- [`src/wast/module_wast_tests.mbt`](../../../../../src/wast/module_wast_tests.mbt) and [`src/wast/ref_null_exact_surface_test.mbt`](../../../../../src/wast/ref_null_exact_surface_test.mbt) already cover parser / lowerer / validator roundtrips for many of the interesting shapes.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) already gives the honest boundary-only rejection path.

## Required future implementation shape

A future implementation should land as a module/type-graph pass, not as a HOT expression cleanup.

Minimum data-model requirements:

- one module-wide relation graph over private heap types;
- separate subtype and descriptor edge sets;
- public-boundary freezing;
- JS boundary exposure markers;
- cast-observability markers for ordinary and exact casts;
- trap-preservation markers for nullable descriptor allocations;
- a lifecycle model that can be invalidated after later transforms.

Minimum algorithmic requirements:

- compute the initial required edges from validation, JS, and descriptor surfaces;
- run a fixed point until no new required edge is discovered;
- preserve exact cast observability without over-preserving ordinary-cast chains;
- rewrite private declarations only after the closure is known;
- repair descriptor allocations before type rewrite;
- refinalize the module afterward.

## Registry and dispatcher sequencing

Do not move `unsubtyping` out of boundary-only status until the planner and validation hooks exist.

When the first real slice lands, the minimum code changes should include:

- a module/type-graph owner file;
- a registry category change in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt);
- a dispatcher arm in the module-pass path once the pass exists;
- tests that prove explicit `--unsubtyping` no longer fails only after real relation closure and rewrite exist;
- no default preset scheduling unless a later consumer payoff is also proven.

## Validation ladder

### Planner-only tests

- public type freeze stays intact;
- direct validation constraints seed the expected edges;
- exact casts keep the smaller relation surface;
- ordinary casts keep only the edges needed for observable success;
- descriptor squares close transitively;
- nullable descriptor traps are preserved only when required;
- JS boundary exposure keeps only the narrow descriptor edges it should.

### Rewrite tests

- private subtype edges collapse only when the closure proves them unnecessary;
- descriptor edges disappear independently when unobservable;
- descriptor-bearing allocations are repaired before type rewrite;
- refinalization keeps the final module valid;
- the combined `--unsubtyping --remove-unused-types` result still matches Binaryen's tested shrink behavior.

### Binaryen oracle tests

Use the full upstream pass, then the common cleanup combo:

- `wasm-opt --unsubtyping`
- `wasm-opt --unsubtyping --remove-unused-types`

For Starshine fuzzing, compare the combined cleanup path rather than expecting a standalone type rewrite to normalize into different text output.

## Main risks

- **Over-removing public or JS-visible relations:** the pass must freeze the right boundaries.
- **Missing descriptor-square closure:** relation removal can become unsound if descriptors and supertypes are pruned independently.
- **Trap preservation regressions:** nullable descriptor allocations are not just dead data.
- **Stale relation metadata:** later mutating passes can invalidate the graph.
- **Scheduler overreach:** the current tree still treats `unsubtyping` as boundary-only, so a port should not be hidden behind a preset until the rewrite is honest.

## Definition of done for a faithful first local port

A first local implementation is worth calling `unsubtyping` only when it has:

- a module/type-graph owner file;
- registry and dispatcher support;
- a closure planner with separate subtype and descriptor facts;
- public-boundary, JS-boundary, and exact-cast guards;
- descriptor-allocation repair and refinalization;
- planner-only tests for direct, transitive, descriptor, JS, and cast cases;
- rewrite tests for the simple private-type family;
- an explicit invalidation or discard story for later mutating passes.

Until then, keep the boundary-only status described in [`./starshine-strategy.md`](./starshine-strategy.md).

## Related pages

- Overview: [`./index.md`](./index.md)
- Binaryen strategy: [`./binaryen-strategy.md`](./binaryen-strategy.md)
- Upstream file/test map: [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- Descriptor and JS boundaries: [`./descriptor-squares-casts-and-js-boundaries.md`](./descriptor-squares-casts-and-js-boundaries.md)
- Shape catalog: [`./wat-shapes.md`](./wat-shapes.md)
- Current Starshine status: [`./starshine-strategy.md`](./starshine-strategy.md)
- Raw source manifest: [`../../../raw/binaryen/2026-05-05-unsubtyping-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-unsubtyping-current-main-recheck.md)
- Research follow-up: [`../../../raw/research/0444-2026-05-05-unsubtyping-current-main-recheck.md`](../../../raw/research/0444-2026-05-05-unsubtyping-current-main-recheck.md)
- Legacy raw source manifest: [`../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md`](../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md)
- Legacy research follow-up: [`../../../raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md`](../../../raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md)
