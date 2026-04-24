---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-abstract-type-refining-primary-sources.md
  - ../../binaryen/passes/abstract-type-refining/index.md
  - ../../binaryen/passes/abstract-type-refining/binaryen-strategy.md
  - ../../binaryen/passes/abstract-type-refining/implementation-structure-and-tests.md
  - ../../binaryen/passes/abstract-type-refining/traps-never-happen-exact-casts-and-descriptors.md
  - ../../binaryen/passes/abstract-type-refining/wat-shapes.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../../src/wast/exact_type_equivalence_test.mbt
  - ../../../../src/validate/env.mbt
  - ../../../../src/validate/match.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/abstract-type-refining/starshine-strategy.md
  - ../../binaryen/passes/global-struct-inference/index.md
  - ../../binaryen/passes/remove-unused-types/index.md
  - ../../binaryen/passes/type-refining/index.md
  - ../../binaryen/passes/unsubtyping/index.md
---

# `abstract-type-refining` primary-source and Starshine follow-up

## Question

The existing `abstract-type-refining` folder already taught Binaryen's algorithm, implementation structure, descriptor/exact-cast rules, and WAT-shape families, but it still lacked two things required by the current pass-wiki quality bar:

1. an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. a dedicated Starshine strategy page that maps the upstream strategy to exact in-repo local status and future landing surfaces.

## Work performed

- Re-read the existing `abstract-type-refining` living folder, the pass tracker, the pass-folder map, the top-level wiki index and log, the local pass registry, type-section/WAT/validation surfaces, and the active backlog.
- Captured the reviewed primary online sources in `docs/wiki/raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/abstract-type-refining/starshine-strategy.md`.
- Refreshed the existing `abstract-type-refining` pages so the folder now points at the raw manifest and local strategy page instead of remaining an upstream-only dossier.

## Primary-source findings

The new raw manifest records the official Binaryen sources reviewed in this run:

- `version_129` release page and releases index
- `src/passes/AbstractTypeRefining.cpp`
- `src/passes/pass.cpp`
- `src/ir/subtypes.h`
- `src/ir/type-updating.h` / `src/ir/type-updating.cpp`
- `src/ir/module-utils.h`
- `src/ir/localize.h`
- `src/ir/drop.h`
- `src/wasm-type.h`
- `test/lit/passes/abstract-type-refining*.wast` dedicated files

Durable source-backed conclusions stayed stable:

- `abstract-type-refining` is a public Binaryen pass with a compact public summary but a richer owner-file contract.
- It is hard-gated on GC and `--closed-world` in reviewed `version_129`.
- It is struct-only today: the creation scan watches `struct.new*`, not arrays, function types, plain references, casts, or type mentions.
- Public heap types are conservatively treated as created.
- The pass distinguishes directly created types from types that have a created subtype.
- Fully never-created struct families can bottomize even outside TNH.
- Parent-to-unique-live-child refinement is TNH-only.
- Exact casts and descriptor-sensitive operations require preoptimization so impossible checks do not become successful live-child checks and nullable descriptor traps/side effects survive.
- The pass rewrites type uses through shared type-updating machinery but deliberately preserves declared supertypes; later `unsubtyping` owns relation cleanup.
- The dedicated lit files cover ordinary TNH refinement, always-on bottomization, exact and descriptor repair, `ref.get_desc`, `struct.new_desc`, exact-bottom locals, and continuation-containing rec-group robustness.
- A narrow 2026-04-24 current-`main` spot check did not expose teaching-relevant drift from the reviewed `version_129` contract.

## Starshine findings

The local code map is intentionally status-oriented because there is no implementation file yet.

Current Starshine facts:

- `src/passes/optimize.mbt` keeps `abstract-type-refining` in `pass_registry_boundary_only_names()`.
- Registry construction converts boundary-only names into `HotPassRegistryCategory::BoundaryOnly` entries.
- The active pipeline rejects requested boundary-only names with `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
- The active preset tests prove that current `optimize` and `shrink` expansions contain only implemented active pass names; `abstract-type-refining` is absent.
- `agent-todo.md` still has no dedicated `abstract-type-refining` slice.
- `src/lib/types.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/ref_null_exact_surface_test.mbt`, `src/wast/exact_type_equivalence_test.mbt`, `src/validate/env.mbt`, `src/validate/match.mbt`, `src/validate/typecheck.mbt`, and `src/binary/encode.mbt` provide reusable type-section, exact-reference, custom-descriptor, branch-cast, typechecking, and binary-emission surfaces, but they are not a pass implementation.

## Main uncertainty

The unresolved local question is not the upstream algorithm.
The unresolved question is where Starshine should put the first faithful closed-world type-graph rewrite engine that can support ATR's exact/descriptor repair requirements.

A faithful port would need all of these local capabilities:

- whole-module heap-type inventory and closed-world visibility classification
- GC plus closed-world gating
- `struct.new*` creation scanning across module code and all function bodies
- public heap-type keepalive treatment
- upward created-subtype propagation
- TNH-equivalent mode gating for unique-live-child refinement
- bottom-type mapping for fully never-created struct families
- exact-cast impossibility preservation
- descriptor operand side-effect and null-trap preservation
- `ref.get_desc`, `br_on_cast_desc_eq*`, and `struct.new_desc` repair
- coherent whole-module type-use rewrite
- an explicit split from later declared subtype-edge cleanup in `unsubtyping`
- validation or refinalization after the rewrite

Until those exist, the Starshine wiki should keep `abstract-type-refining` framed as a boundary-only closed-world type-graph module pass, not as a hidden partial implementation.

## Pages changed by this follow-up

- `docs/wiki/raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`
- `docs/wiki/raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/starshine-strategy.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/index.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/traps-never-happen-exact-casts-and-descriptors.md`
- `docs/wiki/binaryen/passes/abstract-type-refining/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Follow-up recommendations

- Add a dedicated backlog slice before implementing `abstract-type-refining`; the current boundary-only registry entry is not enough to define the port scope.
- Do not implement only “replace abstract parent with live child.” Binaryen parity requires bottomization, TNH gating, exact-cast preservation, descriptor repair, and final validation/refinalization.
- Treat `abstract-type-refining` as type-section/module-owned work rather than HOT expression rewriting.
- If Starshine later adds shared closed-world type-graph infrastructure, re-review whether ATR should share that machinery with `remove-unused-types`, `type-refining`, `minimize-rec-groups`, `type-merging`, and `unsubtyping`.
