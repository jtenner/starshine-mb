---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-minimize-rec-groups-primary-sources.md
  - ../../binaryen/passes/minimize-rec-groups/index.md
  - ../../binaryen/passes/minimize-rec-groups/binaryen-strategy.md
  - ../../binaryen/passes/minimize-rec-groups/implementation-structure-and-tests.md
  - ../../binaryen/passes/minimize-rec-groups/permutations-brands-and-public-conflicts.md
  - ../../binaryen/passes/minimize-rec-groups/wat-shapes.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast_tests.mbt
  - ../../../../src/wast/rec_group_typeuse_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/minimize-rec-groups/starshine-strategy.md
  - ../../binaryen/passes/reorder-types/index.md
  - ../../binaryen/passes/remove-unused-types/index.md
  - ../../binaryen/passes/type-merging/index.md
  - ../../binaryen/passes/unsubtyping/index.md
---

# `minimize-rec-groups` primary-source and Starshine follow-up

## Question

The existing `minimize-rec-groups` folder already taught Binaryen's algorithm, implementation structure, focused permutation/brand rules, and WAT-shape families, but it still lacked two things required by the current pass-wiki quality bar:

1. an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. a dedicated Starshine strategy page that maps the upstream strategy to exact in-repo local status and future landing surfaces.

## Work performed

- Re-read the existing `minimize-rec-groups` living folder, the pass tracker, the pass-folder map, the top-level wiki index and log, the local pass registry, rec-group WAT/type surfaces, and the active backlog.
- Captured the reviewed primary online sources in `docs/wiki/raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/minimize-rec-groups/starshine-strategy.md`.
- Refreshed the existing `minimize-rec-groups` pages so the folder now points at the raw manifest and local strategy page instead of remaining an upstream-only dossier.

## Primary-source findings

The new raw manifest records the official Binaryen sources reviewed in this run:

- `version_129` release page and releases index
- `src/passes/MinimizeRecGroups.cpp`
- `src/passes/pass.cpp`
- `src/ir/module-utils.h`
- `src/ir/type-updating.{h,cpp}`
- `src/support/strongly_connected_components.h`
- `src/support/topological_sort.h`
- `src/support/disjoint_sets.h`
- `src/wasm-type-shape.h`
- `src/wasm/wasm-type-shape.cpp`
- the dedicated `minimize-rec-groups*.wast` lit roster

Durable source-backed conclusions stayed stable:

- `minimize-rec-groups` is a GC-only explicit Binaryen module pass, not part of Starshine's current open-world no-DWARF parity path.
- It is not closed-world-gated in reviewed `version_129`; it rewrites only private types and treats public group shapes as collision targets.
- SCC splitting is only the first half of correctness. The pass must also keep output rec-group shapes distinct from other private groups and public groups.
- Valid-order repair is constrained by subtype-before-subtype and described-before-descriptor ordering rules.
- Shape comparison is feature-sensitive because Binaryen compares the written form of types under the active feature set.
- Permutation search is preferred before brands, but automorphisms, singleton groups, subtype constraints, descriptor constraints, and exhausted distinct orders can force synthetic brands.
- Brands are deterministic compact synthetic types, not an accidental artifact.
- The final rewrite must update module type uses, type names, and recorded type indices.
- A narrow 2026-04-24 current-`main` spot check did not expose teaching-relevant drift from the reviewed `version_129` contract.

## Starshine findings

The local code map is intentionally status-oriented because there is no implementation file yet.

Current Starshine facts:

- `src/passes/optimize.mbt` keeps `minimize-rec-groups` in `pass_registry_boundary_only_names()`.
- Registry construction converts boundary-only names into `HotPassRegistryCategory::BoundaryOnly` entries.
- The active pipeline rejects requested boundary-only names with `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
- The active preset tests prove that current `optimize` and `shrink` expansions contain only implemented active pass names; `minimize-rec-groups` is absent.
- `agent-todo.md` still has no dedicated `minimize-rec-groups` slice.
- `src/lib/types.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/module_wast_tests.mbt`, and `src/wast/rec_group_typeuse_test.mbt` provide reusable rec-group/type-section infrastructure, but they are not a pass implementation.

## Main uncertainty

The unresolved local question is not the upstream algorithm. The unresolved question is whether Starshine should implement `minimize-rec-groups` as a standalone module pass, a shared closed-world/type-graph engine used by neighboring type-section passes, or a later type-section cleanup once `remove-unused-types`, `reorder-types`, `type-merging`, and `unsubtyping` infrastructure exists.

A faithful port would need all of these local capabilities:

- whole-module heap-type inventory and visibility classification
- GC feature gating
- private-only type graph SCC discovery
- public rec-group shape collision tracking
- subtype and descriptor dependency ordering
- feature-sensitive rec-group shape comparison
- lazy collision-class canonicalization
- valid permutation enumeration
- compact deterministic brand synthesis
- type-section rebuild and old-to-new mapping
- module-wide type-use, type-name, and type-index rewriting
- validation or refinalization after the rewrite

Until those exist, the Starshine wiki should keep `minimize-rec-groups` framed as a boundary-only type-section module pass, not as a hidden partial implementation.

## Pages changed by this follow-up

- `docs/wiki/raw/binaryen/2026-04-24-minimize-rec-groups-primary-sources.md`
- `docs/wiki/raw/research/0290-2026-04-24-minimize-rec-groups-primary-sources-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/starshine-strategy.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/index.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/permutations-brands-and-public-conflicts.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Follow-up recommendations

- Add a dedicated backlog slice before implementing `minimize-rec-groups`; the current boundary-only registry entry is not enough to define the scope.
- Do not implement only SCC splitting. A Binaryen-parity port must also preserve identity through public-shape checks, permutation search, and brand fallback.
- Treat `minimize-rec-groups` as type-section/module-owned work rather than HOT expression rewriting.
- If Starshine later adds shared type-graph rewrite infrastructure, re-review whether `minimize-rec-groups` should share that machinery with `remove-unused-types`, `reorder-types`, `type-merging`, and `unsubtyping`.
