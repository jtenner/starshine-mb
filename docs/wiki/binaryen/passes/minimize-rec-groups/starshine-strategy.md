---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md
  - ../../../raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../src/wast/rec_group_typeuse_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../remove-unused-types/index.md
  - ../reorder-types/index.md
  - ../type-merging/index.md
  - ../unsubtyping/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./permutations-brands-and-public-conflicts.md
  - ./wat-shapes.md
  - ../remove-unused-types/index.md
  - ../reorder-types/index.md
  - ../type-merging/index.md
  - ../unsubtyping/index.md
---

# Starshine Strategy For `minimize-rec-groups`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md`](../../../raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main infrastructure gaps a future parity port must resolve.

## The honest current status

`minimize-rec-groups` is still **unimplemented** in Starshine.
There is no `src/passes/minimize_rec_groups.mbt`, `src/passes/minimize-rec-groups.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `minimize-rec-groups` in the registry as a known boundary-only name
- reject active requests honestly instead of silently no-oping
- keep the upstream explicit-pass, non-default-preset scheduler status visible in the wiki
- keep its absence from the canonical open-world no-DWARF path explicit
- keep the missing dedicated backlog slice explicit
- document why a future port is type-section/module-owned work, not a HOT peephole

So this is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
    - `pass_registry_boundary_only_names()` includes `"minimize-rec-groups"`
- registry entry construction for boundary-only names
  - [`src/passes/optimize.mbt#L266-L268`](../../../../../src/passes/optimize.mbt#L266-L268)
    - each boundary-only name becomes a boundary-only registry entry through `pass_registry_entry_boundary_only(...)`
