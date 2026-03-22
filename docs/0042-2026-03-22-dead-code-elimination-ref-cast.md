# DeadCodeElimination Ref Cast

## Scope

This checkpoint lands the first no-over-refinalize GC unary slice from
[`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md):
`ref.cast` with an unreachable operand inside concrete reference-result
fixtures.

## Current Behavior

`DeadCodeElimination` now rewrites typed `ref.cast` instructions with the same
generic unary unreachable-child rule already used for arithmetic, loads, and
other one-child nodes. When the operand is unreachable, the cast collapses to
that operand instead of keeping a stale concrete reference wrapper around it.

## Correctness Constraints

- Preserve the existing nullable/exact cast metadata when the operand remains
  reachable.
- Collapse directly to the first unreachable child when the cast operand is
  unreachable.
- Do not force any broader reference-type refinalization while simplifying the
  cast.

## Validation

- Added a focused regression in
  [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt)
  for a concrete `(ref null func)` result fixture whose only body node is
  `ref.cast(... unreachable)`.
- Verified with
  `moon test src/optimization/dead_code_elimination_wbtest.mbt -F '*ref_cast when its operand is unreachable*'`.

## Performance Impact

No material runtime cost change is expected. The benefit is narrower rewritten
typed IR and fewer invalid reference-result wrappers after DCE.

## Open Questions

- Land the sibling unary ref ops (`ref.test`, `ref.test_desc`,
  `ref.cast_desc_eq`).
- Fix the nested concrete-result `try_table` case without over-tightening outer
  reference result types.
- Revisit the string-sensitive and EH `pop` follow-ups once those typed surfaces
  are covered locally.
