---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-simplify-globals-primary-sources.md
  - ../../binaryen/passes/simplify-globals/index.md
  - ../../binaryen/passes/simplify-globals/binaryen-strategy.md
  - ../../binaryen/passes/simplify-globals/implementation-structure-and-tests.md
  - ../../binaryen/passes/simplify-globals/plain-vs-optimizing-and-safety.md
  - ../../binaryen/passes/simplify-globals/wat-shapes.md
  - ../../binaryen/passes/simplify-globals/starshine-strategy.md
  - ../../binaryen/passes/simplify-globals-optimizing/index.md
  - ../../binaryen/passes/propagate-globals-globally/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
  - ../../binaryen/passes/tracker.md
---

# `simplify-globals` primary-source and Starshine follow-up

## Why this follow-up exists

The existing plain-`simplify-globals` dossier already had the required landing page, Binaryen strategy page, implementation/test map, transformed-shape coverage, and a focused safety page.
However, it still had two durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page

This follow-up closes those gaps and refreshes the touched catalogs so the folder now reads cleanly from upstream release/source/test provenance through exact current Starshine status and future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-simplify-globals-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `SimplifyGlobals.cpp` on `version_129` and `main`
- `pass.cpp`
- `pass.h`
- `effects.h`
- `find_all.h`
- `linear-execution.h`
- `properties.h`
- `utils.h`
- the dedicated `simplify-globals-*` and `propagate-globals-globally` lit roster

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- the neighboring `simplify-globals-optimizing` and `propagate-globals-globally` dossiers
- `docs/wiki/binaryen/passes/tracker.md`

## Durable findings

### 1. The upstream dossier needed provenance and a local bridge, not a new Binaryen explanation

The existing living pages already taught the main upstream contract correctly:

- shared `SimplifyGlobals.cpp` family ownership
- startup-only single-use folding into later global initializers
- dead and same-as-init write cleanup with `drop(value)` preservation
- exact `read-only-to-write` legality and actual-node matching rules
- startup-vs-runtime propagation as different algorithms
- the explicit stop point before the optimizing sibling's nested default-function rerun

What was missing was provenance and a single local-status page.
This run added the immutable raw manifest and linked it into the folder so the reviewed release/source/test surface is no longer only implicit in older research notes.

### 2. The main local gap was the missing Starshine page, even though plain `simplify-globals` is still unimplemented

`simplify-globals` remains unimplemented in Starshine.
There is still no `src/passes/simplify_globals.mbt` or similarly named owner file today.

But the repo already had a real local strategy surface in the broader status-and-port-planning sense:

- `src/passes/optimize.mbt` keeps `simplify-globals` in the boundary-only registry
- the same file rejects explicit requests with a boundary-only error instead of silently pretending the pass exists in the active pipeline
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` already groups `simplify-globals` with type/global/signature shaping work rather than HOT-local cleanup
- `agent-todo.md` has slices only for the optimizing sibling under `SGO`, which is itself a durable planning fact worth making explicit instead of silently inventing plain-pass backlog coverage
- the neighboring `simplify-globals-optimizing` and `propagate-globals-globally` dossiers already teach the shared upstream engine and sibling split

Before this run, those local facts were scattered.
The new Starshine page turns them into one read-along path.

### 3. Plain `simplify-globals` needs a smaller and more honest local status story than `simplify-globals-optimizing`

The optimizing sibling already has a dedicated backlog slice under `SGO` because it is on the canonical no-DWARF late path.
Plain `simplify-globals` does not.

That makes the honest current local summary:

- boundary-only name preserved
- active request guard preserved
- shared-engine relation to `simplify-globals-optimizing` documented
- startup-only sibling relation to `propagate-globals-globally` documented
- no dedicated implementation file
- no dedicated plain-pass backlog slice yet

That distinction is useful for future contributors.
A future local plain-`simplify-globals` port would likely share most of its global-analysis and rewrite machinery with any later `simplify-globals-optimizing` port, but it still needs to be taught as the smaller public contract: run the global rewrite family, repair affected types, and stop.

### 4. The right future local implementation shape is still a boundary/module pass, not a HOT peephole

Re-reading the local registry and planning docs reinforces a key point:

- `simplify-globals` is a whole-module global-state analysis and rewrite pass
- it depends on module-wide global traffic facts and startup-order reasoning
- it also rewrites function bodies, but only through a module pass that owns global knowledge
- it shares heavy machinery with `simplify-globals-optimizing` and `propagate-globals-globally`
- it sits conceptually beside other late boundary/global passes like `duplicate-import-elimination`, `remove-unused-module-elements`, `string-gathering`, `reorder-globals`, and `directize`

So even the plain sibling should be taught locally as a boundary/module port with:

1. module-wide `GlobalInfo`-style fact gathering
2. startup-only folding and propagation over global initializers and active offsets
3. runtime propagation over cheap linear traces in function bodies
4. dead-write and `read-only-to-write` cleanup that preserves side effects with `drop(value)`
5. targeted function type repair after refined substitutions
6. a stop point before the optimizing sibling's nested default-function rerun

The local page now makes that boundary shape explicit instead of leaving plain `simplify-globals` as only an upstream research island.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-simplify-globals-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0275-2026-04-23-simplify-globals-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/simplify-globals/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/simplify-globals/index.md`
- `docs/wiki/binaryen/passes/simplify-globals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-globals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `simplify-globals` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-simplify-globals-primary-sources.md`
2. `docs/wiki/binaryen/passes/simplify-globals/index.md`
3. `docs/wiki/binaryen/passes/simplify-globals/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/simplify-globals/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/simplify-globals/plain-vs-optimizing-and-safety.md`
6. `docs/wiki/binaryen/passes/simplify-globals/wat-shapes.md`
7. `docs/wiki/binaryen/passes/simplify-globals/starshine-strategy.md`
8. `src/passes/optimize.mbt`
9. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
10. `agent-todo.md`
11. `docs/wiki/binaryen/passes/simplify-globals-optimizing/index.md`
12. `docs/wiki/binaryen/passes/propagate-globals-globally/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status and the practical local landing zone for a future plain `simplify-globals` port.
