---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
  - ../../../raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
---

# Starshine strategy for `merge-locals`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md`](../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`merge-locals` is still **unimplemented** in Starshine.
There is no `src/passes/merge_locals.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is registry tracking plus future-cluster planning:

- keep the upstream pass spelling tracked in the removed-name registry
- reject the pass explicitly instead of silently accepting it as a no-op
- keep the historical pass-port planning document honest about its removed status
- keep the neighboring local-cleanup dossiers explicit about where a future port would have to land

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code and doc map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - `src/passes/optimize.mbt`
    - `pass_registry_removed_names()` includes `"merge-locals"`
- explicit rejection behavior
  - `src/passes/optimize.mbt`
    - the removed-pass resolution path rejects requested removed passes instead of silently scheduling them
- current batch intent
  - `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
    - Batch 1 still lists `merge-locals` under removed-until-hot-implementation names
- exact neighboring living dossiers that define the future landing zone
  - [`../optimize-casts/index.md`](../optimize-casts/index.md)
  - [`../local-subtyping/index.md`](../local-subtyping/index.md)
  - [`../coalesce-locals/index.md`](../coalesce-locals/index.md)

One important negative local fact is also worth keeping explicit:

- there is currently no `src/passes/merge_locals_test.mbt`
- there is currently no dedicated `merge-locals` slice in `agent-todo.md`

So the current local story is real, but intentionally incomplete.

## What Starshine currently does for this pass name

Today Starshine's behavior for `merge-locals` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps the upstream spelling `merge-locals` in `pass_registry_removed_names()`.
That means:

- the project still treats `merge-locals` as a real known pass
- the name is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and planning work instead of silently falling out of scope

That is the right current behavior for an unimplemented parity pass.

### 2. The request path fails explicitly

`src/passes/optimize.mbt` also keeps the removed-pass rejection surface alive.
That matters because it preserves an honest local contract:

- the pass is known
- the pass is not implemented
- the pass is rejected deliberately

That is much healthier than the old legacy no-op pattern this repo has been removing.

### 3. The repo has historical planning intent, but no active execution slice

`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still keeps `merge-locals` in Batch 1 removed-pass planning.
That is a real planning fact.

But there is not yet a matching active delivery slice in `agent-todo.md`.
So the honest current summary is:

- registry tracked
- rejection path tracked
- planning doc tracked
- implementation and active backlog slice still absent

## The right future Starshine implementation shape

The refreshed Binaryen dossier strongly suggests that a future local port should be taught as a **rooted equivalent-copy cleanup pass**, not as a generic one-set-local normalizer.

Why:

- the reviewed Binaryen contract starts from simple root sets, not arbitrary locals
- the proof surface depends on `LocalGraph` plus `LocalStructuralDominance`
- the pass collapses equivalent copy wrappers onto one existing winner local
- the pass sits in a local-cleanup cluster just before `optimize-casts`, `local-subtyping`, and `coalesce-locals`

So the right local implementation mental model is:

1. build or reuse a local influence representation rich enough to express root sets and copy-wrapper reachability
2. add a proof layer equivalent in spirit to Binaryen's structural-dominance plus equivalent-copy checks
3. choose one existing winner local for each proven family
4. retarget dominated gets and redundant copy sets
5. run in the same broader cluster neighborhood as future `optimize-casts`, `local-subtyping`, and `coalesce-locals`

That is much more precise than the older “merge similar locals” summary.

## The most important local dependency map

### `merge-locals` belongs to the stronger local-cleanup cluster

See the neighboring dossiers:

- [`../optimize-casts/index.md`](../optimize-casts/index.md)
- [`../local-subtyping/index.md`](../local-subtyping/index.md)
- [`../coalesce-locals/index.md`](../coalesce-locals/index.md)

Why it matters locally:

- the reviewed Binaryen scheduler places `merge-locals` immediately before that cluster
- a future Starshine port should therefore be designed as part of a sequence, not as an isolated one-off pass

### `merge-locals` is not a substitute for `coalesce-locals`

This distinction is especially important for local planning.
A future contributor should not try to “cover both at once” by describing one vague locals cleanup.

The documented cluster split is:

- `merge-locals` = rooted equivalent-copy family cleanup
- `coalesce-locals` = broader slot-sharing / interference cleanup

That conceptual separation should survive any local port plan.

### The future local landing zone is probably analysis-heavy, not a tiny peephole

Nothing in the current reviewed Binaryen contract suggests this should be taught as one small AST peephole.
The pass depends on:

- local influence information
- set-root reasoning
- copy-equivalence checks
- structural dominance

So if Starshine ports it, the likely landing zone is an analysis-heavy local pass near other locals-cleanup work, not a single trivial helper buried inside an unrelated pass.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `merge-locals`
- a dedicated local test file for the pass
- an active backlog slice with deliverables and exit criteria
- a committed local proof layer explicitly described as the equivalent of Binaryen's `LocalStructuralDominance` contract for this pass

So the current repo status is best summarized as:

- name tracked
- failure mode tracked
- historical batch intent tracked
- transform itself not yet landed

## Validation plan for the eventual port

The current docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced structural tests for the core proof surface
   - simple root-set positives
   - direct equivalent-copy wrapper positives
   - transitive wrapper positives
   - extra-set and non-simple-root negatives
2. dominance-sensitive tests
   - ordering-sensitive rewrites
   - loop families
   - cases where some uses must not retarget
3. cluster interaction tests
   - `merge-locals -> optimize-casts`
   - `merge-locals -> local-subtyping`
   - `merge-locals -> coalesce-locals`
4. artifact and oracle comparison
   - once the active backlog grows a real `merge-locals` slice and the exact local slot becomes executable

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the real downstream contracts already documented in this repo.

## Bottom line

Current Starshine `merge-locals` strategy is honest registry tracking plus future cluster planning:

- the upstream spelling is intentionally preserved in `src/passes/optimize.mbt`
- the pass is intentionally rejected through the removed-pass path rather than silently no-oping
- the historical Batch 1 planning doc still records the name as a future removed-pass port target
- there is still no MoonBit implementation file and still no active dedicated backlog slice
- the neighboring `optimize-casts`, `local-subtyping`, and `coalesce-locals` dossiers already define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear rejection surface**
- **clear future cluster**
- **clear warning that the implementation and active backlog slice still do not exist**
