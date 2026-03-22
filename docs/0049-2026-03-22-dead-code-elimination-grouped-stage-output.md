# DeadCodeElimination Grouped Stage Output

## Scope

Lock the current output behavior of the real default grouped function stage once
`DeadCodeElimination` has already been wired into that stage.

## Current Behavior

In the current repo state, the grouped function stage contains real
`DeadCodeElimination` work followed by many placeholder func-local passes.

That means the next useful interaction check is not "later passes do more
cleanup" yet. It is "running the real grouped stage preserves the DCE-trimmed
output and still validates."

## Validation

- Added focused pipeline execution coverage in
  [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt).
- The test runs the actual default grouped function stage on a typed fixture
  with `return` followed by dead tail.
- Verified the final body is exactly `[return]` and the optimized module still
  validates.
- Verified with
  `moon test src/optimization/optimization_test.mbt -F '*grouped function stage preserves dead-code-elimination tail trimming output*'`.

## Follow-Up

- Reopen grouped-stage interaction coverage when more of the downstream
  func-local cleanup passes stop being no-op placeholders.
