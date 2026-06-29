# 1381 - remove-unused-brs large br_table JumpThreader boundary

Date: 2026-06-29

## Scope

This slice re-audits the remaining large-table JumpThreader item after note `1375` raised the safe no-payload `br_table` retargeting cap to nine explicit targets.

Result: no implementation change. This slice adds an explicit ten-target boundary test and keeps the larger table family blocked until the retargeting predicate can distinguish JumpThreader-only shell cases from early mostly-default `optimizeSwitch(...)` candidates.

## Source and local evidence

Local Binaryen oracle source: `.tmp/binaryen-v130/RemoveUnusedBrs.cpp` (`wasm-opt version_130`).

Binaryen's `JumpThreader::visitExpression(...)` records scope-name uses through `BranchUtils::operateOnScopeNameUsesAndSentTypes(...)` only when the sent type is `Type::none`, then `JumpThreader::visitBlock(...)` uses `BranchUtils::replacePossibleTarget(...)` to redirect no-payload branch uses through one-child named block shells or child-block-to-following-simple-jump shells. The upstream source does not impose a small-table cutoff.

Starshine's local cutoff is a defensive shape-interaction guard in `remove_unused_brs_branch_table_can_retarget_without_payload(...)`, not a semantic Binaryen rule. The existing gates are:

- node op must be HOT `BrTable`;
- child count must be `0` or `1` so there are no branch payload children;
- all explicit/default branch targets must have branch arity `0`;
- explicit target count must be at most `9`.

Note `1375` records the red-first nine-target implementation and the failed broad `32`-target experiment. Raising the cap to `32` regressed existing switch-lowering tests:

- `remove-unused-brs lowers nested stack-style large mostly-default br_table`
- `remove-unused-brs keeps below-threshold mostly-default br_table`

Those failures show the broad retargeter can rewrite the same large table structure that early `optimizeSwitch(...)` expects to inspect for mostly-default lowering.

## Test added

`src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs boundary keeps ten-target br_table jump-threading conservative`

The fixture is a no-payload, selector-child `br_table` inside a one-child named block shell. It has ten explicit targets, including two `$inner` targets that would retarget if the guard were widened. The test asserts the table remains live and both `$inner` target slots still point at the inner label.

This is an intentional boundary test. It is green under current behavior and protects the chosen guard while the precise predicate remains unimplemented.

## Validation

Focused validation after adding the boundary test:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` — passed `211/211`.

Full validation is left to the thread's validation slice.

## Status update

The large `br_table` JumpThreader family is now documented as a precise local blocker:

- current implemented subset: no-payload `br_table` retargeting through one-child shells and child-to-following-simple-jump shapes for zero-child/selector-child HOT tables with at most nine explicit targets;
- protected boundary: ten or more explicit targets stay conservative;
- reopening criteria: derive a predicate that proves a large table is a pure JumpThreader shell-retarget case and not an early mostly-default switch-lowering candidate, then add red-first tests that keep the existing mostly-default switch expectations green while enabling the new large-table retarget case.

Direct compare was not rerun for this slice because no pass implementation behavior changed.
