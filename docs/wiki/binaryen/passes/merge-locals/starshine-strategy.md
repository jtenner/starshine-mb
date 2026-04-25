---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
---

# Starshine strategy for `merge-locals`

## Honest current status

`merge-locals` is still **unimplemented** in Starshine.
There is no `src/passes/merge_locals.mbt` owner file and no `src/passes/merge_locals_test.mbt`.

Current Starshine strategy is therefore:

- keep the upstream pass name tracked
- reject explicit requests honestly
- keep the pass visible in port planning and the wiki
- avoid pretending an equivalent local transform exists

## Exact local code and doc map

| Local surface | Meaning |
| --- | --- |
| [`src/passes/optimize.mbt:144-151`](../../../../../src/passes/optimize.mbt) | `pass_registry_removed_names()` includes `merge-locals`. |
| [`src/passes/optimize.mbt:455-473`](../../../../../src/passes/optimize.mbt) | removed pass requests fail with an explicit removed-from-active-pipeline error. |
| [`src/passes/registry_test.mbt:171-179`](../../../../../src/passes/registry_test.mbt) | generic removed-pass request behavior is tested; the current sample is `de-nan`, not `merge-locals`. |
| [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:41-42`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md) | historical Batch 1 plan still lists `merge-locals` as removed until hot implementation lands. |
| `agent-todo.md` | no dedicated `merge-locals` execution slice currently exists. |

## What Starshine does for the pass name today

### 1. The name is known

Keeping `merge-locals` in the removed-name registry prevents silent drift.
Future users and agents can tell the pass is recognized but not implemented.

### 2. The request path is explicit

Requesting a removed pass fails rather than producing a misleading no-op success.
That is the correct local behavior until a real implementation exists.

### 3. The pass is outside active presets

The current active Starshine optimize/shrink presets expand only to implemented hot/module passes.
`merge-locals` is not scheduled there, matching its removed registry status.

## Correct future port target

A future Starshine port should implement Binaryen's corrected source-backed model:

1. respect or deliberately document the named-local bailout policy
2. build or reuse local set/get influence facts
3. identify locals with exactly one set
4. reject candidates whose set has no value or a non-simple value
5. reject candidates whose influenced gets do not all trace back to the same set
6. reuse a small source-local chain when legal
7. otherwise create one fresh temp for the simple value
8. retarget influenced gets and remove redundant sets

The future port should **not** start from the stale 2026-04-23 `EquivalentCopies` / `LocalStructuralDominance` story.
That model is not source-backed for Binaryen `merge-locals` in the reviewed sources.

## Local implementation dependencies

A faithful implementation would need, at minimum:

- a local use/set influence representation similar in purpose to Binaryen `LocalGraph`
- a simple-expression predicate aligned with Binaryen's move-safety boundary
- local declaration insertion for fresh temps
- local.get / local.set index rewrite helpers
- validation after local rewrites
- tests around named locals if Starshine chooses to preserve Binaryen's bailout exactly

Neighboring local-cleanup dossiers remain the right context:

- [`../optimize-casts/index.md`](../optimize-casts/index.md)
- [`../local-subtyping/index.md`](../local-subtyping/index.md)
- [`../coalesce-locals/index.md`](../coalesce-locals/index.md)

But those neighbors should not be collapsed into one vague locals pass.

## Validation plan for the eventual port

1. Unit-style WAT tests for source-local reuse.
2. Unit-style WAT tests for fresh-temp materialization.
3. Branch / arity and DAG-like influence positives.
4. Loop-copy positives.
5. Extra-set negatives.
6. Non-simple value negatives.
7. Named-local bailout or a documented Starshine-specific alternative.
8. `bun fuzz compare-pass --pass merge-locals` or the repo-standard equivalent once the pass is runnable.
9. Cluster tests after neighboring removed passes become available.

## Bottom line

Starshine's current `merge-locals` strategy is honest non-implementation:

- tracked in the removed registry
- rejected on request
- documented with corrected Binaryen source strategy
- no owner file, no tests, and no active backlog slice yet

The source-correct future target is one-set local influence merging with optional fresh-temp materialization, not structural-dominance equivalent-copy grouping.
