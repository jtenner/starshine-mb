---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-merge-locals-primary-sources.md
  - ../../binaryen/passes/merge-locals/index.md
  - ../../binaryen/passes/merge-locals/binaryen-strategy.md
  - ../../binaryen/passes/merge-locals/local-graph-and-copy-influences.md
  - ../../binaryen/passes/merge-locals/wat-shapes.md
  - ../../binaryen/passes/merge-locals/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../binaryen/passes/optimize-casts/index.md
  - ../../binaryen/passes/local-subtyping/index.md
  - ../../binaryen/passes/coalesce-locals/index.md
---

# `merge-locals` primary-source and source-correction follow-up

## Why this follow-up exists

The existing `merge-locals` dossier already had a landing page, a Binaryen strategy page, a LocalGraph explainer, and a WAT-shape page.
But it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- older 2026-04-20 living wording materially overread the reviewed `version_129` source by teaching `merge-locals` as a one-set-local plus optional fresh-temp normalizer with a local-name early bailout

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched living pages around the actual `version_129` implementation.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-merge-locals-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `MergeLocals.cpp` on `version_129` and `main`
- `pass.cpp`
- `pass.h`
- `local-graph.h`
- `LocalStructuralDominance.h`
- `pass-utils.h`
- `merge-locals.wast`

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- the neighboring `optimize-casts`, `local-subtyping`, and `coalesce-locals` dossiers

## Durable findings

### 1. The old Binaryen explanation needed a real source correction, not just fresher provenance

The largest correction is conceptual.
The older dossier framed the pass as:

- pick locals with exactly one set
- require their value to be simple
- either reuse one old source local or create one fresh canonical temp
- skip named-local functions instead of invalidating DWARF

The reviewed `version_129` source says something different.
The real implementation:

- reports `invalidatesDWARF() == true`
- does **not** use the older local-name early-return policy
- roots the transform in simple `local.set` expressions from `graph.setInfluences`
- computes both ordinary influences and set influences
- uses `LocalStructuralDominance` plus `EquivalentCopies` to identify alias locals whose copy sets are structurally equivalent to the root set
- chooses one **existing** target local for the group rather than creating a fresh temp local
- rewrites dominated gets and redundant copy sets around that chosen existing local

So the durable maintenance task was not just “add a raw source file.”
It was “repair the teaching surface so it stops preserving a stale algorithm story.”

### 2. The real pass is a simple-set-root plus equivalent-copy merger, not a generic one-set local merger

The source readback makes the positive cases sharper.
`merge-locals` cares about locals that participate in a rooted family like:

- one simple value local.set
- zero or more copy locals whose sets are structurally equivalent to `local.set x (local.get root)`
- dominated gets that can safely retarget to one chosen existing local

That explains why the official tests emphasize:

- transitive chains
- ordering and dominance-sensitive families
- loop cases
- multiple-equivalent-copy families
- negative cases where one extra set or a non-simple source breaks the proof

It also means the pass is narrower than the old landing page suggested in one direction and more structured in another direction: it is not “any local with one set,” but it also is not just a tiny adjacent-copy peephole.

### 3. The old “fresh temp canonicalization” story was not source-backed

The reviewed `version_129` pass source does not materialize the kind of fresh-temp canonical slot the older dossier described.
Instead, it chooses one existing target local among the compatible group and redirects other equivalent locals to that existing target.

That matters because it changes the beginner mental model and the future port scope:

- the pass is about collapsing equivalent local families onto one existing slot
- not about inventing a new canonical temp to hold a shared simple producer

The refreshed living pages now keep that correction explicit.

### 4. The missing Starshine page was still a real gap even though the pass remains unimplemented

`merge-locals` is still unimplemented in Starshine.
There is no `src/passes/merge_locals.mbt`.

But the repo still had real local strategy surfaces worth centralizing:

- `src/passes/optimize.mbt` keeps `merge-locals` in `pass_registry_removed_names()`
- the same file rejects it explicitly through the removed-pass registry path instead of silently no-oping it
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still keeps it in Batch 1 removed-pass planning
- the neighboring `optimize-casts`, `local-subtyping`, and `coalesce-locals` dossiers already define the downstream cluster a future local port would need to integrate with

Before this run, those local facts were scattered.
The new Starshine page turns them into one read-along path.

### 5. The local planning story is currently real but intentionally incomplete

There is still no dedicated `merge-locals` slice in `agent-todo.md`.
This follow-up keeps that absence explicit rather than smoothing it over.

So the honest current status is:

- known removed pass name preserved in the registry
- explicit rejection behavior preserved
- historical batch-planning intent preserved
- no implementation file yet
- no active dedicated backlog slice yet

That is a better maintenance outcome than pretending either that nothing exists locally or that a future port plan is already mature.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-merge-locals-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md`

### New living page

- `docs/wiki/binaryen/passes/merge-locals/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/merge-locals/index.md`
- `docs/wiki/binaryen/passes/merge-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-locals/local-graph-and-copy-influences.md`
- `docs/wiki/binaryen/passes/merge-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `merge-locals` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-merge-locals-primary-sources.md`
2. `docs/wiki/binaryen/passes/merge-locals/index.md`
3. `docs/wiki/binaryen/passes/merge-locals/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/merge-locals/local-graph-and-copy-influences.md`
5. `docs/wiki/binaryen/passes/merge-locals/wat-shapes.md`
6. `docs/wiki/binaryen/passes/merge-locals/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
9. `docs/wiki/binaryen/passes/optimize-casts/index.md`
10. `docs/wiki/binaryen/passes/local-subtyping/index.md`
11. `docs/wiki/binaryen/passes/coalesce-locals/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the corrected local teaching story and the exact current Starshine registry/planning status.
