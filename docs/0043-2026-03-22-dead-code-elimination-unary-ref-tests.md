# DeadCodeElimination Unary Ref Tests

## Scope

This checkpoint lands the sibling GC unary ref-op slice from
[`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md):
`ref.test`, `ref.test_desc`, and `ref.cast_desc_eq` with unreachable operands.

## Current Behavior

`DeadCodeElimination` now rewrites these typed one-child reference operators
with the same generic unreachable-child rule already used for arithmetic and
plain `ref.cast`. Once the operand is unreachable, the wrapper operator itself
is removed and DCE keeps only the unreachable child plus any earlier prefix
effects.

## Correctness Constraints

- Preserve reachable operand behavior and existing nullable / heap-type metadata.
- Remove the wrapper op once the operand is unreachable.
- Avoid broad GC type tightening while simplifying descriptor-aware unary ops.

## Validation

- Added focused regressions in
  [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt)
  for unreachable `ref.test_desc` and `ref.cast_desc_eq` operands.
- Verified with
  `moon test src/optimization/dead_code_elimination_wbtest.mbt -F '*ref_*operand is unreachable*'`.

## Performance Impact

No meaningful runtime cost change is expected. The value is tighter typed IR
after DCE and fewer invalid unary reference wrappers in unreachable paths.

## Open Questions

- Land `ref.get_desc` once a focused descriptor-bearing fixture is added.
- Fix the nested concrete-result `try_table` case without over-tightening outer
  reference result types.
- Revisit the string-sensitive and EH `pop` follow-ups once those typed surfaces
  exist locally.
