---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../coalesce-locals/index.md
---

# Binaryen `merge-locals` strategy

## Source rule

Use Binaryen `version_129` plus the 2026-05-04 current-`main` recheck as the source oracle for this page.
The corrected source-backed owner surface is:

- `src/passes/MergeLocals.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/ir/local-graph.h`
- `test/lit/passes/merge-locals.wast`

The living dossier is about copy-shaped local traffic balancing, not one-set-local merging.
The earlier overread that centered `computeInfluences()`, one-set candidate discovery, and fresh-temp canonicalization is superseded for this pass.

## High-level intent

Binaryen uses `merge-locals` to reshape a local-copy pair so later cleanup has a simpler live-range story.
The pass starts from a `local.set $x (local.get $y)` copy shape, turns the copy into a synthetic `local.tee` candidate on the source side, then decides whether the influenced gets should be retargeted toward `$x` or toward `$y`.

That makes the pass a copy-oriented live-range tradeoff pass, not a general coalescer and not a generic local-value simplifier.

## Strategy table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Copy discovery | Find copy-shaped `local.set` / `local.get` pairs and instrument them with a trivial tee | Make the copy relationship explicit for graph analysis |
| Graph setup | Build an eager `LocalGraph` and compute set influences | Recover enough set/get flow to reason about the original and synthetic locals |
| Orientation test | Compare the original copy local and the synthetic tee local as retargeting targets | Choose the direction that preserves a clean single-set story |
| Safety gate | Require matching local types on influenced gets | Avoid rewiring a local into a type-incorrect context |
| Rollback | Rebuild a post-rewrite graph snapshot and undo bad candidates | Keep the pass conservative even though it mutates the function |
| Cleanup | Strip the trivial tee wrapper after successful rewrites | Leave behind the simplified copy shape |

## Phase 1: discover copy-shaped local traffic

The reviewed implementation does not begin from an abstract local-merging summary.
It begins by spotting actual copy-shaped `local.set` / `local.get` traffic.

The key transform is to expose the source side as a trivial `local.tee` candidate so the copy relation can be analyzed as a concrete graph object instead of as a speculative equivalence class.

## Phase 2: eager `LocalGraph` is the analysis engine

The pass constructs an eager `LocalGraph` and computes set influences.
That lets it ask a narrow question:

- which influenced gets can safely move to the original destination local?
- which influenced gets can safely move to the source local?

This is why the pass can reason through more than one adjacent copy without becoming a full dataflow optimizer.

## Phase 3: choose an orientation

For each candidate copy, Binaryen tries to prove one of two retargeting directions:

- **to the destination local:** influenced gets on the synthetic tee side are rewritten toward the original copy destination
- **to the source local:** influenced gets on the original copy side are rewritten toward the synthetic tee source

The pass is intentionally directional: it does not merely declare the two locals equivalent.
It chooses the orientation that still has a single-set story after graph checking.

## Phase 4: verify and roll back when needed

After the first rewrite, Binaryen rebuilds the graph and rechecks the candidate.
If the post-rewrite graph no longer supports the intended set relationships, the pass rolls the candidate back.

That rollback step is important: it keeps the pass conservative even though it is mutating local identity in place.

## Scheduler placement

`pass.cpp` inserts `merge-locals` only under stronger settings:

- `options.optimizeLevel >= 3`, or
- `options.shrinkLevel >= 2`

It sits after `heap2local` and before:

- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`

This explains why Starshine tracks it as saved-`-O4z` relevant but not part of the canonical no-DWARF `-O` / `-Os` path.

## What the pass does not do

Binaryen `merge-locals` does **not**:

- perform general liveness/interference slot coloring
- infer arbitrary local equivalence classes
- build a one-set-local / fresh-temp rewrite from scratch
- replace [`../coalesce-locals/index.md`](../coalesce-locals/index.md)

## Bottom line

Binaryen `merge-locals` is a copy-shape local-traffic balancing pass: it exposes a trivial tee, uses `LocalGraph` to decide whether the source or destination side should own the influenced gets, validates the choice with a post-rewrite graph, and then strips the temporary wrapper.
That is the source-correct model a future Starshine port should preserve.
