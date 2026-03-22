# DeadCodeElimination Ref Get Desc

## Scope

This checkpoint lands the remaining descriptor unary rewrite from the GC
reference slice in
[`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md):
`ref.get_desc` with an unreachable operand inside a descriptor-bearing fixture.

## Current Behavior

`DeadCodeElimination` now rewrites typed `ref.get_desc` instructions with the
same generic unary unreachable-child rule used by `ref.cast`, `ref.test`, and
the descriptor-aware sibling ops. When the inspected reference is unreachable,
the wrapper instruction disappears and DCE keeps only the unreachable child.

## Correctness Constraints

- Preserve the requested descriptor target type when the operand remains
  reachable.
- Collapse directly to the first unreachable child when the inspected reference
  is unreachable.
- Keep descriptor-bearing fixtures valid without introducing unrelated type
  tightening.

## Validation

- Added a descriptor-bearing regression in
  [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt)
  for `drop(ref.get_desc(... unreachable))`.
- Verified with
  `moon test src/optimization/dead_code_elimination_wbtest.mbt -F '*ref_get_desc when its operand is unreachable*'`.

## Performance Impact

No meaningful runtime cost change is expected. The benefit is removing one more
stale GC unary wrapper from unreachable typed IR.

## Open Questions

- Decide whether the nested concrete-result `try_table` case needs any rewrite
  tightening beyond the current unreachable-equivalent void wrapper shape.
- Revisit the string-sensitive and EH `pop` follow-ups once those typed surfaces
  exist locally.
