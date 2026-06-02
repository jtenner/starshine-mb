---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-unsubtyping-current-main-recheck.md
  - ../../../raw/research/0444-2026-05-05-unsubtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md
  - ../../../raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../type-refining/index.md
  - ../global-struct-inference/index.md
  - ../abstract-type-refining/index.md
  - ../remove-unused-types/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./descriptor-squares-casts-and-js-boundaries.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../type-refining/index.md
  - ../global-struct-inference/index.md
  - ../abstract-type-refining/index.md
  - ../remove-unused-types/index.md
---

# Starshine Strategy For `unsubtyping`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md`](../../../raw/binaryen/2026-04-24-unsubtyping-primary-sources.md).
The 2026-05-05 current-main recheck did not change the boundary-only status; the missing implementation ladder now lives in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main infrastructure gaps a future parity port must resolve.

## The honest current status

`unsubtyping` is still **unimplemented** in Starshine.
There is no `src/passes/unsubtyping.mbt`, `src/passes/un_subtyping.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `unsubtyping` in the registry as a known boundary-only name
- reject active requests honestly instead of silently no-oping
- keep the upstream closed-world scheduler role visible in the wiki
- keep its absence from the canonical open-world no-DWARF path explicit
- keep the missing dedicated backlog slice explicit
- document why a future port is type-section/module-owned work, not a HOT peephole

So this is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
    - `pass_registry_boundary_only_names()` includes `"unsubtyping"`
- registry entry construction for boundary-only names
  - [`src/passes/optimize.mbt#L266-L268`](../../../../../src/passes/optimize.mbt#L266-L268)
    - each boundary-only name becomes a boundary-only registry entry through `pass_registry_entry_boundary_only(...)`
