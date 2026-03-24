# `RemoveUnusedNames` Candidate Pre-Scan

Status: completed implementation slice; large-artifact runtime blocker still open.

## Scope
- Pass:
  - `RemoveUnusedNames`
- Goal:
  - avoid paying for the full typed rewrite walk on functions that cannot change

## Problem
- After the branch-summary memoization slice, the pass was still too expensive on the fresh release artifact.
- The common no-op case was still doing a full bottom-up rewrite walk over every typed function body even when the body contained:
  - no `loop`
  - no same-typed single-child `block` peel opportunity

## Change
- Added `optimization_remove_unused_names_has_candidate_typed_body(...)` in `src/optimization/optimization.mbt`.
- The scan uses a cheap early-exit transformer:
  - return `true` immediately on any `loop`
  - return `true` on any `block bt` whose body is exactly one child `block bt`
  - otherwise keep traversing
- `optimization_remove_unused_names_func(...)` now returns immediately when the candidate scan is false.

## Pseudocode

```text
has_candidate(expr):
  walk instructions depth-first
  if any instr is loop:
    return true
  if any instr is block(bt, [block(bt, _)]):
    return true
  return false

run_remove_unused_names(func):
  if !has_candidate(func.body):
    return unchanged
  run the existing typed rewrite walk
```

## Validation
- Added whitebox tests in `src/optimization/remove_unused_names_wbtest.mbt` for:
  - candidate scan false on a body with no loop or peel shape
  - candidate scan true on a nested same-typed block under a value tree
- Validation run:
  - `moon test src/optimization`
  - `moon build --target native --release src/cmd`

## Fresh-Artifact Checkpoint
- The slice is safe but not sufficient.
- On the current release binary:
  - `_build/native/release/build/cmd/cmd.exe --duplicate-function-elimination --remove-unused-module-elements --memory-packing --once-reduction --dead-code-elimination --remove-unused-names ...`
  - still spent about a minute of CPU on `_build/wasm/release/build/cmd/cmd.wasm`
- So the next hotspot is not just candidate-free functions.

## Next Slice
- Find the remaining expensive shape inside candidate-bearing functions:
  - likely the full rewrite walk itself rather than the old branch-target rescans
- Keep the work on safe analysis / traversal reductions only.
- Do not broaden `RemoveUnusedNames` semantics beyond Binaryen parity to chase speed.
