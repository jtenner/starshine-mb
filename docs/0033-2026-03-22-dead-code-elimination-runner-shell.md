# DeadCodeElimination Runner Shell

## Scope
- Land Slice 1 from the DCE migration plan in [docs/0017-2026-03-22-dead-code-elimination.md](/home/jtenner/Projects/starshine-mb/docs/0017-2026-03-22-dead-code-elimination.md).
- Replace the generic func-local no-op dispatch with a dedicated `run_dead_code_elimination` shell.
- Add focused whitebox coverage for pipeline dispatch and typed-function visitation.

## Current Behavior
- `DeadCodeElimination` is now routed through its own func-local runner symbol.
- The runner visits typed functions, reports scratch stats, and preserves bodies unchanged.
- No unreachable-code rewrite semantics are landed in this slice.

## Correctness Constraints
- Pipeline grouping must keep the dedicated DCE runner as the first func-local entry instead of replacing it with the generic no-op shell.
- The shell must preserve module shape and bodies exactly until real rewrite logic lands.
- Scratch accounting should reflect visited functions without spuriously marking the pass as changed.

## Validation Plan
- Add whitebox coverage for `add_pass_to_pipeline(... DeadCodeElimination ...)`.
- Add a typed-function smoke test for `run_dead_code_elimination`.
- Run `moon test src/optimization/dead_code_elimination_wbtest.mbt`.

## Performance Impact
- Negligible. The shell only walks the function list and counts visits.

## Open Questions
- Slice 2 remains the generic non-control-flow unreachable-child rewrite.
- Slice 3 remains block tail truncation and single-unreachable collapse.
