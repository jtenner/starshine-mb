---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
related:
  - ./pattern-catalog.md
  - ./select-and-condition-rewrites.md
  - ./carried-guards-and-result-blocks.md
  - ./returned-ladder-hot-shapes.md
  - ./parity.md
---

# `remove-unused-brs` Branch-Exit And Payload Rewrites

## Scope

This page covers the helpers that clean up explicit branch-shaped control once the pass can see direct block-local structure:

- one-armed `if br`
- local-set branch/copy arms
- two-arm branch exits
- one-arm payload branches
- branch-payload `if`
- tail value-`if` branch exits
- block-if chain flattening
- suffix restructuring and related arm-local structural cleanup

## One-Armed `if br` To `br_if`

### `remove_unused_brs_try_rewrite_if_br(...)`

This is the canonical `if br` cleanup.

- If the then arm is a plain `br`, the pass replaces the whole `if` with `br_if`.
- If the then arm is itself a `br_if`, the pass can combine the outer and inner conditions when both are reorder-safe.

The pass therefore treats "one-armed if break" and "nested one-armed if break" as the same family, just with a stronger condition guard for the second case.

## Inline Single-Branch Wrapper Blocks

### `remove_unused_brs_try_inline_single_br_if_block(...)`

Some block-local branch cleanup opportunities are hidden behind a void block that:

- has an otherwise-unused label
- contains exactly one live root
- and that root is `br` or `br_if`

This helper inlines the body root into the parent region.

It is less glamorous than the large carried-wrapper rewrites, but it is a key exposure helper for later branch cleanup.

## Local-Set Arm Rewrites

### `remove_unused_brs_try_rewrite_region_local_set_copy_arm(...)`

This helper handles the copy-arm case:

- `local.set X (if cond then value else local.get X)`

It becomes:

- one-armed `if`
- whose then body performs `local.set X value`

### `remove_unused_brs_try_rewrite_region_local_set_br_arm(...)`

This helper handles the branch-arm case:

- `local.set X (if cond then br label else value)`

It becomes:

- `br_if label cond`
- followed by `local.set X value`

Together these helpers model the "optimizeSetIf" flavor of cleanup already called out in the Binaryen comparison note.

## Two-Arm Branch Exit Cleanup

### `remove_unused_brs_try_rewrite_two_arm_branch_if(...)`

This helper rewrites:

- `if { br X } else { br Y }`

into:

- `br_if X cond`
- `br Y`

or even a single `br` if both targets are the same.

Important boundaries:

- the arm roots must be plain branches
- the `if` label itself cannot be the chosen branch target
- immediate-holder targeting is not required; the helper already handles the "neither arm targets the holder" family

## One-Arm Payload Branch Cleanup

### `remove_unused_brs_try_rewrite_one_arm_payload_branch_if(...)`

This helper handles a void `if` where exactly one arm is a payload-bearing branch and the other arm is fallthrough work.

The replacement shape is:

- `drop(br_if target payload condition)`
- followed by the surviving body roots

This is the main direct one-arm payload family, but not the only one. More complicated carried-wrapper versions live on the carried-guards page.

## Branch-Payload `if`

### `remove_unused_brs_try_rewrite_branch_payload_if(...)`

This helper starts from an outer `br` whose payload children all point at the same typed `if`.

That matters because the pass is not just cleaning up `if` roots inside regions. It is also willing to clean up control that only appears as a branch payload.

The helper recognizes:

- branching else arms
- multi-value payload branches
- nested simple payload `if`

and can also trigger nested voidification in those payload arms once the branch-exit shape becomes explicit enough.

## Tail Value-`if` Branch Exits

### `remove_unused_brs_try_rewrite_tail_value_if_branch_exit(...)`

This helper lives at the tail of a region.

- One arm is a plain branch exit.
- The other arm contributes the fallthrough payload.
- The whole value `if` can then be linearized into a `br_if` plus direct payload work.

This is the source of the "stack-style branch exits from tail value if arms" regressions.

## Returned Child Branch Exits

### `remove_unused_brs_try_rewrite_return_child_if_branch_exit(...)`

When the interesting value `if` sits under explicit `Return`, the pass delegates to this helper.

- It descends through the return child.
- It tries the ordinary tail branch-exit cleanup inside the returned regions.
- It lets returned ladders participate in the same branch-exit cleanup without pretending they were direct region tails from the start.

This is why returned ladders share ownership between this page and [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md).

## Block-If Chain Flattening

### `remove_unused_brs_try_flatten_block_if_chain(...)`
### `remove_unused_brs_flatten_block_if_chains(...)`

These helpers flatten block-local chains once earlier rewrites have exposed them as direct block-body roots.

They are the reason the pass can keep draining sequences like:

- `if br else if br`
- multi-root then arms before block exit
- else-arm break ladders

without needing a general-purpose nested CFG optimizer.

## Suffix Restructuring

### `remove_unused_brs_try_restructure_one_arm_return_if_suffix(...)`

This helper takes:

- a one-arm void `if`
- whose then arm is just `return`
- followed by suffix roots that already end in the enclosing branch exit

and rewrites it into an explicit `else` form with the suffix moved inside.

### `remove_unused_brs_try_restructure_one_exit_arm_if_suffix(...)`

This helper handles the sibling case:

- exactly one arm is already nonfallthrough
- the suffix already exits the enclosing block

The pass moves the suffix into the fallthrough arm and leaves the nonfallthrough arm alone.

These helpers are not just pretty-print cleanups. They are how the pass exposes later block-local opportunities without scanning deeper everywhere.

## Arm-Local Self-Branch Cleanup

### `remove_unused_brs_try_sink_if_arm_self_branch_block(...)`

This helper removes an explicit self-target branch from an `if` arm when:

- the surrounding block's label is only used by that arm tail
- the arm has real side effects before the self-branch

Instead of leaving `(then ... br $done)`, the pass wraps the side-effect roots in arm-local blocks and removes the explicit branch.

This is the "self-target if-arm block branches" family called out in the backlog.

## Void Block / Single Loop Rotation

### `remove_unused_brs_try_rotate_void_block_single_loop(...)`

This helper is a small but real structural normalization:

- `block -> loop(body)`

becomes:

- `loop(block(body), unreachable)`

when the loop body has no nested value control.

The rotation is deliberately blocked when nested value control exists, because that wrapper can still matter for later typed cleanup.

## Practical Rule

- Use the helpers on this page when the branch structure is already direct and local.
- If the branch/payload family still depends on result-block carriers or prefix guards, move to [`./carried-guards-and-result-blocks.md`](./carried-guards-and-result-blocks.md).
- If the branch family is hidden behind explicit `Return` and holder blocks, check [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md) before widening a matcher here.

