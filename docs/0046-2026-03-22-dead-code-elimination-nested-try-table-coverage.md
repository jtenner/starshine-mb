# DeadCodeElimination Nested TryTable Coverage

## Scope

Close the remaining focused `DeadCodeElimination` coverage question for nested
concrete reference-result `try_table` rewrites after the earlier EH slice
landed the base `try_table` retagging rule.

## Current Behavior

When a concrete-result `try_table` body becomes unreachable, Starshine retags
the `try_table` itself to `void`.

In the focused nested shape:

- an outer concrete ref-result `block`
- containing an inner concrete ref-result `try_table`
- whose body is the literal `unreachable`

the optimizer already rewrites to a single `void` `try_table` with an
`unreachable` body, and the resulting typed IR still validates.

## Correctness Constraint

This case must not leave behind a stale concrete result requirement on either
the inner `try_table` or the enclosing block once the unreachable child rewrite
fires.

## Validation

- Added `dead code elimination keeps nested ref-result try_table rewrites valid`
  in
  [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt).
- Verified with
  `moon test src/optimization/dead_code_elimination_wbtest.mbt -F '*nested ref-result try_table rewrites valid*'`.

## Follow-Up

- Port the remaining string-sensitive regressions from the research baseline.
- Revisit EH `pop` fixups as the later control-flow cleanup slice.
