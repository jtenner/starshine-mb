# DeadCodeElimination Default Stage Ordering

## Scope

Lock the first grouped-pipeline interaction guarantee for the landed
`DeadCodeElimination` port in the default optimize pipeline.

## Current Behavior

In the default function-local optimize stage, Starshine currently orders:

1. `DeadCodeElimination`
2. early cleanup passes including `RemoveUnusedNames` and `RemoveUnusedBrs`
3. later simplification passes
4. `Vacuum`

That ordering matters because later cleanup and compaction passes are supposed
to consume DCE's output, not run before it.

## Validation

- Added focused coverage in
  [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt)
  to assert the grouped function stage keeps `DeadCodeElimination` ahead of the
  first `RemoveUnusedNames`, the first `RemoveUnusedBrs`, and `Vacuum`.
- Verified with
  `moon test src/optimization/optimization_test.mbt -F '*dead code elimination ahead of cleanup passes*'`.

## Follow-Up

- Add grouped-pipeline output coverage that proves later cleanup passes consume
  DCE-trimmed function bodies as expected.
