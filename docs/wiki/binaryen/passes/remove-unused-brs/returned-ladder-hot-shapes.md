---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
related:
  - ./pattern-catalog.md
  - ./starshine-hot-ir-strategy.md
  - ./tail-and-return-cleanups.md
  - ./select-and-condition-rewrites.md
  - ./branch-exit-and-payload-rewrites.md
  - ./parity.md
  - ./visit-order-and-bailouts.md
---

# `remove-unused-brs` Returned-Ladder HOT Shapes

## Why This Page Exists

- Printed WAT is not enough to reason about the hard RUB families.
- The pass does not receive the remaining returned-ladder cases as the clean typed `if` shapes that pretty WAT suggests.
- After lift, the important families arrive as:
  - explicit `Return`
  - typed holder `Block`
  - zero-result wrapper blocks around arms
  - nested returned value blocks that themselves contain typed `If`

That is why broad "just search all return-context tails" experiments repeatedly overfired or cost too much.

## Representative Lifted Shapes

### Scalar returned ladder

- Root region:
  - one root
  - that root is a `Block(result T)`
- Holder-block body:
  - one root
  - that root is `Return`
- Return child:
  - a typed `If`
- Then arm:
  - zero-result holder block
  - body roots like side effects plus `Return`
- Else arm:
  - zero-result holder block
  - usually another direct `Return`

### Nested returned ladder

- The value produced by the first returned branch can itself be another typed block.
- That typed block often contains:
  - another typed `If`
  - two more zero-result holder blocks
  - returned scalar or branch-exit work hidden behind those wrappers

### Multi-value returned ladder

- The same wrapper pattern exists for multi-value cases.
- The difference is that payload arity checks become stricter:
  - a child payload cannot silently shrink
  - a repeated child carrier has to match the exact result arity
  - branch-arity and return-context stripping helpers become the real legality boundary

## Why These Shapes Break Naive Matcher Discovery

- The pass is strongest on direct region tails and direct branch-payload contexts.
- Returned ladders after lift are often neither:
  - the "interesting" `If` is a child of `Return`, not the region tail itself
  - the arms are holder blocks, not direct region roots
  - the value-producing tail may be hidden behind another typed block
- So a matcher written from normalized WAT alone usually makes one of two mistakes:
  - it misses the family because it looks in the wrong place
  - it broadens the search so much that it revisits many unrelated returned regions and hurts perf

## How The Current Pass Interacts With These Shapes

The current tree does not have one single "returned ladder rewrite". It handles these shapes through several narrow helpers:

- `remove_unused_brs_try_strip_return_context_tail(...)`
  for direct returned-tail stripping once the lifted shape already exposes the removable exit
- `remove_unused_brs_try_rewrite_tail_value_if_branch_exit(...)`
  for branch-exit cleanup inside a returned region
- `remove_unused_brs_try_rewrite_return_child_if_branch_exit(...)`
  for value-`if` children under explicit `Return`
- `remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(...)`
  for one-sided stack-exit select formation
- `remove_unused_brs_try_voidify_tail_return_if(...)`
  when the lifted shape has already reached an exit-only tail-return form
- `remove_unused_brs_try_restructure_one_arm_return_if_suffix(...)`
  and `remove_unused_brs_try_restructure_one_exit_arm_if_suffix(...)`
  when the interesting cleanup is really suffix restructuring rather than tail stripping

The pass therefore treats returned ladders as a family of lifted-shape entry points, not as one canonical printed-WAT pattern.

## Why It Matters

- The existing regressions prove both sides of the rule:
  - some returned ladders should collapse
  - some returned ladders must stay typed until a later select or suffix rewrite
- That is why this page belongs beside the pattern catalog instead of inside parity alone.

The returned-ladder tests already split into:

- families that should rewrite:
  - `lifts scalar returned ladders through return and holder blocks`
  - `lifts multi-value returned ladders through repeated holder blocks`
  - `flattens nested returned ladder branch exits`
  - `lowers scalar returned ladders with side-effect arms to select`
  - `lowers nested scalar returned ladders with side-effect arms`
- families that must survive:
  - `preserves result ifs for nested multi-value root return blocks`
  - `preserves scalar root return ifs with returned block arms`
  - `preserves scalar root return ifs with nested returned block ladders`
  - `preserves result ifs for nested scalar root return blocks`
  - `preserves scalar root return ifs with direct return arms`

So the key question is never just "can we see a returned `if`?".
The real question is:

- which lifted wrapper shape are we in
- which helper owns that shape
- whether the next step should be stripping, select formation, suffix restructuring, or deliberate preservation

## Practical Rule

- Treat these families as lifted-shape work first and parity work second.
- Always inspect the HOT holder / `Return` shape before widening a matcher that looks harmless in WAT.
- Preserve the returned-scalar tests that prove some typed ladders must survive longer.
- If a new mismatch only appears after lift and still reports `changed=false`, verify whether the real problem is RUB at all before adding another returned-ladder rewrite.

## Relationship To Bailouts

- The raw structured-return-ladder skip exists specifically because many printed returned ladders are no-op families unless a HOT-only candidate is also present.
- The perf tests now lock in the rule that lift must still happen when:
  - a condition-child value-`if` rewrite is present
  - a carried-guard payload/result-block rewrite is present
- So returned ladders are not just a shape note. They are one of the reasons the current raw/hot split exists.

## Sources

- Archived research doc: [`../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md`](../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md)
- Pattern inventory: [`./pattern-catalog.md`](./pattern-catalog.md)
- Related strategy page: [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
- Related parity page: [`./parity.md`](./parity.md)
- Focused tests: [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt)
- Perf coverage: [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)