- active request guard for boundary-only passes
  - [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- generic boundary-only request coverage
  - [`src/cmd/fuzz_harness_wbtest.mbt#L198-L217`](../../../../../src/cmd/fuzz_harness_wbtest.mbt#L198-L217)
    - the current representative boundary-only request test uses `global-struct-inference-desc-cast`, not `unsubtyping`
- registry-planning breadcrumb
  - [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L59`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L59)
    - `unsubtyping` is grouped with boundary-only type/global/signature shaping names
- type-section representation a future port would have to rewrite
  - [`src/lib/types.mbt#L29-L130`](../../../../../src/lib/types.mbt#L29-L130)
    - `HeapType`, `RefType`, `TypeIdx`, `TypeMetadata`, `SubType`, and `RecType` encode the basic graph surface
- custom-descriptor and subtype WAT roundtrip fixtures a future port would reuse for regression shape coverage
  - [`src/wast/module_wast_tests.mbt#L308-L407`](../../../../../src/wast/module_wast_tests.mbt#L308-L407)
    - subtype metadata, descriptors, arrays, structs, and rec groups roundtrip through WAT
  - [`src/wast/ref_null_exact_surface_test.mbt#L1-L85`](../../../../../src/wast/ref_null_exact_surface_test.mbt#L1-L85)
    - exact and bottom descriptor refs are already parsed, lowered, and validated
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `unsubtyping` in the active default route
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `unsubtyping` slice

That map is the durable local status today: the pass is known, intentionally unavailable, boundary-only, not in the open-world path, not assigned to an active implementation slice, and not backed by an owner file.

## Why this is not a HOT peephole

Binaryen's `unsubtyping` changes the module's type graph.
The transformed shapes can show up as local WAT snippets, but the proof is module-wide.
A faithful Starshine port would need to reason over:

- public versus private heap types
- declared subtype edges and descriptor/described edges
- function, global, table, element, tag, control-flow, call, and continuation validation constraints
- ordinary and exact cast success preservation
- JS boundary flow through `any` and `extern.convert_any`
- descriptor-square completion
- descriptor-bearing allocation fixups
- module-wide type-use rewriting
- refinalization after the graph changes

Those requirements cross package boundaries that current HOT expression passes do not own.
The right future landing shape is a module pass or a shared closed-world type-graph engine, not a small `HotFunc` rewrite.

## What Starshine currently does for the pass name

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `unsubtyping` in `pass_registry_boundary_only_names()`.
That means:

- the spelling remains discoverable in local registry behavior
- neighboring type-cluster docs can point at one consistent local status
- future port work has to intentionally move the pass into an implemented category

### 2. The active pipeline rejects it honestly

When a user requests a boundary-only pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a boundary-only error.
That behavior matters because:

- explicit pass requests do not silently pretend to rewrite subtype graphs
- the registry category remains executable documentation
- future implementation work will have to change the category and diagnostics intentionally

### 3. The pass-port map is only a registry disposition

The pass-port batch map records `unsubtyping` under boundary-only type/global/signature shaping names, but `agent-todo.md` has no dedicated current slice for it.
Treat that as a local status breadcrumb, not an implementation plan.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- require or explicitly model closed-world mode before rewriting subtype relations
- skip modules without the relevant GC/type surface
- freeze public heap types and public boundary relations
- seed required relations from validation, JS boundaries, descriptors, and cast-like operations
- distinguish ordinary casts from exact casts
- preserve guaranteed-success casts without over-preserving guaranteed-fail or uninhabited success cases
- keep descriptor-square completion in the fixed point
- model JS prototype keepalive narrowly, not as blanket descriptor retention
- preserve or explicitly eliminate nullable descriptor traps according to the traps-never-happen mode
- rewrite private `SubType` / `TypeMetadata` relations without corrupting rec groups
- rewrite all affected type uses across the module
- refinalize or equivalently re-typecheck after the graph changes
- keep the `--unsubtyping --remove-unused-types` combo-test caveat visible in documentation and tests

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./descriptor-squares-casts-and-js-boundaries.md`](./descriptor-squares-casts-and-js-boundaries.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Nearby boundaries to keep distinct

### `remove-unused-types`

See [`../remove-unused-types/index.md`](../remove-unused-types/index.md).

`remove-unused-types` can delete now-unused private heap types after `unsubtyping` removes relation edges.
Do not describe type-definition disappearance in upstream combo tests as if `unsubtyping` alone directly removes every vanished type.

### `abstract-type-refining`

See [`../abstract-type-refining/index.md`](../abstract-type-refining/index.md).

`abstract-type-refining` can rewrite never-created or singleton-child abstract type uses before `unsubtyping` prunes relations.
Do not file TNH singleton-child narrowing under `unsubtyping`; the unsubtyping-specific TNH behavior is descriptor-trap repair.

### `type-refining`

See [`../type-refining/index.md`](../type-refining/index.md).

`type-refining` tightens struct field and function/local use types earlier in the closed-world cluster.
`unsubtyping` later removes unnecessary declared subtype and descriptor edges from the final type graph.

### `global-struct-inference`

See [`../global-struct-inference/index.md`](../global-struct-inference/index.md).

`gsi` can expose new relation-pruning opportunities before `unsubtyping`, but it is still a global-origin / struct-field inference pass rather than a general subtype-graph minimizer.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep boundary-only rejection until the transform exists
   - when the pass lands, update registry category, help behavior, tests, tracker, and docs in the same change
2. type-section rewrite fixtures
   - unused private parent relation collapses
   - public type relations stay frozen
   - descriptor and described edges can be removed independently when unobservable
   - rec groups and descriptor metadata remain valid after rewrite
3. validation-flow fixtures
   - function results, global initializers, table/element initializers, branch payloads, calls, tags, EH, and continuations keep required subtype edges
   - non-flow basic constraints such as `ref.eq` do not over-preserve user relations
4. cast fixtures
   - ordinary casts preserve success only when concrete flowing types make success observable
   - exact casts preserve only the exact success surface
   - guaranteed-fail casts do not invent new relations
5. descriptor/JS fixtures
   - descriptor-square completion keeps implied edges
   - `ref.get_desc` and descriptor-aware casts keep observable descriptor edges
   - JS prototype keepalive follows the narrow descriptor-field rule
   - `extern.convert_any` exposure is modeled
6. source parity
   - compare focused `--unsubtyping` fixtures with Binaryen before composing with `remove-unused-types`
   - then compare the common `--unsubtyping --remove-unused-types` combo separately

## Bottom line

Current Starshine `unsubtyping` strategy is honest boundary-only tracking plus an explicit future-proofing map:

- the pass name is preserved at [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
- active requests are rejected at [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462)
- current generic boundary-only request coverage exists at [`src/cmd/fuzz_harness_wbtest.mbt#L198-L217`](../../../../../src/cmd/fuzz_harness_wbtest.mbt#L198-L217), but there is no `unsubtyping`-specific request test today
- the pass-port map keeps it boundary-only at [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L59`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md#L54-L59)
- the active backlog still has no dedicated slice
- there is no local owner file yet

So the right mental model today is:

- **no transform yet**
- **clear boundary-only registry behavior**
- **source-backed Binaryen `unsubtyping` contract**
- **future closed-world type-graph infrastructure still required**
- **no open-world no-DWARF parity obligation today**
