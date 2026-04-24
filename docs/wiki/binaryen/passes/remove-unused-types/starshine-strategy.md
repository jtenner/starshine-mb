---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md
  - ../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../remove-unused-module-elements/index.md
  - ../type-merging/index.md
  - ../minimize-rec-groups/index.md
  - ../unsubtyping/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-visibility-and-rec-group-rewrite.md
  - ./wat-shapes.md
  - ../remove-unused-module-elements/index.md
  - ../type-merging/index.md
  - ../minimize-rec-groups/index.md
  - ../unsubtyping/index.md
---

# Starshine Strategy For `remove-unused-types`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main infrastructure gaps a future parity port must resolve.

## The honest current status

`remove-unused-types` is still **unimplemented** in Starshine.
There is no `src/passes/remove_unused_types.mbt`, `src/passes/remove-unused-types.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `remove-unused-types` in the registry as a known boundary-only name,
- reject active requests honestly instead of silently no-oping,
- keep the upstream closed-world GC/type-graph contract visible in the wiki,
- keep its absence from the canonical open-world no-DWARF path explicit,
- keep the missing dedicated backlog slice explicit,
- document why a future port is type-section/module-owned work, not a HOT peephole.

So this is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
    - `pass_registry_boundary_only_names()` includes `"remove-unused-types"`.
- registry entry construction for boundary-only names
  - [`src/passes/optimize.mbt#L266-L268`](../../../../../src/passes/optimize.mbt#L266-L268)
    - each boundary-only name becomes a boundary-only registry entry through `pass_registry_entry_boundary_only(...)`.
