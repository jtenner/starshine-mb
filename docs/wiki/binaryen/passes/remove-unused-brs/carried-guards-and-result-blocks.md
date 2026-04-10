---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/cmd/cmd_test.mbt
  - ../../../../../agent-todo.md
related:
  - ./pattern-catalog.md
  - ./branch-exit-and-payload-rewrites.md
  - ./returned-ladder-hot-shapes.md
  - ./parity.md
---

# `remove-unused-brs` Carried Guards And Result Blocks

## Why This Family Has Its Own Page

- Most of the current artifact parity work lives here.
- These shapes look like ordinary "branch payload cleanup" in normalized WAT, but in HOT they are usually result-block or guard-carrier problems.
- They are also the easiest place to regress correctness:
  - label-owner mistakes
  - branch-arity mismatches
  - deleting a wrapper that is still somebody else's payload carrier
  - changing a shape Binaryen intentionally keeps for a later phase

## The Common Shape

The recurring carrier family usually contains some combination of:

- a result block whose label supplies the payload type
- an inner void block that starts with `br_if` to its own label
- a later `br` carrying the actual payload to an outer label
- a `drop` around the result block because the branch payload is only needed structurally
- sibling carriers or suffix roots that make the interesting branch live outside the immediate body tail

This is why the pass keeps recomputing:

- label reference counts
- branch-payload-child marks

Those two analyses are the main legality boundary for this entire page.

## Result-Block Prefix Payload Branch

### `remove_unused_brs_try_rewrite_result_block_prefix_payload_branch(...)`

This helper handles the direct result-block prefix family:

- the enclosing holder is a value block
- its first root is an inner void block
- the inner block begins with `br_if` to itself
- the tail of the inner block branches to the outer value label with the real payload

The rewrite:

- removes the inner guard branch
- rebuilds the inner body without that guard
- wraps the inner block in a new outer `if`

This is the main "carried guard block becomes one-arm `if`" transformation.

The focused regressions include:

- `rewrites result-block br_if prefixes into one-arm payload ifs`
- `rewrites result-block br_if prefixes with payload bodies into one-arm payload ifs`
- `rewrites stack-style branch-payload result wrappers around br_if prefixes`
- `rewrites sibling-carried branch payload wrappers around br_if prefixes`

## Dropped Result-Block Tail Branch

### `remove_unused_brs_try_rewrite_drop_result_block_if_tail_branch(...)`

This helper handles:

- `drop(block(result T) (if ...) (br target ...))`

The important point is that RUB does not simply delete the wrapper.

- It splits the shape into the dropped `if` plus a dropped branch payload.
- That keeps the dropped branch carrier explicit while removing the unnecessary typed block shell.

This is why the pass still has tests that mention preserved dropped typed carriers even when some wrappers can now be removed.

## Block Prefix Payload Branch Root

### `remove_unused_brs_try_rewrite_block_prefix_payload_branch_root(...)`

This helper is the void-block analogue of the result-block prefix rewrite.

- the block body starts with `br_if` to the block's own label
- later roots in the block or its sibling/suffix region carry the real payload branch
- the block label's reference count proves the shape is local enough to rewrite

The rewrite turns the guard into an outer `if` whose then arm reuses the block body with the original guard removed.

This is the helper behind most of the backlog language about:

- sibling carried guards
- dropped carried guards
- then-arm carried guards
- removable self tails

## Prefixed One-Arm Payload Branch Suffix

### `remove_unused_brs_try_rewrite_prefixed_one_arm_payload_branch_if_suffix(...)`

This helper covers the narrower suffix form:

- the enclosing region is a one-result region
- some roots already ran before the interesting `if`
- a later one-arm payload branch can now become `drop(br_if ...)`

The rewrite matters because not every one-arm payload family is rooted at index zero. Some only become legal once the pass proves that the prefix roots can stay in place and the carried branch can be lowered in the suffix.

## Result-Block One-Arm Payload `if`

### `remove_unused_brs_try_rewrite_result_block_one_arm_payload_if(...)`

This helper is unusual because it owns both a rewrite and a deliberate preservation.

It rewrites the simple direct family:

- a one-result block
- first root is a direct one-arm payload `if`
- remaining roots already form the fallthrough payload

But it deliberately preserves the more complex prefix-heavy carried-wrapper family.

The source comment says why:

- Binaryen still keeps those remaining wrappers
- so RUB leaves them intact for parity instead of over-normalizing them

The paired regressions are:

- `simplifies block-carried one-arm payload branches into value selection`
- `preserves prefix-heavy block-carried one-arm payload wrappers for oracle parity`

## Branch-Payload Children As A Hard Boundary

One of the most important details in the current implementation is `branch_payload_children`.

- If a result block is itself serving as a payload child for some other branch, RUB often refuses to simplify it yet.
- That is not just defensive programming.
- It is how the pass avoids deleting a wrapper that another branch still needs to carry the right value/arity structure.

When a new result-block cleanup looks obviously correct but `branch_payload_children` blocks it, assume the analysis is protecting a real invariant until proven otherwise.

## Native And Artifact Coverage

This family is not only covered by unit-like pass tests.

- The CLI test `run_cmd_with_adapter dumps lowered remove-unused-brs carried guard wrappers without br_if` locks one native lowered family directly.
- The artifact replay test `run_cmd_with_adapter validates remove-unused-brs on debug artifact` ensures the explicit pass still emits valid wasm on the checked-in debug artifact.
- The backlog notes that several major artifact blocker families already moved because these helpers landed:
  - dropped then-arm wrappers
  - prefixed payload suffixes
  - carried-suffix recognition
  - raw structured-return-ladder false-positive removal

## Practical Rule

- If the family mentions "carrier", "wrapper", "prefix guard", or "result block", start here before reaching for a generic branch-exit helper.
- Always check:
  - label reference counts
  - branch target arity
  - whether the candidate block is still a payload child
  - whether Binaryen intentionally keeps the wrapper longer
- Do not treat these as cosmetic reshapes. This page owns some of the most parity-sensitive correctness work in the pass.

