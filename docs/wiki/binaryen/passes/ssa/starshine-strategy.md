---
kind: concept
status: supported
last_reviewed: 2026-06-13
sources:
  - ../../../raw/binaryen/2026-04-26-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0402-2026-04-26-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-ssa-primary-sources.md
  - ../../../raw/research/0321-2026-04-24-ssa-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0207-2026-04-21-ssa-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/ssa.mbt
  - ../../../../../src/passes/ssa_test.mbt
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
  - ../../../../../src/ir/local_graph.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/ir/ssa_policy.mbt
  - ../../../../../src/ir/ssa_local.mbt
  - ../../../../../src/ir/ssa_destroy.mbt
  - ../../../../../src/ir/analysis_cache.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./merge-locals-entry-prepends-and-default-values.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../ssa-nomerge/starshine-hot-ir-strategy.md
  - ../ssa-nomerge/index.md
  - ../tracker.md
---

# Starshine status and port strategy for full `ssa`

This page describes the **current local Starshine status** for upstream Binaryen's public full `ssa` pass.

The short version:

- Starshine now records full `ssa` as an active hot-pass name for the direct non-merge families from Binaryen's `ssa.wast`: repeated parameter overwrites and default/null replacements.
- Starshine keeps full-`ssa` merge families fail-closed until `[SSA-FULL]002C` through `[SSA-FULL]002E` implement Binaryen-shaped merge-local mutation, entry prepends, and loop handling.
- Starshine has a full-`ssa` merge planner in `src/passes/ssa.mbt` that consumes LocalGraph reaching sources and records Binaryen-shaped merge-local inputs; 002B uses the planner only as a merge-family boundary, not as a merge-local mutator.
- Starshine still exposes and actively runs the sibling [`ssa-nomerge`](../ssa-nomerge/index.md); presets continue to use that sibling, not full `ssa`.

## Current local registry status

`src/passes/optimize.mbt` is the source of truth for pass names.

Current facts:

- `ssa-nomerge` is an active hot-pass registry entry.
- `ssa` is now an active hot-pass registry entry for safe non-merge families only.
- direct `--ssa` CLI requests parse as registry-owned pass flags and execute the staged full-SSA runner.
- the staged runner reuses existing non-merge rewrite machinery for functions with no LocalGraph merge reads, rewrites no-write default local reads through the raw default materializer, and returns unchanged for merge reads until merge-local materialization lands.
- the public `optimize` and `shrink` presets contain `ssa-nomerge`, not full `ssa`.

That means an explicit local `--ssa` request is no longer boundary-only, but it is still intentionally partial. This status prevents silent aliasing to `ssa-nomerge` while allowing the official non-merge lit families to execute under the public full-SSA name.

## Why Starshine still has relevant SSA code

The absence of a public `ssa` pass does not mean the repo lacks SSA machinery.

Starshine's local HOT pipeline has an SSA overlay model used by the active sibling and by other analyses:

- `src/ir/ssa_policy.mbt`
  - owns the local SSA vocabulary: value origins, phi definitions, phi inputs, use origins, rename/destruction policy names, and explicit excluded-feature labels.
- `src/ir/ssa_local.mbt`
  - builds a `HotLocalSsa` overlay using CFG, dominance, liveness, and use-def analysis.
  - seeds entry definitions for params and ordinary locals.
  - places block phis and records predecessor inputs.
- `src/ir/ssa_destroy.mbt`
  - maps SSA values back to concrete locals.
  - appends extra locals when needed.
  - rewrites local gets/sets/tees onto chosen concrete locals.
  - inserts predecessor copies for phis.
  - removes dead local definitions when safe.
- `src/passes/pass_common.mbt`
  - exposes cached SSA construction through `pass_require_ssa(...)`.
- `src/ir/analysis_cache.mbt`
  - stores `HotLocalSsa` in the per-function analysis cache.

So the local infrastructure is real and important. The missing piece is a public pass whose contract matches Binaryen full `ssa`.

