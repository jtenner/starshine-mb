---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-rereloop-primary-sources.md
  - ../../binaryen/passes/rereloop/index.md
  - ../../binaryen/passes/rereloop/binaryen-strategy.md
  - ../../binaryen/passes/rereloop/wat-shapes.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/cli/cli_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - 0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/rereloop/starshine-strategy.md
  - ../../binaryen/passes/rereloop/flat-cfg-builder-and-boundaries.md
  - ../../binaryen/passes/rereloop/implementation-structure-and-tests.md
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/dataflow-optimization/index.md
---

# `rereloop` primary-source and Starshine follow-up

## Question

The existing `rereloop` folder already taught Binaryen's algorithm, but it still lacked two things required by the current pass-wiki quality bar:

1. an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. a dedicated Starshine strategy page that maps the upstream strategy to exact in-repo local status and future landing surfaces.

## Work performed

- Re-read the existing `rereloop` living folder, the pass tracker, the pass-folder map, the top-level wiki index and log, the local pass registry, the CLI/cmd tests for the local spelling, the old pass-port batch map, and the active backlog.
- Captured the reviewed primary online sources in `docs/wiki/raw/binaryen/2026-04-24-rereloop-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/rereloop/starshine-strategy.md`.
- Refreshed the existing `rereloop` pages so the folder now points at the raw manifest and local strategy page instead of remaining an upstream-only dossier.

## Primary-source findings

The new raw manifest records the official Binaryen sources reviewed in this run:

- `version_129` release page
- `src/passes/ReReloop.cpp`
- `src/passes/pass.cpp`
- `src/cfg/Relooper.h`
- `src/cfg/Relooper.cpp`
- `src/ir/flat.h`
- `test/lit/passes/flatten_rereloop.wast`
- `test/lit/passes/opt_flatten.wast`
- narrow current-`main` spot-check URLs for the key implementation and lit surfaces

Durable source-backed conclusions stayed stable:

- Upstream publishes the pass as `rereloop`; Starshine's local removed registry still tracks the hyphenated alias `re-reloop`.
- Binaryen's public registration describes the pass as control-flow reoptimization through the relooper algorithm.
- The active reviewed default-path story remains noncommittal: upstream `pass.cpp` keeps `rereloop` as a TODO near the flatten-era `-O4` cluster rather than as an active reviewed default slot.
- `Flat::verifyFlatness(function)` is the first real implementation step, so flat input is a hard precondition.
- The pass-local adapter builds temporary CFG blocks from flat top-level control forms and delegates structured reconstruction to `cfg/Relooper.*`.
- The generic relooper's branch-condition side-effect rule explains why flatness matters for correctness.
- The implementation hard-fails on EH instructions in the reviewed contract.
- The rendered output may intentionally introduce helper blocks, helper names, and a fresh `i32` label local before later cleanup passes simplify anything.
- A narrow 2026-04-24 current-`main` spot check did not expose teaching-relevant drift from the reviewed `version_129` contract.

## Starshine findings

The local code map is intentionally status-oriented because there is no implementation file yet.

Current Starshine facts:

- `src/passes/optimize.mbt` keeps `re-reloop` in `pass_registry_removed_names()`.
- Registry construction converts removed names into `HotPassRegistryCategory::Removed` entries.
- The active pipeline rejects requested removed names with `pass flag {name} is removed from the active hot pipeline registry`.
- `src/cli/cli_test.mbt` has direct parse coverage for the local `--re-reloop` spelling.
- `src/cmd/cmd_wbtest.mbt` has request-rejection coverage for `--re-reloop` and help-output coverage proving the removed pass is hidden from help.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still lists `re-reloop` under Batch 2 removed-until-hot-implementation names.
- `agent-todo.md` still has no dedicated `rereloop` / `re-reloop` slice.
- The canonical no-DWARF / saved-`-O4z` queue does not currently require this pass.

Potential future local landing surfaces are visible but not yet a plan:

- a future port probably needs to follow the existing removed-name registry transition pattern,
- it should likely land beside the `flatten`, `simplify-locals-*`, `local-cse`, `dataflow-optimization`, and `souperify` flatness-sensitive cluster,
- it needs either a Starshine equivalent of Binaryen Flat IR or a proven local flatness contract before using branch conditions as relocatable CFG-edge conditions,
- and it needs an explicit structured-rendering design rather than assuming existing HOT block flattening is the same thing as a generic Relooper.

## Main uncertainty

The unresolved local question is not the upstream algorithm. The unresolved question is whether Starshine should ever implement `re-reloop` as part of a future aggressive flat-IR cluster.

The source-backed upstream state says `rereloop` is real, but not active in the reviewed default no-DWARF route. The local state says the name is preserved, but removed, with no current backlog slice.

Until that changes, the wiki should keep the strategy page framed as a status-and-port-planning bridge, not as an implementation guide for already-existing code.

## Pages changed by this follow-up

- `docs/wiki/raw/binaryen/2026-04-24-rereloop-primary-sources.md`
- `docs/wiki/raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/rereloop/starshine-strategy.md`
- `docs/wiki/binaryen/passes/rereloop/index.md`
- `docs/wiki/binaryen/passes/rereloop/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/rereloop/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/rereloop/flat-cfg-builder-and-boundaries.md`
- `docs/wiki/binaryen/passes/rereloop/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Follow-up recommendations

- If an implementation slice is created later, give it a dedicated backlog ID instead of relying only on the old Batch 2 removed-name breadcrumb.
- Preserve the upstream/local naming split explicitly: `rereloop` in Binaryen, `re-reloop` in current Starshine registry state.
- Keep `rereloop` separate from `flatten`: flatten creates the flat precondition; rereloop consumes it and rebuilds structure.
- Keep EH unsupported until a deliberate local design widens beyond Binaryen `version_129`.
- Do not treat helper blocks or helper label locals as cosmetic test noise; they are part of the generic renderer's visible contract before cleanup.
