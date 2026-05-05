---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md
  - ../../../raw/research/0462-2026-05-05-type-merging-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md
  - ../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../remove-unused-types/index.md
  - ../type-refining/index.md
  - ../type-ssa/index.md
  - ../minimize-rec-groups/index.md
  - ../unsubtyping/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./dfa-partitions-casts-and-refinalization.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-types/index.md
  - ../type-refining/index.md
  - ../type-ssa/index.md
  - ../minimize-rec-groups/index.md
  - ../unsubtyping/index.md
---

# Starshine Strategy For `type-merging`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md) and the 2026-05-05 current-main bridge in [`../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, the new port-readiness bridge, and the main infrastructure gaps a future parity port must resolve.

## The honest current status

`type-merging` is still **unimplemented** in Starshine.
There is no `src/passes/type_merging.mbt`, `src/passes/type-merging.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `type-merging` in the registry as a known boundary-only name
- reject active requests honestly instead of silently no-oping
- keep the upstream closed-world GC/type-graph contract visible in the wiki
- keep its absence from the canonical open-world no-DWARF path explicit
- keep the missing dedicated backlog slice explicit
- document why a future port is type-section/module-owned work, not a HOT peephole

So this is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
    - `pass_registry_boundary_only_names()` includes `"type-merging"`
- registry entry construction for boundary-only names
  - [`src/passes/optimize.mbt#L264-L268`](../../../../../src/passes/optimize.mbt#L264-L268)
    - each boundary-only name becomes a boundary-only registry entry through `pass_registry_entry_boundary_only(...)`
