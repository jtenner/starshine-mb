---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-de-nan-primary-sources.md
  - ../../binaryen/passes/de-nan/index.md
  - ../../binaryen/passes/de-nan/binaryen-strategy.md
  - ../../binaryen/passes/de-nan/wat-shapes.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/de-nan/starshine-strategy.md
  - ../../binaryen/passes/de-nan/helper-functions-fallthrough-and-boundaries.md
  - ../../binaryen/passes/de-nan/implementation-structure-and-tests.md
  - ../../binaryen/passes/global-effects/index.md
  - ../../binaryen/passes/precompute/index.md
---

# `de-nan` primary-source and Starshine follow-up

## Question

The existing `de-nan` / `denan` folder already taught Binaryen's algorithm, but it still lacked two things required by the current pass-wiki quality bar:

1. an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. a dedicated Starshine strategy page that maps the upstream strategy to exact in-repo local status and future landing surfaces.

## Work performed

- Re-read the existing `de-nan` living folder, the pass tracker, the pass-folder map, the top-level wiki index and log, the local pass registry, the pass-port batch map, and the active backlog.
- Captured the reviewed primary online sources in `docs/wiki/raw/binaryen/2026-04-24-de-nan-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/de-nan/starshine-strategy.md`.
- Refreshed the existing `de-nan` pages so the folder now points at the raw manifest and local strategy page instead of remaining an upstream-only dossier.

## Primary-source findings

The new raw manifest records the official Binaryen sources reviewed in this run:

- `version_129` release page and releases index
- `src/passes/DeNaN.cpp`
- `src/passes/pass.cpp`
- `src/ir/properties.h`
- `src/ir/names.h`
- `src/wasm-builder.h`
- `src/pass.h`
- `test/lit/passes/denan.wast`

Durable source-backed conclusions stayed stable:

- Upstream publishes the pass as `denan`; Starshine's local removed registry still tracks the alias `de-nan`.
- Binaryen implements the pass as NaN-to-zero instrumentation, not ordinary optimization, NaN payload canonicalization, or default-preset scheduling.
- The pass rewrites constant NaN `f32`, `f64`, and `v128` producers directly to zero constants.
- Nonconstant float/SIMD producers inside functions are wrapped in helper calls.
- Non-imported function params of those types are sanitized on entry.
- `local.get` and `Properties::isResultFallthrough(...)` shells are intentionally skipped.
- Nonfunction contexts only get constant repair because helper calls are not legal there.
- Helper functions are generated after the walk and named collision-safely.
- The SIMD helper's lane-extraction strategy is source-backed and only lightly lit-backed.
- A narrow 2026-04-24 current-`main` spot check did not expose teaching-relevant drift from the reviewed `version_129` contract.

## Starshine findings

The local code map is intentionally status-oriented because there is no implementation file yet.

Current Starshine facts:

- `src/passes/optimize.mbt` keeps `de-nan` in `pass_registry_removed_names()`.
- Registry construction converts removed names into `HotPassRegistryCategory::Removed` entries.
- The active pipeline rejects requested removed names with `pass flag {name} is removed from the active hot pipeline registry`.
- `src/passes/registry_test.mbt` has both category coverage for `de-nan` and generic removed-name request-rejection coverage using `de-nan`.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still lists `de-nan` as Batch 1 work removed until a hot implementation lands.
- `agent-todo.md` still has no dedicated `de-nan` / `denan` slice.
- The canonical no-DWARF / saved-`-O4z` queue does not currently require this pass.

Potential future local landing surfaces are visible but not yet a plan:

- the existing pass registry and removed-name rejection path would have to change intentionally when a real port lands,
- helper-function insertion is module-level work even if expression wrapping can be implemented through HOT regions,
- Starshine would need a clear pass-metadata story for an effect-adding transform,
- and validation must include module-context legality because global initializers can only use constant repair.

## Main uncertainty

The unresolved local question is not the upstream algorithm. The unresolved question is how to classify and land a Starshine port.

`denan` is unusual for the current pass wiki because it is optional instrumentation that deliberately adds calls and helper functions. It is therefore not a simple HOT peephole even though many positive rewrites are expression-local. A future port should decide whether the pass belongs as:

- a module pass with function-body rewrites plus helper synthesis,
- a hybrid pass that uses HOT region rewriting under a module owner,
- or a later boundary-only instrumentation feature outside the default optimization presets.

Until that decision lands, the wiki should keep the strategy page framed as a status-and-port-planning bridge, not as an implementation guide for already-existing code.

## Pages changed by this follow-up

- `docs/wiki/raw/binaryen/2026-04-24-de-nan-primary-sources.md`
- `docs/wiki/raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/de-nan/starshine-strategy.md`
- `docs/wiki/binaryen/passes/de-nan/index.md`
- `docs/wiki/binaryen/passes/de-nan/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/de-nan/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/de-nan/helper-functions-fallthrough-and-boundaries.md`
- `docs/wiki/binaryen/passes/de-nan/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Follow-up recommendations

- If an implementation slice is created later, give it a dedicated backlog ID instead of leaving it implicit in the old Batch 1 removed list.
- Preserve the upstream/local naming split explicitly: `denan` in Binaryen, `de-nan` in current Starshine registry state.
- Keep `de-nan` separate from `precompute`, `global-effects`, and ordinary floating simplification: it changes behavior by forcing NaNs to zero and advertises added effects.
- Add focused tests for SIMD helper behavior if Starshine ever ports the pass; the official source is clearer than the existing lit file for that path.
