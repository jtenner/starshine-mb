---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0402-2026-04-26-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-ssa-primary-sources.md
  - ../../../raw/research/0321-2026-04-24-ssa-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0207-2026-04-21-ssa-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
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

- Starshine does **not** currently expose a full `ssa` pass.
- Starshine does expose and actively run the sibling [`ssa-nomerge`](../ssa-nomerge/index.md).
- Starshine also has a HOT SSA overlay/destruction infrastructure that is useful for the active sibling and for future local work, but it is not the same as Binaryen full `ssa`.

## Current local registry status

`src/passes/optimize.mbt` is the source of truth for pass names.

Current facts:

- `ssa-nomerge` is an active hot-pass registry entry.
- `ssa` is not present in the active hot-pass entries.
- `ssa` is not present in the boundary-only name list.
- `ssa` is not present in the removed-name list.
- the public `optimize` and `shrink` presets contain `ssa-nomerge`, not full `ssa`.

That means an explicit local `--ssa` request is not a known-but-disabled pass request. It falls through as an unknown pass name.

This is different from many other upstream-only pages in the wiki, where Starshine already has a boundary-only or removed registry entry.

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
  - active entries start with `ssa-nomerge`; no sibling `ssa` entry exists in active, module, boundary-only, removed, or preset lists.
  - `optimize` and `shrink` presets both include `ssa-nomerge` in the early hot-pass slot.
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
  - registry test coverage for the active `ssa-nomerge` descriptor.
- `agent-todo.md`
  - current parity notes use shorthand `SSA` for the active local `ssa-nomerge` slot, not a separate full-`ssa` implementation slice.

## Current behavior versus Binaryen full `ssa`

| Topic | Binaryen full `ssa` | Current Starshine |
| --- | --- | --- |
| Public pass name | `ssa` registered in Binaryen `pass.cpp` | no `ssa` registry entry |
| Default no-DWARF sibling | Binaryen's canonical path here uses `ssa-nomerge`, not full `ssa` | Starshine presets also use `ssa-nomerge` |
| Merge handling | create a merge local for a multi-source get | HOT SSA destruction lowers phis through predecessor copies |
| Explicit incoming sets | rewrite values through `local.tee mergeLocal` | concrete local assignment plus inserted predecessor `local.set` copies |
| Parameter-entry merge input | function-entry prepend into merge local | no full-`ssa` public prepend contract; local overlay has entry-param definitions |
| Default-entry merge input | rely on fresh merge local's default | local overlay has entry-default definitions, but no public full-`ssa` merge-local pass |
| Implementation owner | Binaryen `SSAify.cpp` plus `LocalGraph` | Starshine `ssa_nomerge.mbt`, `ssa_local.mbt`, and `ssa_destroy.mbt` for the sibling/infrastructure |

The main caution is that both systems use words like SSA, phi, entry, and predecessor, but the encoded rewrite shapes differ.

## What a faithful Starshine full-`ssa` port would need

A faithful local port should not be introduced as a tiny alias for `ssa-nomerge`.

It would need to decide whether to reproduce Binaryen's exact surface or expose a Starshine-specific sibling. For Binaryen parity, the important requirements are:

1. Add a known registry name for `ssa` in `src/passes/optimize.mbt`.
2. Keep it out of public presets unless a Binaryen parity path really needs it; current presets should remain on `ssa-nomerge`.
3. Build or reuse an analysis that can answer Binaryen's LocalGraph-style question for each `local.get`: which sets and entry values reach it?
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

- Starshine implements upstream Binaryen full `ssa`.
- `ssa` is a boundary-only name in the local registry.
- the local `ssa-nomerge` predecessor-copy output is Binaryen full `ssa`'s merge-local + incoming-tee output.
- the default `optimize` / `shrink` presets are missing full `ssa`.

## Bottom line

The Starshine codebase has useful SSA infrastructure, but the pass surface remains sibling-specific:

- `ssa-nomerge` is active and documented as a local HOT-SSA roundtrip/destruction strategy.
- full `ssa` is upstream-only knowledge in this repo today.
- any future full-`ssa` implementation must consciously bridge from Starshine's overlay/predecessor-copy model to Binaryen's merge-local/`local.tee`/entry-prepend contract.
