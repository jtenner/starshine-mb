---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_test.mbt
related:
  - ./index.md
  - ./pattern-catalog.md
  - ./tail-and-return-cleanups.md
  - ./select-and-condition-rewrites.md
  - ./branch-exit-and-payload-rewrites.md
  - ./carried-guards-and-result-blocks.md
  - ./visit-order-and-bailouts.md
  - ./parity.md
---

# Starshine HOT-IR Strategy For `remove-unused-brs`

## Two-Layer Architecture

- Starshine does not run RUB as one monolithic lifted rewrite.
- The current implementation has two distinct layers:
  - a raw pre-lift path in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - the real HOT pass in [`../../../../../src/passes/remove_unused_brs.mbt`](../../../../../src/passes/remove_unused_brs.mbt)
- That split is deliberate.
- The raw layer exists so obvious no-op families and one cheap decision-ladder normalization can avoid HOT lift entirely.
- The HOT layer exists because the real branch-shape work needs explicit labels, holders, region APIs, and on-demand analyses that only make sense after lift.

## Raw Pre-Lift Layer

The raw layer does three kinds of work:

- Candidate detection.
  It checks whether the original instruction tree even contains `nop`, `if`, `br`, `br_if`, `br_table`, or `return` surfaces worth considering.
- A narrow raw normalization.
  `run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(...)` rewrites a cheap `local.get` / `i32.eq const` / `if(result i32)` chain into a raw `select` when that lets the function skip lift cleanly.
- Skip decisions.
  The raw layer recognizes several families where lifting used to cost a lot while doing no useful work:
  - `decision-ladder-selects`
  - `structured-return-ladder-noop`
  - `unique-loop-select-return-ladder-noop`
  - `no-remove-unused-brs-candidates`

The raw layer is not trying to re-implement the whole pass.

- It only handles the parts that are:
  - obviously local in raw WAT form
  - cheap to prove correct without HOT analyses
  - known from perf history to be worth skipping

## HOT Fixpoint Layer

- The HOT layer is `remove_unused_brs_run(...)`.
- It runs a bounded fixpoint:
  - recompute analysis scaffolding
  - walk the root region
  - apply structural rewrites
  - repeat up to eight cycles while mutations keep happening
- Each cycle rebuilds:
  - label reference counts
  - branch-payload-child marks
  - reorder-safety cache
  - embedded-control cache
  - subtree-return cache

That reset-per-cycle approach matters because many rewrites change:

- which labels are still referenced
- which blocks are now branch-payload carriers
- whether a region tail is still removable
- whether a subtree still contains explicit `Return`

## Context Tracking

The HOT visitor tracks more than just the current node.

- `payload_context`
  means "the current subtree feeds a branch payload or equivalent preserved carrier path".
- `return_context`
  means "the current subtree is in a position where stripping or rewriting return-shaped control is legal and useful".
- `seen`
  is not a plain visited set. It records which node has already been visited in:
  - plain mode
  - payload mode
  - return mode

That detail matters because the same node may be safe to revisit under a stronger context even if it was already seen in a weaker one.

## Traversal Order

- `remove_unused_brs_visit_region(...)` first checks region-root patterns that are best recognized before descending:
  - `br_if` equality ladders to `br_table`
  - block-root self-branch sinking
  - inline single-`br_if` wrapper blocks
  - block-prefix payload-branch roots
  - loop-wrapper rotation
  - region-level `if` rewrites
  - local-set arm rewrites
- Only after those region-root opportunities are exhausted does the visitor descend into node-specific logic.

That ordering is one of the main reasons the docs treat RUB as a structured optimizer rather than a post-order peephole pass.

## Why So Many Guards Exist

Several guards recur across the implementation:

- Label-reference checks.
  A transformation usually refuses to touch a control node if its label is still referenced somewhere else.
- Branch-arity checks.
  Multi-value payload rewrites are only legal when the surviving payload side still supplies the exact arity the destination label expects.
- Reorder-safety checks.
  `select` formation is intentionally narrow. The pass only reorders conditions or value arms when the involved nodes are known to be safe, or when the condition is proven safe over the value-arm local-read surface.
- Branch-payload-child checks.
  Some result blocks are themselves payload carriers for another branch. Those wrappers cannot always be simplified immediately without breaking later structure.
- On-demand `use-def`.
  The pass only builds `use-def` when it must prove the single-use exit-only chain for `remove_unused_brs_try_voidify_exit_only_value_if(...)`.

## Why This Pass Is Still HOT-IR Work

- The current in-tree strategy depends heavily on HOT-only concepts:
  - holder blocks
  - region references
  - branch target labels
  - result arity queries
  - replacing a control node with a demoted block
  - splicing region roots while preserving detached-child cleanup
- The raw path is an optimization layer, not the real home of the pass.
- Any future RUB work that matters for artifact parity still needs to fit the HOT traversal and fixpoint model.

## Where Starshine Intentionally Differs From A Naive Port

- Starshine already includes targeted raw and hot bailouts that Binaryen itself does not need in the same way.
- Those are not accidental hacks. They are the current cost-control contract for the MoonBit debug artifact.
- The pass also distinguishes several HOT-only carrier families that do not appear as obviously in printed WAT:
  - returned ladders through explicit `Return`
  - prefix-guard payload result blocks
  - dropped carried wrappers
  - self-target arm-local block cleanup

## Current Maintenance Rule

- Keep the two-layer design.
- Add raw rewrites only when the family is obviously cheap and lift avoidance is the main win.
- Add HOT rewrites only when the structural guard is narrow enough to preserve current perf behavior and existing returned-ladder regressions.
- When a new helper needs broad nested discovery, assume the strategy is wrong until the cost model is proven.