- active request guard for boundary-only passes
  - [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- active preset absence
  - [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
    - the built-in `optimize` and `shrink` presets expand only the currently implemented module/HOT sequence and do not include `minimize-rec-groups`
  - [`src/passes/registry_test.mbt#L129-L158`](../../../../../src/passes/registry_test.mbt#L129-L158)
    - the preset test asserts every expanded preset name is `HotPass` or `ModulePass`, which keeps boundary-only names out of the active default path
- type-section representation a future port would have to rebuild
  - [`src/lib/types.mbt#L41-L136`](../../../../../src/lib/types.mbt#L41-L136)
    - `HeapType`, `RefType`, `TypeIdx`, `TypeMetadata`, `SubType`, and `RecType` encode the graph and group surface
- WAT rec-group parser/lowering surfaces a future port can reuse for fixtures
  - [`src/wast/parser.mbt#L3479-L3481`](../../../../../src/wast/parser.mbt#L3479-L3481)
    - WAT `(rec ...)` fields are parsed as `ModuleField::RecField(...)`
  - [`src/wast/lower_to_lib.mbt#L376-L428`](../../../../../src/wast/lower_to_lib.mbt#L376-L428)
    - plain type definitions and rec groups lower to `RecType::new(...)` / `RecType::group(...)`
  - [`src/wast/module_wast_tests.mbt#L401-L405`](../../../../../src/wast/module_wast_tests.mbt#L401-L405)
    - rec-group roundtrip expectations already exist
  - [`src/wast/rec_group_typeuse_test.mbt`](../../../../../src/wast/rec_group_typeuse_test.mbt)
    - rec-group type-use fixtures already exist for parser/lowering coverage
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `minimize-rec-groups` in the active default route
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `minimize-rec-groups` slice

That map is the durable local status today: the pass is known, intentionally unavailable, boundary-only, not in the open-world path, not assigned to an active implementation slice, and not backed by an owner file.

## Why this is not a HOT peephole

Binaryen's `minimize-rec-groups` changes the module's type section and every affected type use. The shared Starshine type-section and type-index carrier checklist lives in [`../../../binary/type-table-memory-global-tag-sections.md`](../../../binary/type-table-memory-global-tag-sections.md).
The transformed shapes are written as WAT type declarations, not expression trees inside a single function.
A faithful Starshine port would need to reason over:

- the module's full heap-type inventory
- public versus private rec-group visibility
- SCCs in the private type graph
- supertype-before-subtype ordering constraints
- described-before-descriptor ordering constraints
- feature-sensitive written type shapes
- public-group shape collisions
- private/private collision classes
- valid permutation enumeration
- deterministic synthetic brand construction
- whole-module type-use, type-name, and type-index rewriting
- validation or refinalization after type graph changes

Those requirements cross package boundaries that current HOT expression passes do not own.
The right future landing shape is a module pass or a shared type-graph rewrite engine, not a small `HotFunc` rewrite.

## What Starshine currently does for the pass name

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `minimize-rec-groups` in `pass_registry_boundary_only_names()`.
That means:

- the spelling remains discoverable in local registry behavior
- neighboring type-section docs can point at one consistent local status
- future port work has to intentionally move the pass into an implemented category

### 2. The active pipeline rejects it honestly

When a user requests a boundary-only pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a boundary-only error.
That behavior matters because:

- explicit pass requests do not silently pretend to repartition recursion groups
- the registry category remains executable documentation
- future implementation work will have to change the category and diagnostics intentionally

### 3. The active presets exclude it

The Starshine `optimize` and `shrink` presets expand only implemented module/HOT passes today.
The registry test asserts that preset expansions stay on active pass names.
That matches the reviewed Binaryen story for this pass: `version_129` registers `minimize-rec-groups`, but the reviewed default optimize-preset surface does not insert it automatically.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- require GC/type-section support before rewriting
- collect all heap types and classify public versus private groups
- rewrite only private groups
- record public group shapes as immutable collision targets
- compute private-type SCCs without public edges merging private SCCs
- build valid intra-SCC order graphs for subtype and descriptor constraints
- compare rec-group shapes as written under the active feature set
- detect private/private and private/public shape collisions
- lazily form equivalence classes for colliding isomorphic groups
- use valid permutations before brands when permutations produce distinct written shapes
- synthesize compact deterministic brand types when permutations are impossible or exhausted
- rebuild new rec groups and maintain old-to-new type maps
- update type uses, type names, and type indices across the module
- validate or refinalize after rewrite

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./permutations-brands-and-public-conflicts.md`](./permutations-brands-and-public-conflicts.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Nearby boundaries to keep distinct

### `remove-unused-types`

See [`../remove-unused-types/index.md`](../remove-unused-types/index.md).

`remove-unused-types` deletes unused private heap types and copies retained private rec groups around public groups.
`minimize-rec-groups` keeps live private types but may repartition them into smaller SCC-based groups and add brands to preserve identity.
Do not teach `minimize-rec-groups` as dead-type cleanup.

### `reorder-types`

See [`../reorder-types/index.md`](../reorder-types/index.md).

`reorder-types` chooses a cheaper private-type index layout and rebuilds a large private rec group.
`minimize-rec-groups` changes the rec-group partitioning itself.
Do not teach `reorder-types` as a substitute for SCC minimization or branding.

### `type-merging`

See [`../type-merging/index.md`](../type-merging/index.md).

`type-merging` merges behaviorally indistinguishable private heap types using a closed-world cast-aware partition-refinement model.
`minimize-rec-groups` must do the opposite kind of accounting in its conflict half: it prevents distinct old types from becoming accidentally indistinguishable after SCC splitting.

### `unsubtyping`

See [`../unsubtyping/index.md`](../unsubtyping/index.md).

`unsubtyping` prunes declared subtype and descriptor relations after proving them unobservable.
`minimize-rec-groups` respects subtype and descriptor order constraints while repartitioning private rec groups; it does not decide which relations are semantically unnecessary.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep boundary-only rejection until the transform exists
   - when the pass lands, update registry category, preset behavior if any, tests, tracker, and docs in the same change
2. feature and visibility gates
   - no-GC modules are unchanged
   - public groups stay unchanged
   - private groups can split or brand without colliding with public shapes
3. SCC and order fixtures
   - independent members split
   - acyclic chains split into valid order
   - true cycles stay grouped
   - subtype and descriptor constraints force legal emitted order
4. identity-preservation fixtures
   - same-shape singleton groups brand
   - same-shape multi-type SCCs use valid permutations when possible
   - automorphism-heavy or order-constrained groups brand when needed
   - many duplicate groups advance deterministic brands
5. feature-sensitive shape fixtures
   - exact and inexact refs remain distinct when written features preserve exactness
   - exactness erasure causes collisions and brands when features erase the written distinction
6. rewrite fixtures
   - function, global, table, element, tag, and expression type uses map to new types
   - type names and recorded indices stay coherent
   - final validation/typechecking passes after the rewrite

## Bottom line

Current Starshine `minimize-rec-groups` strategy is honest boundary-only tracking plus an explicit future-proofing map:

- the pass name is preserved at [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
- active requests are rejected at [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462)
- active presets exclude the pass at [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
- preset tests keep default expansion on implemented pass categories at [`src/passes/registry_test.mbt#L129-L158`](../../../../../src/passes/registry_test.mbt#L129-L158)
- reusable rec-group representation exists in [`src/lib/types.mbt#L41-L136`](../../../../../src/lib/types.mbt#L41-L136), but there is no local owner file yet
- the active backlog still has no dedicated slice

So the right mental model today is:

- **no transform yet**
- **clear boundary-only registry behavior**
- **source-backed Binaryen `minimize-rec-groups` contract**
- **future module/type-section infrastructure still required**
- **no open-world no-DWARF parity obligation today**
