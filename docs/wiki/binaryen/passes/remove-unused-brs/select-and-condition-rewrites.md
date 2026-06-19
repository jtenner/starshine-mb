---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/perf_test.mbt
related:
  - ./pattern-catalog.md
  - ./tail-and-return-cleanups.md
  - ./returned-ladder-hot-shapes.md
  - ./parity.md
---

# `remove-unused-brs` Select And Condition Rewrites

## Scope

This page covers the parts of RUB that turn branch-shaped control into value selection:

- raw decision-ladder select formation
- direct value-`if` to `select`
- nested condition folding
- one-sided stack-tail select formation
- repeated branch-target equality ladders to `br_table`

The pass is intentionally conservative here. Most of the complexity is not "how to build `select`", but "when reordering is still correct".

## Raw Decision-Ladder Selects

### `run_hot_pipeline_raw_remove_unused_brs_rewrite_decision_ladder_instrs(...)`

Before lift, the pass manager looks for a very specific raw instruction pattern:

- `local.get`
- `i32.const`
- `i32.eq`
- `if(result i32)` whose arms are both single `i32.const`

That sequence is rewritten to raw `select` and can then skip HOT lift if no other HOT-only candidates remain.

The project keeps this raw rewrite because:

- it is cheap
- it is obviously local
- it cuts out lift cost for a known no-op family

## Direct Value-`if` To `select`

### `remove_unused_brs_try_rewrite_value_if_to_select(...)`

This is the main HOT `select` path.

The helper requires:

- a one-result `if`
- both arms to be buildable as value expressions
- the condition to be reorder-safe, or at least safe over the value-arm local-read surface
- for direct `selectify` candidates, the Binaryen-shaped unconditionalization cost threshold for the current shrink level

The pass supports more than trivial const arms. Current regressions cover:

- pure const arms
- local.get arms
- i64 result arms
- conditions containing `local.tee`
- conditions involving calls when the ordering is still known to be safe
- returned condition ladders with side-effect prefixes
- costly integer `div`/`rem` arms staying as `if` at speed shrink level and becoming `select` under `shrink_level=1` when the cost threshold allows it

The crucial helper pair is:

- `remove_unused_brs_build_region_value_expr(...)`
- `remove_unused_brs_condition_is_select_safe_over_value_arms(...)`

That pair is what keeps "selectify" from silently reordering side effects or local traffic.

## Condition-Child Value-`if` Rewrites

### `remove_unused_brs_try_rewrite_condition_child_value_if_to_select(...)`

This helper exists because some functions do not present the interesting value-`if` as a direct result node.

- Instead, a void outer `if` uses a one-result inner `if` as its condition.
- The pass first selectifies the condition child.
- Only then do later branch cleanups or suffix rewrites become visible.

This helper is also the reason some returned ladders cannot use the raw structured-return skip.

The perf coverage explicitly checks that structured returned ladders still lift when this helper is needed.

## Nested Condition Merging

### `remove_unused_brs_try_merge_nested_if_conditions(...)`

This helper merges:

- an outer one-armed void `if`
- whose then arm is another one-armed void `if`

into a single condition path.

The replacement is not a textual conjunction helper. The pass builds an internal value form that preserves ordering and lets a later `br_if` rewrite finish the cleanup.

This is why the relevant regressions talk about:

- nested one-armed condition merges
- else-if ladders with embedded value-`if` conditions

instead of "just flatten nested `if`".

## `br_if` Equality Ladders To `br_table`

### `remove_unused_brs_try_rewrite_br_if_eq_ladder_to_br_table(...)`

This is the pass's dedicated branch-table formation rule.

It requires:

- a run of at least three consecutive `br_if`
- all branches target the same label
- each condition is `i32.eq(selector, const)` or `i32.eq(const, selector)`
- the selector is the same local-get or local-tee surface
- constant values stay in the small supported range

The rewrite builds:

- an inner block with a fresh label
- a `br_table` whose default target is that inner label
- entries for each matched constant that jump to the original branch target

This is intentionally narrower than "any chain of branch comparisons". The pass only models the straightforward ladder it can prove cheaply.

## One-Sided Stack-Tail `select`

### `remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(...)`

This helper handles a shape Binaryen reaches late:

- a tail one-result `if`
- one arm exits via removable stack-style branch or return
- the other arm already yields a direct value expression

The pass builds the missing value expression from the exit arm by replaying the stack payload roots, then forms a `select`.

This is the current source of:

- `rewrites one-sided stack-style tail branch ifs into select`
- `rewrites one-sided tail return ifs into select`

## Block-Carried Payload Selection

### `remove_unused_brs_try_rewrite_tail_value_if_simple_payload_arm(...)`

This helper is related but not identical to the one-sided tail rule.

- It only runs in one-result regions.
- It needs an earlier region prefix that can be wrapped into a new block.
- It treats the simple branch arm as a block-exit payload producer.

This is the route by which some block-carried one-arm payload families become a value-producing `if` instead of staying as explicit branch carriers.

## Why Select Formation Is So Guarded

The pass's select rules are conservative because the failures are easy to hide:

- reordering a condition past a side effect can stay type-correct while still being wrong
- local-read interactions around `local.tee` can appear safe in printed WAT and still be wrong in HOT order
- returned ladders may need to stay typed until another helper strips the surrounding return context

That is why the select helpers are scattered through the traversal rather than centralized in one "selectify everything" phase.

Binaryen also exposes `remove-unused-brs-never-unconditionalize` to disable rewrites that would execute a condition or hinted branch body unconditionally. Starshine does not currently expose a `--pass-arg`/pass-option equivalent, and it has no expression-level branch-hint metadata representation to protect. Until both surfaces exist, these rewrites are documented as ordinary direct-pass behavior rather than as configurable never-unconditionalize parity.

## Practical Rule

- If the family is already a direct one-result `if`, start with the direct select helper.
- If the family only becomes value-like after peeling branch exits or returned wrappers, it probably belongs to another helper first.
- Never widen the select rules without re-checking:
  - reorder-safety
  - local-read interaction
  - returned-ladder regressions
  - branch-payload arity constraints