- active request guard for boundary-only passes
  - [`src/passes/optimize.mbt#L453-L462`](../../../../../src/passes/optimize.mbt#L453-L462)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
- active preset absence
  - [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
    - the built-in `optimize` and `shrink` presets expand only the currently implemented module/HOT sequence and do not include `remove-unused-types`.
  - [`src/passes/registry_test.mbt#L121-L158`](../../../../../src/passes/registry_test.mbt#L121-L158)
    - the preset test asserts every expanded preset name is `HotPass` or `ModulePass`, which keeps boundary-only names out of the active default path.
- type-section representation a future port would have to rewrite
  - [`src/lib/types.mbt#L48-L136`](../../../../../src/lib/types.mbt#L48-L136)
    - `HeapType`, `RefType`, `TypeIdx`, `TypeMetadata`, `SubType`, `RecType`, and `DefType` encode the heap-type graph and rec-group surface.
- WAT rec-group parser/lowering surfaces a future port can reuse for fixtures
  - [`src/wast/parser.mbt#L3479-L3481`](../../../../../src/wast/parser.mbt#L3479-L3481)
    - WAT `(rec ...)` fields are parsed as `ModuleField::RecField(...)`.
  - [`src/wast/lower_to_lib.mbt#L376-L428`](../../../../../src/wast/lower_to_lib.mbt#L376-L428)
    - plain type definitions and rec groups lower to `RecType::new(...)` / `RecType::group(...)`.
  - [`src/wast/module_wast_tests.mbt#L377-L405`](../../../../../src/wast/module_wast_tests.mbt#L377-L405)
    - rec-group roundtrip expectations already exist.
- validator environment surfaces a future port must preserve
  - [`src/validate/env.mbt#L134-L171`](../../../../../src/validate/env.mbt#L134-L171)
    - validation resolves `TypeIdx` / `HeapType` references through the module type environment.
  - [`src/validate/env.mbt#L194-L217`](../../../../../src/validate/env.mbt#L194-L217)
    - `with_rectype(...)` and `append_rectype_types(...)` encode how rec groups populate validation type environments.
  - [`src/validate/env.mbt#L395-L443`](../../../../../src/validate/env.mbt#L395-L443)
    - descriptor-target and descriptor-result helpers encode part of the GC descriptor invariant surface.
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `remove-unused-types` in the active open-world route.
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `remove-unused-types` slice.

That map is the durable local status today: the pass is known, intentionally unavailable, boundary-only, not in the open-world path, not assigned to an active implementation slice, and not backed by an owner file.

## Why this is not a HOT peephole

Binaryen's corrected `remove-unused-types` strategy changes the module's type graph and every affected type use.
The transformed shapes are type-section / rec-group declarations plus repaired references, not isolated expression rewrites inside one function.

A faithful Starshine port would need to reason over:

- the module's full heap-type inventory,
- public versus private heap-type visibility,
- GC and closed-world gates,
- used heap-type discovery across declarations and function bodies,
- private supertype and descriptor/described dependency edges,
- fresh private type-group construction,
- old-to-new heap-type mapping,
- function/local/global/table/tag/element type rewrites,
- expression result and immediate type rewrites,
- validation after every remapped type use is updated.

Those requirements cross package boundaries that current HOT expression passes do not own.
The right future landing shape is a module pass plus shared closed-world type-graph rewrite infrastructure, not a small `HotFunc` rewrite.

## What Starshine currently does for the pass name

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `remove-unused-types` in `pass_registry_boundary_only_names()`.
That means:

- the spelling remains discoverable in local registry behavior,
- neighboring type-section docs can point at one consistent local status,
- future port work has to intentionally move the pass into an implemented category.

### 2. The active pipeline rejects it honestly

When a user requests a boundary-only pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a boundary-only error.
That behavior matters because:

- explicit pass requests do not silently pretend to rewrite heap types,
- the registry category remains executable documentation,
- future implementation work will have to change the category and diagnostics intentionally.

### 3. The active presets exclude it

The Starshine `optimize` and `shrink` presets expand only implemented module/HOT passes today.
The registry test asserts that preset expansions stay on active pass names.
That matches the current local strategy: `remove-unused-types` has no open-world no-DWARF preset role in this repo today.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- require GC support and closed-world mode before rewriting,
- keep open-world behavior explicit and non-silent,
- collect public type groups as boundary anchors,
- collect used private heap types across declarations and code,
- avoid preserving whole old private rec groups merely because one member is live,
- preserve real private dependencies through supertype and descriptor/described edges,
- rebuild surviving private heap types deterministically,
- keep public groups stable while threading private survivors around them,
- rewrite every affected module type use through an old-to-new map,
- validate after the rewrite.

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./closed-world-visibility-and-rec-group-rewrite.md`](./closed-world-visibility-and-rec-group-rewrite.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Nearby boundaries to keep distinct

### `remove-unused-module-elements`

See [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md).

`remove-unused-module-elements` removes dead module declarations and can indirectly make more heap types unused.
`remove-unused-types` runs in the type graph after that kind of cleanup and rewrites heap-type identities.
Do not teach `remove-unused-types` as a second RUME.

### `type-merging`

See [`../type-merging/index.md`](../type-merging/index.md).

`type-merging` collapses still-used private heap-type identities when they are no longer observably distinct.
`remove-unused-types` deletes private heap types that are not used at all.
Do not teach `type-merging` as dead-type cleanup or `remove-unused-types` as equivalence merging.

### `minimize-rec-groups`

See [`../minimize-rec-groups/index.md`](../minimize-rec-groups/index.md).

`minimize-rec-groups` repartitions private recursion groups while preserving identity through permutations or brands.
`remove-unused-types` drops unused private heap types and rebuilds the surviving private graph around public anchors.
Both touch grouping, but with different goals and correctness pressures.

### `unsubtyping`

See [`../unsubtyping/index.md`](../unsubtyping/index.md).

`unsubtyping` prunes declared subtype and descriptor relations after proving them unobservable.
`remove-unused-types` removes dead private heap-type identities.
Both need descriptor-aware type-graph infrastructure, but they change different graph facts.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep boundary-only rejection until the transform exists,
   - when the pass lands, update registry category, tests, tracker, and docs in the same change.
2. feature and world gates
   - no-GC modules are unchanged,
   - open-world requests are rejected or not scheduled,
   - closed-world test fixtures enable the rewrite explicitly.
3. private/public boundaries
   - unused private singleton types disappear,
   - public type groups stay,
   - unused private subtype groups below public types can disappear,
   - used private subtypes below public types stay and remap correctly.
4. private dependency graph
   - private supertype dependencies are preserved,
   - descriptor/described dependencies are preserved,
   - old private group members that are not referenced can disappear.
5. rewrite and repair coverage
   - functions, locals, globals, tables, elems, tags, heap immediates, and expression types update consistently,
   - names and indices are either updated or intentionally dropped,
   - module validation passes after the transform.
6. parity coverage
   - compare targeted fixtures against Binaryen `wasm-opt --closed-world --remove-unused-types` first,
   - only then include the pass in combined closed-world shrink clusters.

## Current uncertainty and recommendation

The main local uncertainty is where shared closed-world type-graph rewrite infrastructure should live.
A one-off `remove-unused-types` implementation would duplicate machinery that nearby passes also need:

- [`type-merging`](../type-merging/index.md) needs whole-module type-use rewrites after private type identity merges.
- [`minimize-rec-groups`](../minimize-rec-groups/index.md) needs rec-group ordering and module-wide remapping.
- [`unsubtyping`](../unsubtyping/index.md) needs descriptor/subtype graph proof and allocation repair.
- [`type-refining`](../type-refining/index.md) needs closed-world declaration and instruction type repair.

Until a backlog slice decides that architecture, keep `remove-unused-types` documented as boundary-only and unimplemented.
