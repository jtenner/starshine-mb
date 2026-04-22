---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/ir/hot_lower_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
---

# Starshine HOT-IR Strategy For `merge-blocks`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md`](../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show exactly where the current MoonBit implementation lives and how its HOT-level strategy differs from the upstream AST pass.

## Exact local code map

The fastest read-along path through the current Starshine implementation is:

- registry descriptor, summary, preset slots, and public status
  - `src/passes/merge_blocks.mbt`
    - `merge_blocks_descriptor()`
    - `merge_blocks_summary()`
    - `merge_blocks_run(...)`
  - `src/passes/optimize.mbt`
    - active hot-pass registration for `merge-blocks`
    - repeated `optimize` / `shrink` preset placement in the late cleanup cluster
- main HOT rewrite logic in `src/passes/merge_blocks.mbt`
  - `merge_blocks_has_candidate(...)`
  - `merge_blocks_compute_label_used(...)`
  - `merge_blocks_flatten_region_root_block(...)`
  - `merge_blocks_visit_region(...)`
  - `merge_blocks_visit_control_node(...)`
  - `merge_blocks_rewrite_dead_unreachable_suffix_roots(...)`
  - typed-carrier helpers
    - `merge_blocks_control_block_type(...)`
    - `merge_blocks_block_param_count(...)`
    - `merge_blocks_block_has_params(...)`
- representative local evidence surfaces
  - `src/passes/merge_blocks_test.mbt` for direct rewrite legality and Binaryen-stable typed-carrier coverage
  - `src/passes/optimize_test.mbt` for repeated preset-slot exposure and the `heap2local -> simplify-locals -> merge-blocks` handoff
  - `src/passes/registry_test.mbt` for hot-pass category / descriptor coverage
  - `src/cmd/cmd_wbtest.mbt` for direct `--merge-blocks` CLI coverage
  - `src/ir/hot_lower_test.mbt` for the neighboring lower/writeback shapes that explicitly cite “merge-blocks wants Binaryen-stable output”

That exact code map is the main practical addition in this follow-up: readers can now jump directly from the strategy summary to the owning files and helper clusters.

## What Starshine is optimizing

Current Starshine `merge-blocks` is an active HOT pass whose purpose is:

- flatten branch-free block roots out of parent HOT regions
- expose cleaner shapes for later `remove-unused-brs`, `remove-unused-names`, and `precompute` work
- keep typed block/loop lowering Binaryen-stable when HOT writeback has to re-materialize block params or loop carriers

The public summary in `merge_blocks_summary()` is accurate and deliberately narrower than the pass name sounds:

- “Flatten branch-free block roots into their parent regions to expose later branch cleanup.”

That wording matters.
Current Starshine is not trying to port every AST-level same-name branch retargeting case from upstream Binaryen.
It is doing a HOT-region-root cleanup that matches the current local IR and lowering boundaries.

## High-level local algorithm

The actual HOT pass runs in this shape:

1. Cheap candidate gate
   - `merge_blocks_has_candidate(...)` bails out unless the function has at least one live `Block` node.
2. Whole-function label-use scan
   - `merge_blocks_compute_label_used(...)` records every label targeted by `br`, `br_if`, `br_table`, `delegate`, `br_on_*`, and `try_table` catch arms.
3. Recursive control-region walk
   - `merge_blocks_visit_region(...)` and `merge_blocks_visit_control_node(...)` recurse through root, block, loop, `if`, `try`, and `try_table` regions.
4. Root-block flattening attempts
   - `merge_blocks_flatten_region_root_block(...)` checks one region root at a time and splices the block body into the parent region when the local guards pass.
5. Changed-function marking
   - `merge_blocks_run(...)` calls `pass_mark_mutated(ctx, func)` only after a real region splice succeeds.

So the local pass is fundamentally a region-splice pass over HOT roots, not a tail-child AST pass.

## The most important local guards

### 1. Referenced labels block flattening entirely

The strongest local guard is simple:

- if a block's label is referenced anywhere in the function, Starshine keeps the block

That happens in `merge_blocks_flatten_region_root_block(...)` via `merge_blocks_label_is_used(...)`.

This is the biggest difference from Binaryen's same-name-child strategy.
Instead of trying to retarget some branches safely, the current HOT pass just refuses any block whose label is still semantically live.

That makes the local proof easier:

- no branch-target rewrite step
- no same-name ambiguity problem
- no need for Binaryen's `ProblemFinder`
- no need for a named-child effect-invalidates gate

### 2. Typed block params are flattened only in narrow carrier-safe cases

The second major guard is typed-carrier aware.

`merge_blocks_block_param_count(...)` resolves how many params a block/loop type carries.
`merge_blocks_flatten_region_root_block(...)` then allows flattening only when one of these is true:

- the block has no params, or
- the enclosing control also has params and the child has exactly one param, or
- the enclosing control is a loop and the child is a multi-param zero-result carrier the local lowering can safely collapse

