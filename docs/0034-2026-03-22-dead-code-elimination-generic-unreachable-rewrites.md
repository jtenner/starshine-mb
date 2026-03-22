# DeadCodeElimination Generic Unreachable Rewrites

## Scope
- Land Slice 2 from the DCE migration plan in [docs/0017-2026-03-22-dead-code-elimination.md](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md).
- Implement the generic non-control-flow rule: preserve reachable prefix effects before the first unreachable child.
- Keep control-flow-specific rewrites and block truncation for later slices.

## Current Behavior
- The DCE runner now rewrites non-control-flow typed instructions after recursively rewriting their children.
- Supported coverage in this slice includes binary ops, stores, `select`, and direct calls, with the same generic prefix-effect rule also applied to related unary/set/load forms in the implementation.
- The pass still does not truncate enclosing block tails or update control-flow result types.

## Correctness Constraints
- Child handling must respect actual evaluation order, not storage order in every AST constructor.
- Reachable prefix children must be preserved as `drop(...)`.
- The first unreachable child must remain unchanged.
- Later children must be removed entirely.
- If only one child survives, the parent must collapse directly to that child instead of forcing a wrapper block.

## Validation Plan
- Add whitebox regressions for right-unreachable binary operands, store address/value ordering, `select` condition ordering, and direct-call arg ordering.
- Run `moon test src/optimization/dead_code_elimination_wbtest.mbt`.

## Performance Impact
- Low. The new logic is a bounded per-instruction child scan during the existing function walk.

## Open Questions
- Slice 3 remains block tail truncation and single-unreachable collapse for enclosing `block` bodies.
- Later slices still need live-break tracking and synchronous control-flow type updates.
