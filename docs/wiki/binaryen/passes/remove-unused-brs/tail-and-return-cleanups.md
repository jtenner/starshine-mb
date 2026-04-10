---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
related:
  - ./pattern-catalog.md
  - ./returned-ladder-hot-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
---

# `remove-unused-brs` Tail And Return Cleanups

## Scope

This page covers the helpers whose primary job is to delete or demote exit traffic that already flows to the enclosing continuation:

- direct tail `br` / `return` stripping
- duplicated tail exits under `if`
- return-context cleanup
- tail-return voidification
- exit-only value-`if` voidification
- trailing `nop` trimming

These are the oldest and most fundamental RUB behaviors, but even here the current tree is more structured than "drop the last branch if it looks redundant".

## Core Target Model

Several helpers rely on the same target abstraction:

- `ReturnTarget`
  means the enclosing continuation is the function return itself.
- `BranchTarget(label)`
  means the enclosing continuation is a holder-block label.
- `NoTarget`
  means the current region does not have a removable continuation.

The helpers that matter most here are:

- `remove_unused_brs_tail_target(...)`
- `remove_unused_brs_region_enclosing_branch_target(...)`
- `remove_unused_brs_region_tail_control_payload_count(...)`

The last one is especially important in multi-value cases because it prevents "remove the exit" from accidentally changing payload arity.

## Direct Tail Stripping

### `remove_unused_brs_try_remove_region_tail(...)`

This helper is the direct tail-stripper.

- It only runs when the current region has a removable enclosing continuation.
- It accepts either:
  - a `return`
  - a `br` to the enclosing holder
- It handles three output forms:
  - delete the tail entirely when no payload exists
  - replace the tail with its single child when a one-value payload already computes the right result
  - splice multiple payload children into the region when the exit is only carrying stacked values

The focused direct regressions are:

- `removes trailing branch to the enclosing block`
- `removes trailing return at function exit`
- `removes trailing multi-value branch to the enclosing block`
- `removes trailing multi-value return at function exit`

The important legality boundary is that a zero-result region does not get to silently inherit payload-bearing `br` children.

## Duplicated Tail Exits Under `if`

### `remove_unused_brs_try_strip_tail_if_exits(...)`

This helper handles the case where the tail of a region is itself an `if`, and both arms already end in the same removable exit.

- It computes the expected payload arity from the `if` result.
- It proves that both arms end in the same `ReturnTarget` or `BranchTarget`.
- It strips the duplicated exits from both arms.
- It then trims newly exposed trailing `nop` roots.

This is not the same as `if -> br_if`.

- The control node stays an `if`.
- The simplification is "both arms already perform the same terminal exit, so keep the payload-producing work and drop the duplicate exit shell".

## Return-Context Tail Stripping

### `remove_unused_brs_try_strip_return_context_tail(...)`

This helper is narrower than the direct tail stripper.

- It only runs in explicit return context.
- It checks that the trailing `return` payload count exactly matches the enclosing region result arity.
- It then uses the same tail-control stripping machinery to remove the redundant `return`.

This matters most for returned ladders and nested returned loops, where the visible region tail is a `return` but the actual value work already matches the enclosing region contract.

The most relevant regressions are:

- `strips nested returns inside root returned loops`
- `strips nested multi-value returns in root return context`
- `detects nested multi-value root return context`
- `strips nested returned scalar wrapper blocks`

## Tail-Return Voidification

### `remove_unused_brs_try_voidify_tail_return_if(...)`

This helper handles a different family from simple tail stripping:

- the region tail is a `return`
- the returned value is a typed `if`
- both arms already leave the current path anyway

Instead of preserving a typed value `if`, the pass:

- rebuilds the arms as a void `if`
- replays any arm-local prefix work
- appends `unreachable`

That output shape is only legal when:

- both arms can be rebuilt as nonfallthrough bodies
- multi-value arms do not hide nested `Return` that would invalidate the reshaping
- the `if` label itself is otherwise unused

Key regressions:

- `voidifies tail return-wrapped ifs whose arms already break away`
- `voidifies multi-value tail return-wrapped ifs`
- `voidifies nested tail return-wrapped if ladders`

## Exit-Only Value-`if` Voidification

### `remove_unused_brs_try_voidify_exit_only_value_if(...)`

This helper is even more selective.

- It starts from a one-result `if`.
- It requires that each arm have a single root and a single exit root.
- It refuses carried result wrappers.
- It requires a provably safe single-use chain through:
  - `local.tee`
  - `drop`
  - `local.set`
  - `br`
  - `return`
  - payload slots of `br_if` / `br_table`

If the chain is safe, the pass turns the value-`if` into:

- a void `if`
- inside a one-result block
- followed by `unreachable`

This is the helper behind:

- `voidifies result ifs whose arms only return under drop`
- `voidifies dropped exit-only ifs through local.tee wrappers`

It is also one of the places where the pass intentionally pays for `use-def`, because guessing the single-use chain from local tree shape would be too fragile.

## Trailing `nop` Trimming

### `remove_unused_brs_trim_trailing_nops(...)`

This looks minor, but it carries a real semantic rule:

- trim trailing `nop` roots that became useless after a rewrite
- but preserve:
  - a single root-level `nop`
  - a single `nop` that is the full body of an `if` arm

That preservation rule exists because Binaryen can preserve explicit `nop` intent in these trivial positions, and earlier Starshine cleanup was too aggressive on that exact family.

## Relationship To Returned Ladders

- Tail/return cleanup is the final step for some returned ladders, not the first.
- The helpers on this page generally assume the shape has already been simplified enough that:
  - the removable exit is direct
  - the payload arity is obvious
  - holder blocks are no longer masking a different structural family

If that is not true yet, the real work usually belongs on:

- [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md)
- [`./branch-exit-and-payload-rewrites.md`](./branch-exit-and-payload-rewrites.md)
- [`./carried-guards-and-result-blocks.md`](./carried-guards-and-result-blocks.md)

## Practical Rule

- Reach for these helpers when the continuation is already explicit and local.
- Do not use them as a shortcut for broader carried-wrapper or returned-ladder discovery.
- When a reduction changes payload arity or introduces `unreachable`, re-check whether the family should really be handled by a tail cleanup rather than an earlier structural rewrite.

