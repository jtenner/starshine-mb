---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/ir/hot_lower_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ../simplify-locals/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
---

# Starshine HOT-IR Strategy For `merge-blocks`

Use this page with the corrected Binaryen source manifest in [`../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md).

The goal here is not to restate upstream Binaryen. It is to show exactly where current MoonBit behavior lives and how the HOT-level strategy differs from Binaryen's named-block retargeting pass.

## Corrected Binaryen contrast

The 2026-04-25 source correction matters for the local strategy too.

Upstream Binaryen is not a tail-child-only unnamed-wrapper pass. It is a named-block deblocking pass with:

- function-wide ambiguity prescan;
- recursive branch-user retargeting proof;
- block, `if`, and terminal-expression visitors;
- effect barriers and refinalization.

Current Starshine intentionally does something else:

- it does **not** retarget branch names;
- it refuses every block whose label is referenced anywhere in the function;
- it can flatten unlabeled branch-free HOT region-root blocks that Binaryen's named-block AST pass would not treat as the same positive family;
- it adds typed-carrier and dead-`unreachable` suffix repairs that are specific to local HOT lowering/writeback.

So the right comparison is “same cleanup family, different proof obligations,” not “Starshine copied `MergeBlocks.cpp`.”

## Exact local code map

The fastest read-along path through the current Starshine implementation is:

| Lines | Surface | Role |
| --- | --- | --- |
| `src/passes/merge_blocks.mbt:2-17` | `merge_blocks_descriptor()` | Active HOT descriptor and invalidated analyses. |
| `src/passes/merge_blocks.mbt:20-31` | `merge_blocks_has_candidate(...)` | Cheap live-`Block` scan before deeper work. |
| `src/passes/merge_blocks.mbt:34-80` | `merge_blocks_compute_label_used(...)` | Whole-function label-use scan across `br`, `br_if`, `br_table`, `delegate`, `br_on_*`, and `try_table` catch targets. |
| `src/passes/merge_blocks.mbt:85-90` | `merge_blocks_label_is_used(...)` | Hard bailout for live labels. |
| `src/passes/merge_blocks.mbt:93-136` | region and typed-block helpers | Region root collection and block-param counting through `HotModuleContext`. |
| `src/passes/merge_blocks.mbt:141-184` | `merge_blocks_rewrite_dead_unreachable_suffix_roots(...)` | Preserves dead value roots before `unreachable` as explicit `drop`s. |
| `src/passes/merge_blocks.mbt:187-284` | `merge_blocks_visit_control_node(...)` | Recurses through block, loop, if, try, and try-table regions. |
| `src/passes/merge_blocks.mbt:287-333` | `merge_blocks_flatten_region_root_block(...)` | Main HOT root-block splice helper. |
| `src/passes/merge_blocks.mbt:336-366` | `merge_blocks_visit_region(...)` | Region traversal and repeated flattening. |
| `src/passes/merge_blocks.mbt:369-386` | `merge_blocks_run(...)` | Entry point, use-def construction, mutation marking, changed/unchanged result. |
| `src/passes/optimize.mbt:232-234` | registry entry | Active hot-pass registration. |
| `src/passes/optimize.mbt:255-268` and `394-408` | preset arrays | Repeated late `merge-blocks` placement in `optimize` and `shrink`. |
| `src/passes/pass_manager.mbt:7813` and `8704` | manager/dispatcher | Trace integration and call to `merge_blocks_run(ctx, func)`. |

## What Starshine is optimizing

Current Starshine `merge-blocks` flattens branch-free HOT region-root `Block` nodes.

That means it is looking for HOT-region shapes like:

```text
parent region roots:
  ...
  Block(label unused, body=[a, b, c])
  ...
```

and rewriting them into:

```text
parent region roots:
  ...
  a
  b
  c
  ...
```

only when local guards preserve label, typed-carrier, and writeback behavior.

The public summary in `merge_blocks_summary()` remains accurate:

- “Flatten branch-free block roots into their parent regions to expose later branch cleanup.”

## High-level local algorithm

1. `merge_blocks_has_candidate(...)` bails out if the function has no live `Block` nodes.
2. `merge_blocks_compute_label_used(...)` marks every label targeted by all HOT branch/catch surfaces.
3. `merge_blocks_visit_region(...)` walks root and nested regions.
4. `merge_blocks_visit_control_node(...)` descends through block, loop, `if`, `try`, and `try_table` bodies.
5. `merge_blocks_flatten_region_root_block(...)` attempts a root-level splice.
6. `merge_blocks_rewrite_dead_unreachable_suffix_roots(...)` repairs dead values before `unreachable` before a successful splice.
7. `merge_blocks_run(...)` marks the function mutated only after a real change.

## Main local guards

### 1. Referenced labels block flattening entirely

If `merge_blocks_label_is_used(...)` says the block label is referenced anywhere in the function, Starshine keeps the block.

This is the local replacement for Binaryen's harder name-retargeting proof:

- no branch-target rewrite step;
- no same-name ambiguity problem;
- no Binaryen-style `ProblemFinder` clone;
- no named-child effect-invalidates gate.

### 2. Typed block params are flattened only in carrier-safe cases

`merge_blocks_block_param_count(...)` resolves block/loop type params through the module context. `merge_blocks_flatten_region_root_block(...)` then allows flattening only when the local typed-carrier rules can remain Binaryen-stable.

The simplified rule is:

- no block params: ordinary flattening can proceed;
- one-param child under an enclosing param-carrying control: allowed;
- multi-param zero-result child under a loop: allowed for the local loop-carrier collapse family;
- other param-carrying cases: keep the wrapper.

### 3. Dead values before `unreachable` become explicit drops

When a flattened body has value roots before an `unreachable`, Starshine cannot silently lose those roots. It rewrites them to explicit `drop`s first.

That repair is local to Starshine's HOT writeback stability. It is not a direct Binaryen `MergeBlocks.cpp` behavior, but it is required for the current local pass to keep Binaryen-stable output.

### 4. Loops get special carrier treatment

The local pass distinguishes loops because some branch-free typed loop carriers can collapse more aggressively than ordinary block carriers.

The focused tests cover:

- single-param loop carriers;
- multi-result loop carriers;
- externref and funcref loop carriers;
- branch-free void loop carrier deletion;
- result-only loop rewrites for some multi-result families.

## Current scheduler role

`src/passes/optimize.mbt` schedules `merge-blocks` twice in both public presets. The late cleanup neighborhood is:

- `heap2local`
- `simplify-locals`
- `merge-blocks`
- `remove-unused-brs`
- `remove-unused-names`
- `merge-blocks`
- `precompute`
- `optimize-instructions`
- `heap-store-optimization`

This mirrors the structural strategy:

- `simplify-locals` and neighboring passes create wrappers and typed carriers;
- the first `merge-blocks` removes easy structural wrappers;
- branch/name cleanup exposes more opportunities;
- the second `merge-blocks` catches newly branch-free wrappers.

## What the current Starshine pass does not do

The active HOT pass does **not** currently:

- port Binaryen's recursive branch-name retargeting proof;
- change branch targets from child labels to parent labels;
- flatten blocks whose labels are still live;
- use Binaryen's effect-analysis invalidation proof;
- implement Binaryen's `if`-arm named-block cleanup as a direct AST transform;
- implement Binaryen's terminal wrapper-name cleanup as a direct AST transform;
- replace `remove-unused-brs`, `remove-unused-names`, or `flatten`.

## Validation and evidence surfaces

Fastest proof path:

- `src/passes/merge_blocks_test.mbt:21-1709`
  - direct flattening positives, live-label negatives, typed carrier matrix, dead-`unreachable` repair, externref/funcref/multi-result cases.
- `src/passes/optimize_test.mbt:340-447`
  - repeated preset-slot exposure and `simplify-locals -> merge-blocks` handoff.
- `src/passes/registry_test.mbt:48` and `135-159`
  - active hot-pass category, descriptor, and preset expansion coverage.
- `src/cmd/cmd_wbtest.mbt:1959-1993`
  - direct `--merge-blocks` CLI surface.
- `src/ir/hot_lower_test.mbt:1861-2506`
  - neighboring lower/writeback tests for Binaryen-stable typed carrier output.

## Bottom line

Current Starshine `merge-blocks` is a real implemented hot pass, but it is intentionally not Binaryen's named-block retargeting engine.

Its practical contract is:

- flatten branch-free region-root blocks;
- preserve live labels by refusing them;
- preserve typed carrier legality with explicit param-count and loop/result guards;
- preserve dead-before-`unreachable` value work by materializing `drop`s;
- run twice late so neighboring cleanup passes can expose new easy merges.

## Sources

- [`../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md)
- [`../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md`](../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
