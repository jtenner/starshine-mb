---
kind: concept
status: working
last_reviewed: 2026-10-02
sources:
  - ./index.md
  - ../late-pipeline-dispatch.md
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/cmd/cmd.mbt
  - https://github.com/WebAssembly/binaryen/commit/b125d2e19542df72458bc916a2d0aa4bf72500fd
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
- After the 2026-04-18 slot-14 generated-artifact fix, Starshine also keeps the plain-`br` form intact when a **large** lifted function (`hot_node_count >= 256`) would otherwise rewrite a non-reorder-safe condition. The extracted `Func 1354` replay showed that this large carried-condition family could lower to invalid wasm even though Binaryen kept a valid block-plus-branch shape on the same oracle input.

The pass therefore treats "one-armed if break" and "nested one-armed if break" as the same family in small, simple cases, but now keeps an explicit large-condition correctness guard on the direct `if br -> br_if` path.

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
- `local.set X (if cond then local.get X else value)` with a flipped `i32.eqz` condition
- the same shapes under `local.tee`, where the replacement is a result block containing the one-armed setter and a trailing `local.get X`

It becomes:

- one-armed `if`
- whose then body performs `local.set X value`
- plus a result-preserving `local.get` wrapper when the original store was a tee

### `remove_unused_brs_try_rewrite_region_local_set_br_arm(...)`

This helper handles the branch-arm case:

- `local.set X (if cond then br label else value)`
- `local.set X (if cond then value else br label)` with a flipped `i32.eqz` condition
- the same shapes under `local.tee`, where the surviving value remains a tee result

It becomes:

- `br_if label cond` (or `br_if label (i32.eqz cond)` for else-arm branches)
- followed by `local.set X value` or `local.tee X value`

Together these helpers model the locally representable `optimizeSetIf` flavor of cleanup already called out in the Binaryen comparison note. Re-entering the region walk gives the same observable recursive cleanup for nested local-set copy arms that Binaryen gets by recursing on the rewritten `set->value`. The 2026-06-29 value-legality audit in [research note 1378](./index.md) keeps conditional `br_if` set-if arms conservative, matching Binaryen `version_130`'s source TODO for the side-effect/order proof needed before conditional branch-arm extraction.

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

### Branch-value speculation cost (October 2, 2026)

The direct helper and
`remove_unused_brs_try_rewrite_prefixed_one_arm_payload_branch_if_suffix`
check branch-value cost before moving a conditional payload ahead of `br_if`.
They reuse the existing selectify cost walk and threshold policy: reject costs
above 4 at shrink level 0, reject costs of at least 8 at shrink level 1, and
bypass the cost walk at shrink levels 2 and higher. This is the narrow local
counterpart of [Binaryen #9187 / b125d2e](https://github.com/WebAssembly/binaryen/commit/b125d2e19542df72458bc916a2d0aa4bf72500fd).

Admission sums existing branch children without new arrays, worklists or HOT
nodes. The prefixed path first verifies a sole live branch to its holder, then
checks cost before its region-value builder; rejected payloads do not create a
temporary result block. Generated native C has no direct allocation calls in
the new cost/threshold guards; total allocations inside the reused estimator
were not measured. Existing legality checks and payload-free branch handling
remain separate.

Bounded public-pipeline tests cover costs 0/4/5/7/8 at shrink levels 0/1/2,
with no else, a then-arm branch and an else-arm branch. Nontrapping `i32.rem_u`
and `struct.new_default` witnesses catch unwanted unconditional work; an active
CLI-dispatch test protects option propagation. These are executable local
regressions against the previously eager paths, not full pass closeout or
Binaryen-v133 executable-oracle signoff. A verified v133 oracle is unavailable
in this checkout; long fuzzing and artifact-wide comparisons are outside this
bounded update.

Final focused validation passes `moon info`, `moon fmt`, all 269 tests in
`remove_unused_brs_test.mbt`, and all 76 tests in `src/cmd/cmd.mbt`. Five new
pass tests and one dispatcher test cover 52 bounded fixture/option combinations.
The red-test commit records four intended pass failures and one dispatcher
failure before the implementation.

A short native-release benchmark runs 32 identical branch-payload functions per
sample, with fixtures prepared and validated before measurement. Pipeline
means are 1.15 ms (cost 0, shrink 0), 934.26 µs (cost 8, shrink 0), and 1.82 ms
(cost 8, shrink 2), across ten measured batches per control. Timings include
lift/pass/lower with final module validation disabled after preflight. They
are descriptive post-change controls, not before/after, pass-local, or Binaryen
speed comparisons. Moon 0.1.20260920 and GCC 14.2.0 were used on x86_64.


The direct rewrite now also has one whole-function negative parity guard.

- If the current function contains any `br_table`, the helper bails out immediately.
- The reduced `Func 3771` family proved Binaryen keeps that shape as an `if` instead of lowering it to `drop(br_if ...)`.
- The focused regression is `remove-unused-brs keeps one-arm payload branch ifs in br_table functions`.

The implementation detail matters for performance too.

- The guard reuses the existing `branch_payload_children` scan, which now also returns `has_br_table`.
- The first correct draft added a second whole-function walk and regressed the full self-opt replay, so future whole-function negative guards should piggyback on an existing scan when possible.

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
