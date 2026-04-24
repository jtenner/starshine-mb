---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../binaryen/2026-04-24-avoid-reinterprets-primary-sources.md
  - ../../binaryen/passes/avoid-reinterprets/index.md
  - ../../binaryen/passes/avoid-reinterprets/binaryen-strategy.md
  - ../../binaryen/passes/avoid-reinterprets/wat-shapes.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/ir/hot_builders.mbt
  - ../../../../src/ir/hot_mutate.mbt
  - ../../../../src/ir/use_def.mbt
  - ../../../../src/ir/ssa_local.mbt
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/avoid-reinterprets/starshine-strategy.md
  - ../../binaryen/passes/avoid-reinterprets/single-load-chains-and-bailouts.md
  - ../../binaryen/passes/alignment-lowering/index.md
  - ../../binaryen/passes/optimize-added-constants/index.md
---

# `avoid-reinterprets` primary-source and Starshine follow-up

## Question

The existing `avoid-reinterprets` folder already taught Binaryen's algorithm, but it still lacked two things required by the current pass-wiki quality bar:

1. an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`, and
2. a dedicated Starshine strategy page that maps the upstream strategy to exact in-repo local status and future landing surfaces.

## Work performed

- Re-read the existing `avoid-reinterprets` living folder, the pass tracker, the top-level wiki index and log, the local pass registry, the pass-port batch map, and the active backlog.
- Captured the reviewed primary online sources in `docs/wiki/raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/avoid-reinterprets/starshine-strategy.md`.
- Refreshed the existing `avoid-reinterprets` pages so the folder now points at the raw manifest and local strategy page instead of remaining an upstream-only dossier.

## Primary-source findings

The new raw manifest records the official Binaryen sources reviewed in this run:

- `version_129` release page and releases index
- `src/passes/AvoidReinterprets.cpp`
- `src/passes/pass.cpp`
- `src/ir/local-graph.h`
- `src/ir/properties.h`
- `src/wasm/wasm.h`
- `test/lit/passes/avoid-reinterprets.wast`
- `test/lit/passes/avoid-reinterprets64.wast`

Durable source-backed conclusions stayed stable:

- `avoid-reinterprets` is a public Binaryen pass.
- The real implementation is a small function-parallel postwalker, not a whole-module planner.
- Direct `reinterpret(load)` can become an opposite-typed load immediately.
- Indirect `reinterpret(local.get)` only rewrites after `LocalGraph` proves a single full-width source load.
- The indirect case duplicates the load at the source site and preserves both original-type and alternate-type views through helper locals.
- Partial loads, unreachable loads, entry/parameter values, multi-source merges, and non-fallthrough wrappers are deliberate no-op families.
- Memory64 changes the pointer-temp type and is covered by a dedicated lit file.

A narrow 2026-04-24 current-`main` spot check did not expose teaching-relevant drift from the reviewed `version_129` contract.

## Starshine findings

The local code map is intentionally status-oriented because there is no implementation file yet.

Current Starshine facts:

- `src/passes/optimize.mbt` keeps `avoid-reinterprets` in `pass_registry_removed_names()`.
- The active pipeline rejects requested removed names with `pass flag {name} is removed from the active hot pipeline registry`.
- `src/passes/registry_test.mbt` covers the removed-name rejection path generically today through `de-nan`; there is not yet a pass-specific `avoid-reinterprets` regression.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still lists `avoid-reinterprets` as Batch 1 work removed until a hot implementation lands.
- `agent-todo.md` still has no dedicated `avoid-reinterprets` slice.
- The canonical no-DWARF / saved-`-O4z` queue does not currently require this pass.

Potential future local landing surfaces are visible but not yet a plan:

- `src/ir/hot_builders.mbt` already has builders for `LocalGet`, `LocalSet`, `LocalTee`, `Load`, and `Unary` nodes.
- `src/ir/hot_mutate.mbt` has `hot_append_body_local(...)`, which is the kind of local-extension API a helper-local rewrite would need.
- `src/ir/use_def.mbt` and `src/ir/ssa_local.mbt` expose local read/write and SSA-style value queries, but they are not the same contract as Binaryen's `LocalGraph::getSets(...)` and should not be cited as an existing implementation of the pass.

## Main uncertainty

The unresolved local question is not the upstream algorithm. The unresolved question is how exactly to encode Binaryen's `LocalGraph` single-set proof in Starshine's HOT analyses without overclaiming an equivalence that does not exist today.

The future port should decide whether to:

- build a small pass-local reaching-set proof,
- reuse HOT local SSA only after documenting the exact merge/entry/cycle boundaries,
- or introduce a LocalGraph-like helper shared with other locals-family ports.

Until that decision lands, the wiki should keep the strategy page framed as a status-and-port-planning bridge, not as an implementation guide for already-existing code.

## Pages changed by this follow-up

- `docs/wiki/raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`
- `docs/wiki/raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/starshine-strategy.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/index.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/single-load-chains-and-bailouts.md`
- `docs/wiki/binaryen/passes/avoid-reinterprets/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Follow-up recommendations

- If an implementation slice is created later, give it a dedicated backlog ID instead of leaving it implicit in the old Batch 1 removed list.
- Add a pass-specific request-rejection regression for `avoid-reinterprets` when the registry tests are next touched for removed-pass coverage.
- Keep `avoid-reinterprets`, `alignment-lowering`, and `optimize-added-constants` separate in future memory-pass planning: they all touch load-side shapes but prove different facts and rewrite different operands.