For first-slice implementation order and validation, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). That page keeps registry honesty, source classification, merge-local rewriting, and sibling-stability tests together.

## Exact local code map

Use this map when following along in-tree:

- `src/passes/optimize.mbt`
  - owns pass categories, presets, and request lookup.
  - active entries start with `ssa-nomerge`; sibling `ssa` is now an active hot pass for non-merge families only and remains out of presets.
  - `optimize` and `shrink` presets both include `ssa-nomerge` in the early hot-pass slot.
- `src/passes/ssa.mbt`
  - full-`ssa` descriptor/summary and staged runner surface for `[SSA-FULL]002B`.
  - `SsaFullRewritePlan` records merge-get rewrites; each rewrite names the original get/local, the future fresh merge-local id, and input actions for explicit writes, parameter entries, and default entries.
  - nondefaultable body-default entries fail closed, so later mutation slices cannot accidentally create an impossible fresh merge local.
  - `ssa_full_run(...)` executes only when LocalGraph finds no merge reads; merge families return unchanged until merge-local materialization lands.
- `src/passes/ssa_test.mbt`
  - planner fixtures for explicit diamond writes, parameter-entry merges, default-entry merges, nondefaultable fail-closed behavior, and single-source no-merge contrast.
  - active public-pass fixtures for repeated parameter overwrite freshening, default exact-ref replacement with validation/type repair, and merge-family fail-closed behavior.
- `src/passes/ssa_nomerge.mbt`
  - descriptor for the active sibling, including broad invalidation of CFG, dominance, liveness, use-def, effects, loop info, and SSA.
  - runner requires CFG + local SSA and delegates to `@ir.ssa_destroy_into_hot(...)`.
- `src/ir/ssa_policy.mbt`
  - `HotSsaValueOrigin` distinguishes entry params, entry default inits, local-set defs, local-tee defs, and phi defs.
  - `HotSsaPhi` models local-specific block phis in the overlay.
  - `HotSsaExcludedFeature` records current v1 limits: exceptional edges, persistent HOT phi nodes, IR-owned SSA bodies, and non-local values.
- `src/ir/ssa_local.mbt`
  - `ssa_build_local(...)` seeds entry definitions, places phis, visits the dominator tree, records uses, and sorts phi inputs.
- `src/ir/ssa_destroy.mbt`
  - `ssa_assign_concrete_locals(...)` chooses existing or fresh locals for SSA values.
  - `ssa_insert_predecessor_copies(...)` inserts explicit predecessor copies.
  - `ssa_destroy_into_hot(...)` performs the local SSA destruction used by `ssa-nomerge`.
- `src/passes/pass_common.mbt`
  - `pass_require_ssa(...)` builds/caches the local SSA analysis for hot passes.
- `src/passes/ssa_nomerge_test.mbt`
  - branch-join coverage for the active local sibling's predecessor-copy style.
- `src/passes/registry_test.mbt`
  - registry test coverage for the active `ssa-nomerge` descriptor and the active partial full `ssa` sibling.
- `src/cmd/cmd.mbt` / `src/cmd/cmd_wbtest.mbt`
  - CLI pass-flag parsing admits `ssa` as a registry-owned active pass flag so direct `--ssa` can rewrite non-merge fixtures and produce a validated output.
- `agent-todo.md`
  - `[O4Z-AUDIT-SSA]` tracks both active `ssa-nomerge` parity slices and separate full-`ssa` sibling slices; `[SSA-FULL]001` was the boundary-only registry decision, `[SSA-FULL]002A` was the merge planner, `[SSA-FULL]002B` activates direct non-merge rewrites, and `[SSA-FULL]002C` through `[SSA-FULL]002E` still own merge-local materialization, entry-source handling, loops, and closeout signoff.

## Current behavior versus Binaryen full `ssa`

