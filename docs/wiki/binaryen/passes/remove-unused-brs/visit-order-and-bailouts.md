---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/perf_test.mbt
related:
  - ./index.md
  - ./pattern-catalog.md
  - ./starshine-hot-ir-strategy.md
  - ./returned-ladder-hot-shapes.md
  - ./parity.md
---

# `remove-unused-brs` Visit Order And Bailouts

## Why This Page Exists

- RUB is not just a list of rewrites.
- Its execution model is part of its correctness and performance contract.
- Several of the hardest historical regressions came from changing discovery order or widening the scan surface, not from building the wrong replacement node.

## Raw Skip Reasons

The raw pre-lift layer can return early with one of these reasons:

- `decision-ladder-selects`
  a raw decision ladder was rewritten to `select`, and no HOT-only candidates remain
- `structured-return-ladder-noop`
  a structured returned-ladder family is recognized as no-op unless a HOT-only carried-guard or condition-child family is also present
- `unique-loop-select-return-ladder-noop`
  a narrower loop/select returned family is recognized as no-op
- `no-remove-unused-brs-candidates`
  the original instruction tree does not contain any RUB-relevant control surface

The perf tests explicitly lock in both the skip reason and the absence of lift/pass timers where appropriate.

## HOT Skip Reasons

After lift, the pass still has hot-only bailouts:

- `large-void-if-return-ladder-noop`
- `nested-constructor-return-ladder-noop`

Those skips exist because some giant lifted families were repeatedly proven to be semantically unchanged while still costing a lot to traverse.

The hot skip is shape-based, not name-based.

- it counts calls, locals, `if`, `return`, `select`, `br_if`, blocks, loops, and plain `br`
- it matches against specific wide-ladder or constructor-ladder signatures

The relevant perf tests prove that these families still pay lift cost but skip the expensive rewrite walk.

## Region-First Traversal

`remove_unused_brs_visit_region(...)` does not start by descending into each root's full subtree.

Instead, it first checks root-local patterns in this rough order:

- `br_if` equality ladder to `br_table`
- block-root cleanup (`sink_if_arm_self_branch_block`, `inline_single_br_if_block`, `block_prefix_payload_branch_root`, `rotate_void_block_single_loop`)
- dropped result-block cleanup
- outer `br` payload cleanup
- region-level `if` cleanup
- local-set arm cleanup

Only after those direct opportunities are exhausted does the pass call `remove_unused_brs_visit_node(...)` on the surviving root.

That ordering is essential:

- root-local rewrites often expose cheaper inner shapes
- descending first would force the pass to rediscover the same structural cleanup in a more expensive context

## Seen Masks Instead Of A Plain Visited Set

The pass records three visitation modes in `seen`:

- plain
- payload-context
- return-context

This matters because:

- a node already visited in plain mode may still need a payload-sensitive rewrite later
- a node already visited in payload mode may still need a return-context rewrite later

Any future simplification of the seen mask needs to prove it does not suppress legal revisits.

## Cheap Caches And Expensive Analyses

The pass recomputes several cheap caches every fixpoint cycle:

- label refs
- branch payload children
- embedded control
- subtree returns
- reorder safety cache

It only computes the expensive `use-def` analysis on demand for exit-only value-`if` voidification.

There is a dedicated perf regression proving that simple tail-return cleanup does not accidentally build `use-def`.

## Mutation Churn Control

- The fixpoint is capped at eight cycles.
- The perf test `remove-unused-brs trims one mutation step from tail branch payload if cleanup` explicitly watches mutation churn in one cleanup family.
- This is not cosmetic.
- Several historical parity slices were "correct enough" locally but mutated too many times on the real artifact and blew the pass budget.

## Returned-Ladder Bailout Interaction

The returned-ladder raw skips are not absolute.

The raw layer intentionally cancels the skip when it detects HOT-only families such as:

- condition-child value-`if`
- prefix guard payload branch candidates

That is why the perf tests include both:

- functions that should skip
- structurally similar returned ladders that must still lift and rewrite

## Debugging Rule

When a new parity mismatch shows up, use the trace and bailout surfaces to answer these first:

1. Did the raw layer skip, rewrite, or lift?
2. Did the HOT layer report a skip reason?
3. Did RUB report any mutation at all?
4. Was the family blocked by label refs, branch-payload-child marking, or reorder safety?

If those answers are missing, the next code change is probably premature.

## Practical Rule

- Treat execution order, skip heuristics, and mutation count as part of the pass contract.
- Do not collapse raw and HOT behavior into one conceptual bucket when documenting or debugging the pass.
- If a new matcher only works after widening the scan surface substantially, add the proof that it belongs in the current visit order and does not just bypass the bailout design.

