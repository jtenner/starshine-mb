---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-type-ssa-primary-sources.md
  - ../../binaryen/passes/type-ssa/index.md
  - ../../binaryen/passes/type-ssa/binaryen-strategy.md
  - ../../binaryen/passes/type-ssa/implementation-structure-and-tests.md
  - ../../binaryen/passes/type-ssa/created-exact-types-control-values-and-signature-rewrites.md
  - ../../binaryen/passes/type-ssa/wat-shapes.md
  - ../../binaryen/passes/type-ssa/starshine-strategy.md
  - ../../binaryen/passes/type-merging/index.md
  - ../../binaryen/passes/ssa/index.md
  - ../../binaryen/passes/type-refining/index.md
  - ../../binaryen/passes/type-generalizing/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
---

# `type-ssa` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `type-ssa` dossier already had the required living overview, Binaryen strategy page, implementation/test map, and transformed-shape coverage.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still taught the pass mostly as a new upstream-only folder instead of also giving readers one clean bridge into the exact in-repo Starshine status and the current absence of any local registry or backlog owner

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future Starshine planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-type-ssa-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `TypeSSA.cpp` on `version_129` and `main`
- `pass.cpp`
- `ReFinalize.cpp`
- the dedicated `type-ssa.wast` test

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring living dossiers for `ssa`, `type-merging`, `type-refining`, and `type-generalizing`

## Durable findings

### 1. The Binaryen side mostly needed provenance and freshness anchors, not another algorithm rewrite

The existing upstream pages were still broadly correct after the 2026-04-21 research wave.
The missing piece was provenance:

- on 2026-04-23 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` spot check did not surface a new teaching-relevant drift beyond the existing strategy, implementation/test, focused mechanics, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and thread that provenance into the living pages, not to replace the already-correct Binaryen explanation.

### 2. The real local gap was the missing Starshine page, even though the pass is still upstream-only

`type-ssa` is still upstream-only in Starshine, and that remains the right top-line status.
But the repo already had a real local strategy surface for it in the broader sense:

- `src/passes/optimize.mbt` defines the current active, boundary-only, and removed registry sets, and `type-ssa` appears in none of them
- the same file's expansion logic only knows how to dispatch active entries or reject tracked boundary-only / removed names, which means `type-ssa` currently has no compatibility slot at all
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` lists the active hot/module passes plus the current boundary-only and removed planning names, and `type-ssa` is absent there too
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` does **not** place the pass in the current canonical no-DWARF path
- `agent-todo.md` still has **no dedicated `type-ssa` slice**
- the neighboring `ssa`, `type-merging`, `type-refining`, and `type-generalizing` dossiers already give the most useful local conceptual boundary map for what a future port would and would not be

Before this run, that local status was scattered across omissions.
The new Starshine page turns it into one explicit teachable path.

### 3. The honest Starshine story is deliberate non-adoption, not hidden partial implementation

Unlike `alignment-lowering` or `type-refining`, the repo does not even carry `type-ssa` as a boundary-only compatibility name today.
That matters because the most honest current conclusion is stronger than “unimplemented”:

- Starshine has **not** chosen to track `type-ssa` as a future port name yet
- Starshine has **not** assigned it a backlog slice
- Starshine has **not** placed it in any current parity queue
- Starshine therefore has no active dispatch, rejection, or planning behavior specific to this pass beyond the observable omission from registry and planning surfaces

That is useful durable knowledge.
It keeps future readers from overreading the neighboring GC/type pages as evidence that a `type-ssa` port is already planned locally.

### 4. The most useful current local bridge is through neighboring implemented or tracked passes

Re-reading the neighboring dossiers sharpened the practical future-port map:

- `ssa-nomerge` is the closest active local analogue for the “SSA-like flow, but not full upstream `ssa`” side of the story
- `global-refining` and `global-struct-inference` are the current active local GC/type precision neighbors
- the boundary-only `type-refining`, `type-generalizing`, and `type-merging` dossiers remain the clearest local conceptual neighborhood for where a future `type-ssa` port would sit semantically

That does **not** mean Starshine already has a hidden `type-ssa` subset.
It means the best current local strategy page is a status-and-neighborhood page that points readers to the exact omission surfaces plus the nearest concrete implementation neighbors.

### 5. Even without a local owner, the future correctness contract is already clear

The Binaryen dossier is mature enough that a future Starshine port already has a stable source-backed invariant list to preserve:

- the tiny `createdTypes` seed surface
- `getTargetType(...)` rejection of abstract refs
- conservative `block` / `if` / `try` carried-value forwarding
- explicit `loop` exclusion
- local/global propagation
- direct-call operand and return-value retagging
- GC-only refinalization after successful changes

That means the missing local decision is not “what does `type-ssa` do?”
It is “does Starshine want this pass at all, and if yes, where should it live relative to the current GC/type and SSA-adjacent work?”

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-type-ssa-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0277-2026-04-23-type-ssa-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/type-ssa/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/type-ssa/index.md`
- `docs/wiki/binaryen/passes/type-ssa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-ssa/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `type-ssa` work needs a clean provenance-plus-local-status path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-type-ssa-primary-sources.md`
2. `docs/wiki/binaryen/passes/type-ssa/index.md`
3. `docs/wiki/binaryen/passes/type-ssa/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/type-ssa/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/type-ssa/created-exact-types-control-values-and-signature-rewrites.md`
6. `docs/wiki/binaryen/passes/type-ssa/wat-shapes.md`
7. `docs/wiki/binaryen/passes/type-ssa/starshine-strategy.md`
8. `docs/wiki/binaryen/passes/ssa/index.md`
9. `docs/wiki/binaryen/passes/type-merging/index.md`
10. `docs/wiki/binaryen/passes/type-refining/index.md`
11. `docs/wiki/binaryen/passes/type-generalizing/index.md`
12. `src/passes/optimize.mbt`
13. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
14. `agent-todo.md`
15. `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status: no local registry slot, no backlog slice, no parity-queue placement, but a clear neighboring dossier map and a stable future correctness contract if the repo ever chooses to adopt the pass.
