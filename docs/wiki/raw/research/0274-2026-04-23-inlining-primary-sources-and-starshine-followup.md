---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-inlining-primary-sources.md
  - ../../binaryen/passes/inlining/index.md
  - ../../binaryen/passes/inlining/binaryen-strategy.md
  - ../../binaryen/passes/inlining/implementation-structure-and-tests.md
  - ../../binaryen/passes/inlining/heuristics-splitting-and-plain-vs-optimizing.md
  - ../../binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ../../binaryen/passes/inlining/wat-shapes.md
  - ../../binaryen/passes/inlining/starshine-strategy.md
  - ../../binaryen/passes/inlining-optimizing/index.md
  - ../../binaryen/passes/inlining-optimizing/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
  - ../../binaryen/passes/tracker.md
---

# `inlining` primary-source and Starshine follow-up

## Why this follow-up exists

The existing plain-`inlining` dossier already had the required landing page, Binaryen strategy page, implementation/test map, transformed-shape coverage, and the follow-up page that corrected the inline-hints vs `no-inline*` policy split.
However, it still had two durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page

This follow-up closes those gaps and refreshes the touched catalogs so the folder now reads cleanly from upstream release/source/test provenance through exact current Starshine status and future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-inlining-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `Inlining.cpp` on `version_129` and `main`
- `pass.cpp`
- `NoInline.cpp`
- `opt-utils.h`
- `pass.h`
- `wasm.h`
- `wasm.cpp`
- `wasm-binary.cpp`
- `contexts.h`
- `module-utils.cpp`
- the main `inlining*`, `no-inline*`, `inline-main`, and inline-hint lit roster

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md`
- `docs/wiki/binaryen/passes/tracker.md`
- the neighboring `inlining-optimizing`, `inline-main`, `duplicate-function-elimination`, and `monomorphize` dossiers

## Durable findings

### 1. The upstream dossier needed provenance and a local bridge, not a new Binaryen explanation

The existing living pages already taught the main upstream contract correctly:

- whole-module function summaries
- direct-call chosen-action planning in reviewed `version_129`
- layered tiny / one-caller / trivial-wrapper heuristics
- narrow Pattern A / Pattern B partial inlining
- copied-local, label, return, and nondefaultable-local repair
- the explicit split from `inlining-optimizing`

What was missing was provenance and a single local-status page.
This run added the immutable raw manifest and linked it into the folder so the reviewed release/source/test surface is no longer only implicit in older research notes.

### 2. The main local gap was the missing Starshine page, even though plain `inlining` is still unimplemented

`inlining` remains unimplemented in Starshine.
There is still no `src/passes/inlining.mbt` owner file.

But the repo already had a real local strategy surface in the broader status-and-port-planning sense:

- `src/passes/optimize.mbt` keeps `inlining` in the boundary-only registry
- the same file rejects explicit requests with a boundary-only error instead of silently pretending the pass exists in the active pipeline
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` already places it in the whole-module or layout transform bucket, not the HOT-local cleanup bucket
- `agent-todo.md` still has **no dedicated plain-`inlining` slice**, which is itself a durable planning fact worth making explicit rather than silently inventing backlog coverage
- the neighboring `inlining-optimizing` dossier already teaches the shared upstream engine and the later optimizing wrapper split

Before this run, those local facts were scattered.
The new Starshine page turns them into one read-along path.

### 3. Plain `inlining` needs a narrower local status story than `inlining-optimizing`

The optimizing sibling already has a dedicated backlog slice under `INL` because it is on the canonical no-DWARF path.
Plain `inlining` does not.

That makes the honest current local summary:

- boundary-only name preserved
- active request guard preserved
- whole-module landing zone preserved
- shared-engine relation to `inlining-optimizing` documented
- no dedicated implementation file
- no dedicated backlog slice yet

That is a useful distinction for future contributors.
A future local plain-`inlining` port would probably share most of its core machinery with any later `inlining-optimizing` port, but it still needs to be taught as the smaller public contract: inline planning and rewrite without the optimizing sibling's nested useful-pass rerun.

### 4. The right future local implementation shape is still a boundary/module pass, not a HOT peephole

Re-reading the local registry and planning docs reinforces a key point:

- `inlining` is a whole-module planner and rewriter
- it depends on module-wide function summaries and function-boundary rewrites
- it removes dead private helpers after successful inlines
- it shares heavy low-level machinery with `inline-main`, `inlining-optimizing`, and some of the same surrounding late-tail cleanup neighbors

So even the plain sibling should be taught locally as a boundary/module port with:

1. whole-module summary collection
2. direct-call chosen-action planning
3. inline-body rewrite with local / label / return / type repair
4. dead-helper cleanup subject to roots and surviving uses
5. validation against the shared upstream `Inlining.cpp` contract

The local page now makes that boundary shape explicit instead of leaving plain `inlining` as only an upstream research island.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-inlining-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0274-2026-04-23-inlining-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/inlining/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/inlining/index.md`
- `docs/wiki/binaryen/passes/inlining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `inlining` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-inlining-primary-sources.md`
2. `docs/wiki/binaryen/passes/inlining/index.md`
3. `docs/wiki/binaryen/passes/inlining/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/inlining/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/inlining/heuristics-splitting-and-plain-vs-optimizing.md`
6. `docs/wiki/binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md`
7. `docs/wiki/binaryen/passes/inlining/wat-shapes.md`
8. `docs/wiki/binaryen/passes/inlining/starshine-strategy.md`
9. `src/passes/optimize.mbt`
10. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
11. `agent-todo.md`
12. `docs/wiki/binaryen/passes/inlining-optimizing/index.md`
13. `docs/wiki/binaryen/passes/inlining-optimizing/starshine-strategy.md`
14. `docs/wiki/binaryen/passes/inline-main/index.md`
15. `docs/wiki/binaryen/passes/monomorphize/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status and the practical local landing zone for a future plain `inlining` port.
