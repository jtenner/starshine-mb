---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-type-merging-primary-sources.md
  - ../../binaryen/passes/type-merging/index.md
  - ../../binaryen/passes/type-merging/binaryen-strategy.md
  - ../../binaryen/passes/type-merging/implementation-structure-and-tests.md
  - ../../binaryen/passes/type-merging/dfa-partitions-casts-and-refinalization.md
  - ../../binaryen/passes/type-merging/wat-shapes.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast_tests.mbt
  - ../../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../../src/validate/env.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/type-merging/starshine-strategy.md
  - ../../binaryen/passes/remove-unused-types/index.md
  - ../../binaryen/passes/type-refining/index.md
  - ../../binaryen/passes/type-ssa/index.md
  - ../../binaryen/passes/minimize-rec-groups/index.md
  - ../../binaryen/passes/unsubtyping/index.md
---

# `type-merging` primary-source and Starshine follow-up

## Question

The existing `type-merging` folder already taught Binaryen's algorithm, implementation structure, focused DFA/cast/refinalization rules, and WAT-shape families, but it still lacked two things required by the current pass-wiki quality bar:

1. an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. a dedicated Starshine strategy page that maps the upstream strategy to exact in-repo local status and future landing surfaces.

## Work performed

- Re-read the existing `type-merging` living folder, the pass tracker, the pass-folder map, the top-level wiki index and log, the local pass registry, type-section/WAT/validation surfaces, and the active backlog.
- Captured the reviewed primary online sources in `docs/wiki/raw/binaryen/2026-04-24-type-merging-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/type-merging/starshine-strategy.md`.
- Refreshed the existing `type-merging` pages so the folder now points at the raw manifest and local strategy page instead of remaining an upstream-only dossier.

## Primary-source findings

The new raw manifest records the official Binaryen sources reviewed in this run:

- `version_129` release page and releases index
- `src/passes/TypeMerging.cpp`
- `src/passes/pass.cpp`
- `src/wasm-type-ordering.h`
- `src/support/dfa_minimization.h`
- `src/ir/module-utils.h`
- `src/ir/type-updating.h`
- `test/lit/passes/type-merging.wast`

Durable source-backed conclusions stayed stable:

- `type-merging` is a public Binaryen pass with a tiny public summary but a much richer owner-file contract.
- It is hard-gated on GC and `--closed-world` in reviewed `version_129`.
- It rewrites private heap types that are still live, not dead declarations.
- Cast-like observability is central: `ref.cast`, exact casts, `ref.test`, `br_on_cast*`, and `call_indirect` targets can distinguish heap types and block merges.
- The pass first attempts supertype merges, then sibling merges, both through a partition-refinement model rather than shallow syntax matching.
- Descriptor chains are not independent; the merge target must preserve the linked described/descriptor relationship.
- The dedicated lit file covers positive merges, recursive/child-convergence cases, public and cast blockers, descriptor behavior, and known precision limits.
- `ReFinalize` is part of the correctness story because heap-type merges can sharpen exact/LUB-sensitive expression types.
- A narrow 2026-04-24 current-`main` spot check did not expose teaching-relevant drift from the reviewed `version_129` contract.

## Starshine findings

The local code map is intentionally status-oriented because there is no implementation file yet.

Current Starshine facts:

- `src/passes/optimize.mbt` keeps `type-merging` in `pass_registry_boundary_only_names()`.
- Registry construction converts boundary-only names into `HotPassRegistryCategory::BoundaryOnly` entries.
- The active pipeline rejects requested boundary-only names with `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
- The active preset tests prove that current `optimize` and `shrink` expansions contain only implemented active pass names; `type-merging` is absent.
- `agent-todo.md` still has no dedicated `type-merging` slice.
- `src/lib/types.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/module_wast_tests.mbt`, `src/wast/ref_null_exact_surface_test.mbt`, and `src/validate/env.mbt` provide reusable type-section, rec-group, exact-reference, descriptor, and validation surfaces, but they are not a pass implementation.

## Main uncertainty

The unresolved local question is not the upstream algorithm. The unresolved question is whether Starshine should implement `type-merging` as a standalone closed-world module pass, a shared type-graph rewrite engine used by neighboring GC/type passes, or a late cleanup once `remove-unused-types`, `type-refining`, `type-ssa`, `minimize-rec-groups`, and `unsubtyping` infrastructure exists.

A faithful port would need all of these local capabilities:

- whole-module heap-type inventory and public/private visibility classification
- GC plus closed-world gating
- cast/exact-cast/`ref.test`/`br_on_cast*`/`call_indirect` observability scanning
- descriptor-chain-aware candidate pairing
- supertype-first heap-type ordering
- top-level type-shape grouping
- DFA-style partition refinement over child heap-type references
- separate supertype and sibling merge phases
- whole-module type-use rewrite with old-to-new mapping
- refinalization or validation after the rewrite

Until those exist, the Starshine wiki should keep `type-merging` framed as a boundary-only closed-world type-graph module pass, not as a hidden partial implementation.

## Pages changed by this follow-up

- `docs/wiki/raw/binaryen/2026-04-24-type-merging-primary-sources.md`
- `docs/wiki/raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/type-merging/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-merging/index.md`
- `docs/wiki/binaryen/passes/type-merging/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-merging/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-merging/dfa-partitions-casts-and-refinalization.md`
- `docs/wiki/binaryen/passes/type-merging/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Follow-up recommendations

- Add a dedicated backlog slice before implementing `type-merging`; the current boundary-only registry entry is not enough to define the scope.
- Do not implement only a structural deduplicator. Binaryen parity requires cast-aware graph equivalence, descriptor-chain accounting, and post-merge refinalization.
- Treat `type-merging` as type-section/module-owned work rather than HOT expression rewriting.
- If Starshine later adds shared type-graph rewrite infrastructure, re-review whether `type-merging` should share that machinery with `remove-unused-types`, `type-refining`, `minimize-rec-groups`, and `unsubtyping`.