- active request guard for boundary-only passes
  - [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- active preset absence
  - [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
    - the built-in `optimize` and `shrink` presets expand only the currently implemented module/HOT sequence and do not include `type-merging`
  - [`src/passes/registry_test.mbt#L129-L158`](../../../../../src/passes/registry_test.mbt#L129-L158)
    - the preset test asserts every expanded preset name is `HotPass` or `ModulePass`, which keeps boundary-only names out of the active default path
- type-section representation a future port would have to rewrite
  - [`src/lib/types.mbt#L41-L136`](../../../../../src/lib/types.mbt#L41-L136)
    - `HeapType`, `RefType`, `TypeIdx`, `TypeMetadata`, `SubType`, `RecType`, and `DefType` encode the heap-type graph and rec-group surface
- WAT rec-group parser/lowering surfaces a future port can reuse for fixtures
  - [`src/wast/parser.mbt#L3479-L3481`](../../../../../src/wast/parser.mbt#L3479-L3481)
    - WAT `(rec ...)` fields are parsed as `ModuleField::RecField(...)`
  - [`src/wast/lower_to_lib.mbt#L376-L428`](../../../../../src/wast/lower_to_lib.mbt#L376-L428)
    - plain type definitions and rec groups lower to `RecType::new(...)` / `RecType::group(...)`
  - [`src/wast/module_wast_tests.mbt#L377-L405`](../../../../../src/wast/module_wast_tests.mbt#L377-L405)
    - rec-group roundtrip expectations already exist
- exact-reference and descriptor validation surfaces a future port must preserve
  - [`src/wast/ref_null_exact_surface_test.mbt#L1-L88`](../../../../../src/wast/ref_null_exact_surface_test.mbt#L1-L88)
    - exact heap-type immediates and descriptor flows have dedicated roundtrip/validation fixtures
  - [`src/validate/env.mbt#L134-L154`](../../../../../src/validate/env.mbt#L134-L154)
    - validation resolves `TypeIdx` / `HeapType` references through the module type environment
  - [`src/validate/env.mbt#L395-L443`](../../../../../src/validate/env.mbt#L395-L443)
    - descriptor-target and descriptor-result helpers already encode part of the GC descriptor invariant surface
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `type-merging` in the active default route
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `type-merging` slice

That map is the durable local status today: the pass is known, intentionally unavailable, boundary-only, not in the open-world path, not assigned to an active implementation slice, and not backed by an owner file.

## Why this is not a HOT peephole

Binaryen's `type-merging` changes the module's type graph and every affected type use.
The transformed shapes are written as type-section / rec-group declarations plus repaired instruction types, not as isolated expression peepholes inside one function.
A faithful Starshine port would need to reason over:

- the module's full heap-type inventory
- public versus private heap-type visibility
- GC and closed-world gates
- cast-like observability in all function bodies and module-scope expressions
- exact cast targets as a stricter barrier than ordinary casts
- supertype-first target ordering
- top-level type-shape grouping
- child heap-type transitions between groups
- descriptor/described chains
- partition refinement until heap-type equivalence stabilizes
- whole-module type-use rewriting
- validation or refinalization after the rewrite

Those requirements cross package boundaries that current HOT expression passes do not own.
The right future landing shape is a module pass or a shared closed-world type-graph rewrite engine, not a small `HotFunc` rewrite.

## What Starshine currently does for the pass name

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `type-merging` in `pass_registry_boundary_only_names()`.
That means:

- the spelling remains discoverable in local registry behavior
- neighboring type-section docs can point at one consistent local status
- future port work has to intentionally move the pass into an implemented category

### 2. The active pipeline rejects it honestly

When a user requests a boundary-only pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a boundary-only error.
That behavior matters because:

- explicit pass requests do not silently pretend to merge heap types
- the registry category remains executable documentation
- future implementation work will have to change the category and diagnostics intentionally

### 3. The active presets exclude it

The Starshine `optimize` and `shrink` presets expand only implemented module/HOT passes today.
The registry test asserts that preset expansions stay on active pass names.
That matches the current local strategy: `type-merging` has no open-world no-DWARF preset role in this repo today.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- require GC support and closed-world mode before rewriting
- collect all private heap types as candidate sources
- treat public types and casts as observability boundaries
- scan `ref.cast`, exact casts, `ref.test`, `br_on_cast` / `br_on_cast_fail`, and `call_indirect` heap-type targets
- merge private types into safe supertypes before attempting sibling merges
- keep descriptor chains together rather than merging described and descriptor types independently
- group candidates by top-level type kind and shape
- refine partitions using child heap-type references as transitions
- split partitions when any successor transition distinguishes members
- pick deterministic merge targets through supertype-first ordering
- rewrite every affected type use through an old-to-new map
- refinalize or otherwise validate after rewrites that can sharpen expression result types

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./dfa-partitions-casts-and-refinalization.md`](./dfa-partitions-casts-and-refinalization.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Nearby boundaries to keep distinct

### `remove-unused-types`

See [`../remove-unused-types/index.md`](../remove-unused-types/index.md).

`remove-unused-types` deletes unused private heap types and copies retained private rec groups around public groups.
`type-merging` works on private heap types that are still used but no longer observably distinct.
Do not teach `type-merging` as dead-type cleanup.

### `type-refining`

See [`../type-refining/index.md`](../type-refining/index.md).

`type-refining` tries to make declarations more precise so earlier optimization can use the richer graph.
`type-merging` intentionally runs late enough to remove distinctions that no longer buy optimization wins.
Do not teach `type-merging` as inference or declaration sharpening.

### `type-ssa`

See [`../type-ssa/index.md`](../type-ssa/index.md).

`type-ssa` propagates exact heap-type knowledge through values.
`type-merging` can be useful after that kind of precision has already served its purpose.
Do not teach `type-merging` as SSA construction.

### `minimize-rec-groups`

See [`../minimize-rec-groups/index.md`](../minimize-rec-groups/index.md).

`minimize-rec-groups` repartitions private recursion groups while preserving identity through permutations or brands.
`type-merging` collapses private heap-type identities when they are no longer observable.
These passes have opposite identity-accounting pressures and should not share a simplistic type-dedup implementation.

### `unsubtyping`

See [`../unsubtyping/index.md`](../unsubtyping/index.md).

`unsubtyping` prunes declared subtype and descriptor relations after proving them unobservable.
`type-merging` may remove entire private heap-type identities by mapping them to another live type.
Both are closed-world type-graph passes, but they change different graph facts.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep boundary-only rejection until the transform exists
   - when the pass lands, update registry category, preset behavior if any, tests, tracker, and docs in the same change
2. feature and world gates
   - no-GC modules are unchanged
   - open-world mode is unchanged or rejected, matching the chosen Starshine API shape
   - closed-world test fixtures enable the rewrite explicitly
3. private/public boundaries
   - private duplicates merge
   - exported/public heap types stay distinct when observable
   - public successors and public parents preserve the known precision limits from Binaryen's lit file
4. cast and exactness blockers
   - `ref.cast`, exact casts, `ref.test`, `br_on_cast*`, and `call_indirect` prevent unsafe merges
   - traps-never-happen interactions should only be copied after source-backed review
5. graph-equivalence positives
   - direct subtype adds nothing new
   - multilevel chains collapse
   - child convergence unlocks parent merges
   - recursive and mutually recursive families merge when equivalent
   - arrays and function heap types get direct coverage, not only structs
6. descriptor-chain coverage
   - described and descriptor types merge as linked pairs where legal
   - descriptor mismatches block merges
7. rewrite and repair coverage
   - all type uses update consistently
   - exact result/LUB-sensitive expression types remain valid after the rewrite
   - module validation passes after the transform
8. parity coverage
   - compare targeted fixtures against Binaryen `wasm-opt --type-merging` first
   - only then include the pass in combined closed-world shrink clusters

## Current uncertainty and recommendation

The main local uncertainty is where the shared type-graph rewrite infrastructure should live.
A one-off `type-merging` implementation would duplicate machinery that nearby passes also need:

- [`remove-unused-types`](../remove-unused-types/index.md) needs public/private heap-type reachability and module-wide type-section rewriting.
- [`type-refining`](../type-refining/index.md) needs closed-world field/signature type repair.
- [`minimize-rec-groups`](../minimize-rec-groups/index.md) needs rec-group graph ordering and module-wide type remapping.
- [`unsubtyping`](../unsubtyping/index.md) needs descriptor/subtype graph proof and allocation repair.

Until a backlog slice decides that architecture, keep `type-merging` documented as boundary-only and unimplemented.