This is why so many local tests mention “Binaryen-stable” typed block and loop lowering.
The pass is not only deleting wrappers.
It is also preserving the exact carrier shapes that HOT lower/writeback expects to roundtrip cleanly.

### 3. Dead values before `unreachable` are rewritten to explicit drops first

`merge_blocks_rewrite_dead_unreachable_suffix_roots(...)` handles the subtle local case where a flattened block body contains dead value roots before an `unreachable` tail.

Instead of dropping those values accidentally during the splice, Starshine rewrites them into explicit `drop`s before moving the `unreachable` root.

That makes the local contract easy to teach:

- flattening can reorder dead suffix representation
- but it must not silently erase side-effect-free value production that still needs an explicit drop in Binaryen-stable output

### 4. Loops are treated specially because some branch-free loop carriers can disappear entirely

The local pass distinguishes ordinary control from loops via `enclosing_control_is_loop`.
That matters because some branch-free typed loop carriers are safe to collapse much more aggressively than ordinary block carriers.

You can see that directly in the tests:

- some typed loop cases keep the loop
- some branch-free typed void loop carriers disappear entirely
- some multi-result loop families are rewritten into result-only loop forms instead of preserving the original carrier block shape

Those tests are the clearest proof that the local pass is tuned to HOT lower/writeback behavior, not just source-tree simplification aesthetics.

## Relation to upstream Binaryen

The correct comparison is:

- same optimization family
- different proof obligations

### Upstream Binaryen

Binaryen's `MergeBlocks.cpp` works on AST blocks and can accept:

- unnamed tail child merges
- some same-name tail child merges

It therefore needs:

- a whole-function `ProblemFinder` shadow-hazard prescan
- child-name gating
- an effect-invalidates barrier for named children
- post-splice `ReFinalize`

### Current Starshine

Starshine works on lifted HOT regions and therefore chooses a different contract:

- flatten region-root blocks, not only parent-tail child blocks
- refuse all blocks whose labels are still referenced
- encode typed-carrier legality directly in param-count and loop/result guards
- repair dead-unreachable suffix values explicitly before the splice
- rely on HOT mutation APIs plus later writeback rather than Binaryen's AST refinalizer

So Starshine is currently narrower than Binaryen on named-branch retargeting, but broader on where the flatten can happen structurally because HOT regions make root splicing cheaper to prove.

## Current scheduler role in Starshine

`src/passes/optimize.mbt` schedules `merge-blocks` twice in both public presets.
The immediate late-cluster neighborhood is:

- `heap2local`
- `simplify-locals`
- `merge-blocks`
- `remove-unused-brs`
- `remove-unused-names`
- `merge-blocks`
- `precompute`
- `optimize-instructions`
- `heap-store-optimization`

The important local lesson is the same one Binaryen teaches, but through different code:

- `simplify-locals` and neighboring passes create wrapper blocks and typed carriers
- the first `merge-blocks` pass removes the easy structural wrappers
- `remove-unused-brs` and `remove-unused-names` expose more follow-up simplifications
- the second `merge-blocks` pass catches the newly exposed branch-free wrappers

`src/passes/optimize_test.mbt` locks down that repeated scheduling and the direct `simplify-locals -> merge-blocks` handoff.

## What the current Starshine pass does not do

A future port should avoid overstating the current implementation.
The active HOT pass does **not** currently:

- port Binaryen's same-name branch-retargeting path
- attempt general arbitrary-label rewrite
- flatten blocks whose labels are still live
- use an effect-analysis invalidation proof like Binaryen's named-child gate
- stand alone as a general structural cleanup replacement for `remove-unused-brs` or `remove-unused-names`

That is why the local dossier should be read as “active HOT-region-root subset with Binaryen-stable typed-carrier work,” not “feature-complete direct clone of `MergeBlocks.cpp`.”

## Validation and evidence surfaces

If you need the fastest proof path, read these in order:

- `src/passes/merge_blocks_test.mbt`
  - direct flattening positives
  - incoming-branch negatives
  - typed block and loop carrier positives / negatives
  - dead-value-before-`unreachable` preservation
  - multi-result, externref, and funcref lowering families
- `src/passes/optimize_test.mbt`
  - repeated preset-slot exposure
  - `heap2local -> simplify-locals -> merge-blocks` adjacency
- `src/passes/registry_test.mbt`
  - hot-pass category and descriptor status
- `src/cmd/cmd_wbtest.mbt`
  - `--merge-blocks` CLI surface
- `src/ir/hot_lower_test.mbt`
  - the neighboring lower/writeback expectations that explicitly frame some shapes as “merge-blocks wants Binaryen-stable output”

## Bottom line

Current Starshine `merge-blocks` is already a real implemented hot pass.
Its practical contract is:

- flatten branch-free region-root blocks
- preserve live labels by refusing them
- preserve typed carrier legality with explicit param-count and loop/result guards
- preserve dead-before-`unreachable` value work by materializing `drop`s before flattening
- run twice late so neighboring cleanup passes can expose new easy merges

That is the right mental model to carry into future parity or porting work.
