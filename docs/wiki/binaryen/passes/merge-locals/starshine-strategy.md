---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md
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

A future Starshine port should implement Binaryen's corrected copy-shape model:

1. detect copy-shaped `local.set` / `local.get` pairs
2. expose the copy with a trivial tee on the source side
3. build or reuse a local set-influence graph equivalent to Binaryen's `LocalGraph`
4. decide whether the source local or destination local should own the influenced gets
5. require matching local types on the affected gets
6. recheck the rewrite after mutation and roll back bad candidates
7. strip the temporary tee wrapper after success

The future port should **not** start from the stale one-set-local / fresh-temp story.
That model is not source-backed for Binaryen `merge-locals` in the reviewed sources.

## Local implementation dependencies

A faithful implementation would need, at minimum:

- a local copy-shape detector for `local.set` fed by `local.get`
- a local set-influence representation similar in purpose to Binaryen `LocalGraph`
- a post-rewrite verification pass or rollback guard
- local.get / local.set index rewrite helpers
- local tee insertion / cleanup helpers
- validation after local rewrites
- tests around type mismatch and rollback behavior

Neighboring local-cleanup dossiers remain the right context:

- [`../optimize-casts/index.md`](../optimize-casts/index.md)
- [`../local-subtyping/index.md`](../local-subtyping/index.md)
- [`../coalesce-locals/index.md`](../coalesce-locals/index.md)

But those neighbors should not be collapsed into one vague locals pass.

## Validation plan for the eventual port

1. Unit-style WAT tests for source-to-destination retargeting.
2. Unit-style WAT tests for destination-to-source retargeting.
3. Type-mismatch and rollback negatives.
4. Conservative `between-unreachable` regression.
5. `bun fuzz compare-pass --pass merge-locals` or the repo-standard equivalent once the pass is runnable.
6. Cluster tests after neighboring removed passes become available.

## Bottom line

Starshine's current `merge-locals` strategy is honest non-implementation:

- tracked in the removed registry
- rejected on request
- documented with the corrected Binaryen copy-shape strategy
- no owner file, no tests, and no active backlog slice yet

The source-correct future target is copy-shape local traffic balancing with `LocalGraph`-checked orientation and rollback, not one-set merging.