| Topic | Binaryen full `ssa` | Current Starshine |
| --- | --- | --- |
| Public pass name | `ssa` registered in Binaryen `pass.cpp` | active partial `ssa` hot-pass entry for non-merge families |
| Default no-DWARF sibling | Binaryen's canonical path here uses `ssa-nomerge`, not full `ssa` | Starshine presets also use `ssa-nomerge` |
| Merge handling | create a merge local for a multi-source get | planner records future merge locals for multi-source gets; active `ssa` returns unchanged on merge gets until later slices |
| Explicit incoming sets | rewrite values through `local.tee mergeLocal` | planner records explicit-write inputs; no `local.tee` mutation yet |
| Parameter-entry merge input | function-entry prepend into merge local | planner records parameter-entry inputs for later prepends; no public prepend mutation yet |
| Default-entry merge input | rely on fresh merge local's default | planner records defaultable body-entry inputs and skips nondefaultable body entries; no public merge-local mutation yet |
| Implementation owner | Binaryen `SSAify.cpp` plus `LocalGraph` | Starshine `ssa_nomerge.mbt`, `ssa_local.mbt`, and `ssa_destroy.mbt` for the sibling/infrastructure |

The main caution is that both systems use words like SSA, phi, entry, and predecessor, but the encoded rewrite shapes differ.

## What a faithful Starshine full-`ssa` port would need

A faithful local port should not be introduced as a tiny alias for `ssa-nomerge`.

It would need to decide whether to reproduce Binaryen's exact surface or expose a Starshine-specific sibling. For Binaryen parity, the important requirements are:

1. Keep the known active registry name for `ssa` in `src/passes/optimize.mbt` honest about its partial scope.
2. Keep it out of public presets unless a Binaryen parity path really needs it; current presets should remain on `ssa-nomerge`.
3. Build or reuse an analysis that can answer Binaryen's LocalGraph-style question for each `local.get`: which sets and entry values reach it? The first no-mutation planner slice now does this for merge gets through LocalGraph.
4. For multi-source gets, materialize a fresh merge local rather than only destroying existing overlay phis.
5. Rewrite explicit incoming set values through `local.tee` into that merge local.
6. Add function-entry prepends only for parameter-entry incoming sources.
7. Preserve the ordinary defaultable-local no-prepend rule.
8. Preserve the narrow typed repair story for default ref/null replacement.
9. Add dedicated tests that separate direct Binaryen-lit families from source-derived merge-local families.

## Validation plan for a future port

Minimum local test coverage should include:

- direct repeated-param overwrite splitting,
- default reference replacement that requires validation after rewriting,
- tuple default replacement,
- two explicit branch writes feeding one merge local,
- one-arm parameter overwrite requiring an entry prepend,
- one-arm ordinary local overwrite with no default prepend,
- nondefaultable entry cases left untouched when no default is sound,
- sibling contrast tests proving `ssa-nomerge` still keeps its local contract.

For parity signoff, compare explicit `--pass ssa` output against Binaryen on targeted WAT fixtures first. Do not infer full-`ssa` parity from the current `ssa-nomerge` green tests.

## Current non-goals

Do not claim any of these today:

- Starshine implements all of upstream Binaryen full `ssa`.
- `ssa` handles merge-local materialization, parameter-entry prepends, or loop merge closeout.
- the local `ssa-nomerge` predecessor-copy output is Binaryen full `ssa`'s merge-local + incoming-tee output.
- the default `optimize` / `shrink` presets are missing full `ssa`.

## Bottom line

The Starshine codebase has useful SSA infrastructure, but the pass surface remains sibling-specific:

- `ssa-nomerge` is active and documented as a local HOT-SSA roundtrip/destruction strategy.
- full `ssa` is active only for direct non-merge lit-compatible families today.
- the current full-`ssa` merge code is still planner/fail-closed only.
- future full-`ssa` slices must consciously bridge from Starshine's overlay/predecessor-copy model and the newer LocalGraph merge/source facts to Binaryen's merge-local/`local.tee`/entry-prepend contract.
