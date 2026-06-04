---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-unsubtyping-primary-sources.md
  - ../../binaryen/passes/unsubtyping/index.md
  - ../../binaryen/passes/unsubtyping/binaryen-strategy.md
  - ../../binaryen/passes/unsubtyping/wat-shapes.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/cmd/fuzz_harness_wbtest.mbt
  - 0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/module_wast_tests.mbt
  - ../../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/unsubtyping/starshine-strategy.md
  - ../../binaryen/passes/unsubtyping/implementation-structure-and-tests.md
  - ../../binaryen/passes/unsubtyping/descriptor-squares-casts-and-js-boundaries.md
  - ../../binaryen/passes/type-refining/index.md
  - ../../binaryen/passes/global-struct-inference/index.md
  - ../../binaryen/passes/remove-unused-types/index.md
---

# `unsubtyping` primary-source and Starshine follow-up

## Question

The existing `unsubtyping` folder already taught Binaryen's algorithm, implementation structure, focused descriptor/cast/JS rules, and WAT-shape families, but it still lacked two things required by the current pass-wiki quality bar:

1. an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. a dedicated Starshine strategy page that maps the upstream strategy to exact in-repo local status and future landing surfaces.

## Work performed

- Re-read the existing `unsubtyping` living folder, the pass tracker, the pass-folder map, the top-level wiki index and log, the local pass registry, the pass-port batch map, and the active backlog.
- Captured the reviewed primary online sources in `docs/wiki/raw/binaryen/2026-04-24-unsubtyping-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/unsubtyping/starshine-strategy.md`.
- Refreshed the existing `unsubtyping` pages so the folder now points at the raw manifest and local strategy page instead of remaining an upstream-only dossier.

## Primary-source findings

The new raw manifest records the official Binaryen sources reviewed in this run:

- `version_129` release page and releases index
- `src/passes/Unsubtyping.cpp`
- `src/passes/pass.cpp`
- `src/ir/subtype-exprs.h`
- `src/ir/js-utils.h`
- `src/ir/module-utils.h`
- `src/ir/type-updating.{h,cpp}`
- `src/ir/localize.h`
- `src/ir/effects.h`
- `src/wasm-type.h`
- the dedicated `unsubtyping*.wast` lit roster

Durable source-backed conclusions stayed stable:

- `unsubtyping` is a closed-world GC module pass, not part of Starshine's current open-world no-DWARF parity path.
- The pass body itself rejects non-closed-world runs after its GC feature gate.
- The algorithm computes a minimal subtype plus descriptor relation graph, not a simple syntactic dead-supertype list.
- Public heap types stay frozen.
- The initial relation set comes from public boundaries, JS boundary flow, broad validation constraints, explicit descriptor users, and cast-like operations.
- Ordinary casts are flow-sensitive in the fixed point; exact casts have a narrower success-preservation surface.
- Descriptor-square completion makes descriptor and ordinary subtype edges recursively dependent.
- Descriptor-bearing allocation fixups and final refinalization are part of correctness, not cleanup afterthoughts.
- The official tests often pair `--unsubtyping` with `--remove-unused-types`, so visible type-definition deletion in test output must not be over-attributed to `unsubtyping` alone.
- A narrow 2026-04-24 current-`main` spot check did not expose teaching-relevant drift from the reviewed `version_129` contract.

## Starshine findings

The local code map is intentionally status-oriented because there is no implementation file yet.

Current Starshine facts:

- `src/passes/optimize.mbt` keeps `unsubtyping` in `pass_registry_boundary_only_names()`.
- Registry construction converts boundary-only names into `HotPassRegistryCategory::BoundaryOnly` entries.
- The active pipeline rejects requested boundary-only names with `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
- The generic command/fuzz harness boundary-only rejection test currently uses `global-struct-inference-desc-cast`, not `unsubtyping`; there is no `unsubtyping`-specific active request test today.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` groups `unsubtyping` with boundary-only type/global/signature shaping names.
- `agent-todo.md` still has no dedicated `unsubtyping` slice.
- The existing type-section and custom-descriptor surfaces in `src/lib/types.mbt`, `src/wast/module_wast_tests.mbt`, and `src/wast/ref_null_exact_surface_test.mbt` are reusable prerequisites, but they are not a pass implementation.

## Main uncertainty

The unresolved local question is not the upstream algorithm. The unresolved question is what minimum Starshine type-graph infrastructure must exist before this boundary-only pass can move into an implemented module pass.

A faithful port would need all of these local capabilities:

- closed-world option plumbing and scheduling, or an explicit local equivalent
- a module-wide public/private heap-type classifier
- a validation-constraint discoverer broad enough to cover functions, globals, tables, element segments, control flow, GC operations, EH, and stack switching
- ordinary-vs-exact cast success-preservation analysis
- descriptor-square and JS-boundary keepalive analysis
- type-section graph rewriting over `SubType` / `TypeMetadata` / rec-group structures
- module-wide type-use rewriting and refinalization after graph changes
- descriptor-allocation fixups that preserve traps when descriptors are removed

Until those exist, the Starshine wiki should keep `unsubtyping` framed as a boundary-only closed-world type-graph pass, not as a hidden partial implementation.

## Pages changed by this follow-up

- `docs/wiki/raw/binaryen/2026-04-24-unsubtyping-primary-sources.md`
- `docs/wiki/raw/research/0289-2026-04-24-unsubtyping-primary-sources-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/unsubtyping/starshine-strategy.md`
- `docs/wiki/binaryen/passes/unsubtyping/index.md`
- `docs/wiki/binaryen/passes/unsubtyping/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/unsubtyping/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/unsubtyping/descriptor-squares-casts-and-js-boundaries.md`
- `docs/wiki/binaryen/passes/unsubtyping/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Follow-up recommendations

- Add a dedicated backlog slice before implementing `unsubtyping`; the current boundary-only registry entry is not enough to define the scope.
- Keep the combo-test caveat visible whenever discussing upstream WAT outputs because `remove-unused-types` often performs the visible deletion after `unsubtyping` removes relations.
- Do not attempt a peephole-only port. The upstream contract is module-owned type-graph rewriting plus validation/cast/descriptor/JS analysis.
- If Starshine later adds closed-world type-graph infrastructure for neighboring passes, re-review whether `unsubtyping` can share that machinery with `type-refining`, `remove-unused-types`, `abstract-type-refining`, and `type-merging`.
