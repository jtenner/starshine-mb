# DeadCodeElimination Branch Value Stress

Status: completed Slice 8 from [`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md). `DeadCodeElimination` now rewrites the first branch-value stress cases instead of leaving stale branch instructions behind when their values or dispatch inputs become unreachable.

## Scope

Checkpoint the hard branch-value cases from the research plan:

- unreachable `br` values
- unreachable `br_if` condition paths
- unreachable `br_table` indices
- one focused ancestor case where killing a nested branch also kills the enclosing block's stale result type

## Landed Behavior

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) now rewrites `br` using the same evaluation-order-preserving prefix-effect helper as the non-control-flow cases.
- `br_if` now evaluates branch values before the condition for DCE purposes, so an unreachable condition or earlier value collapses the whole branch to the preserved-prefix-plus-unreachable form.
- `br_table` now does the same for branch values followed by the dispatch index.
- The focused ancestor regression now confirms that removing a dead nested `br_if` path also lets the enclosing typed block drop its stale value requirement.

## Correctness Constraints

- `br` with an unreachable value must become unreachable, not remain a branch instruction that pretends the value can still be produced.
- `br_if` must preserve folded evaluation order: branch values first, condition last.
- `br_table` must preserve branch values before the table index.
- Killing a dead branch path must be visible to the enclosing typed block so it can degrade away from a stale result type.

## Validation

- Added whitebox coverage in [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt) for:
  - unreachable `br` values
  - unreachable `br_if` conditions
  - unreachable `br_table` indices
  - an ancestor block-type regression triggered by a dead nested `br_if`
- Verified with `moon test src/optimization/dead_code_elimination_wbtest.mbt`.

## Performance Impact

- Negligible. The new logic reuses the existing prefix-effect rewrite helper and only adds small child-array assembly for branch instructions.

## Next Work

- The next DCE slice is the GC/reference-sensitive regression set.
- After that, revisit the later EH `pop` fixup and handler-sensitive follow-up work.
