# DAE003 iteration-budget guard

_Date:_ 2026-05-26
_Status:_ focused regression / backlog closeout evidence

## Scope

This note closes `[DAE003-H]` for the current v0.1.0 surface by adding a focused regression for the previously suspected fixed core-iteration/starvation boundary.

## Evidence

The new `src/passes/dae_optimizing_test.mbt` test `dae-optimizing reaches exact literal after more than fixed core plus low revisit budget` builds a mid-size module with:

- 73 earlier productive exact-literal rewrites from one exported caller,
- a later target at defined function `1610`, and
- total defined functions below the guarded `defined <= 4096` low-revisit lane.

The test verifies the later target's parameter is removed and materialized as `I32(73)`. This covers a case beyond the old fixed core loop plus earlier selected/starvation assumptions without raising the core fixed-loop budget or broadening the large-artifact path.

## Result

No optimizer behavior change was required: the existing bounded low-forwarded-const revisit already reaches this family. `[DAE003-H]` is closed as a regression-guard/evidence slice rather than an implementation slice.

## Validation

- `moon test src/passes --target native` passed: `1471` tests.

Full quick signoff was run after the docs/backlog updates in the recovery thread.
