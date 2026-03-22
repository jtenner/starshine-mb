# DeadCodeElimination GC Branch Ops

## Scope

This checkpoint lands the GC branch-op part of Slice 9 from
[`docs/0017-2026-03-22-dead-code-elimination.md`](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md):
`br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` when
their inspected ref or earlier prefix values become unreachable.

## Current Behavior

`DeadCodeElimination` now rewrites these branch ops with the same
evaluation-order-preserving helper already used by `br`, `br_if`, and
`br_table`. Reachable prefix effects are preserved as `drop`s, the first
unreachable child is kept, and the branch op itself is removed once the
inspected ref or any earlier required child is unreachable.

## Correctness Constraints

- Preserve child evaluation order for branch values before the inspected ref.
- Do not keep a stale GC branch op once its required ref input is unreachable.
- Keep typed one-result fixtures valid so the pass can be checked end to end.

## Validation

- Added focused regressions in
  [`src/optimization/dead_code_elimination_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/dead_code_elimination_wbtest.mbt)
  for `br_on_non_null` and `br_on_cast_fail` with unreachable inspected refs.
- Verified with `moon test src/optimization/dead_code_elimination_wbtest.mbt`.

## Performance Impact

No expected runtime cost change beyond applying the existing DCE rewrite logic
to more typed instruction shapes. The benefit is smaller and cleaner rewritten
IR in GC-heavy code.

## Open Questions

- Land the remaining `ref.cast` / reference-result no-over-refinalize cases.
- Add string-sensitive regressions from the research baseline.
- Revisit the later EH `pop` fixup follow-up once the typed-IR surface is fully
  covered.
