# `RemoveUnusedNames` Branch-Summary Rework

Status: completed implementation slice; fresh-artifact parity still blocked.

## Scope
- Pass:
  - `RemoveUnusedNames`
- Goal:
  - keep the Binaryen-aligned rewrite surface
  - replace repeated subtree rescans with one memoized branch-target summary per typed body
  - add explicit `try_table` catch-target coverage before the next fresh-artifact parity rerun

## Why This Slice Exists
- The earlier local port already matched the intended rewrite surface:
  - peel same-typed single-child blocks when the removed scopes are not still live targets
  - demote loops to blocks only when no continue edge remains
- The problem was cost:
  - once the generated replay path actually honored `--remove-unused-names`, the large fresh artifact spent minutes inside this pass
  - the hot path was repeated subtree rescans for:
    - `has_branch_to_removed_scope(...)`
    - `has_branch_to_current_scope(...)`
- Binaryen solves this class of problem with one post-walk `branchesSeen` analysis rather than repeated local subtree scans.

## Binaryen Constraint
- Binaryen `RemoveUnusedNames` is still a narrow cleanup pass:
  - clear unused names
  - merge named same-typed single-child blocks
  - retarget branches from removed parent names to the surviving child
  - demote loops only when their name is unused
  - keep `try` handling to break-target bookkeeping
- This slice does not add any broader cleanup rules.
- In particular, it does not reintroduce the earlier speculative result-block demotion work.

## New Local Analysis
- For the typed port, we only need two boolean queries:
  - does this peeled body still target one of the scopes being removed?
  - does this loop body still target the current loop scope?
- Those queries can be answered from one memoized summary per `TExpr`:
  - `min_external_target_depth`
  - `-1` means no branch or catch in the subtree escapes to an outer scope
  - `0` means some branch/catch targets the current enclosing scope
  - `1+` means the nearest escaping target is farther out

### Key Invariant
- The summary is relative to the subtree root, not the raw label index.
- When descending into a control body, one level of label depth becomes internal to that child body.
- So child summaries combine back into the parent by subtracting one external level, not by adding one.

## Pseudocode

```text
min_external_target_depth(expr):
  if cached(expr):
    return cache[expr]

  min_depth = -1
  for instr in expr:
    min_depth = min_nonnegative(min_depth, min_external_target_depth(instr))

  cache[expr] = min_depth
  return min_depth

min_external_target_depth(instr):
  walk label-bearing non-control children normally
  for each seen label:
    note(label_index)

  for block/loop child body:
    note(parent_view(min_external_target_depth(body)))

  for if then/else bodies:
    note(parent_view(min_external_target_depth(then_body)))
    note(parent_view(min_external_target_depth(else_body)))

  for try_table:
    note(parent_view(min_external_target_depth(body)))
    for each catch target:
      note(parent_view(label_index))

parent_view(depth):
  if depth <= 0:
    return -1
  return depth - 1

has_branch_to_removed_scope(body, removed_scopes):
  depth = min_external_target_depth(body)
  return depth >= 0 && depth < removed_scopes

has_branch_to_current_scope(body):
  return min_external_target_depth(body) == 0
```

## Correctness Notes
- `try_table` catch targets must participate in the same summary as plain branches.
- A direct branch to a child block's own scope becomes internal when viewed from the parent and must not block peeling there.
- The memoized summary is only a bookkeeping change:
  - same rewrite rules
  - same label rebasing
  - same loop-demotion rule

## Validation
- Added focused whitebox coverage in `src/optimization/remove_unused_names_wbtest.mbt` for:
  - the existing nested-control live-target bailout
  - a new `try_table` catch target that must also block peeling
- Validation run:
  - `moon test src/optimization`
  - `moon info && moon fmt`
  - `moon test`

## Current Blockers
- Fresh-artifact parity is still not closed.
- Current release-binary replay facts:
  - direct Starshine replay without `RemoveUnusedNames` still fails quickly on a separate post-encode validation bug in `Func 27`, so that direct path is not a trustworthy parity checkpoint yet
  - the current release binary still spends about a minute of CPU on the fresh-artifact shared prefix ending in `RemoveUnusedNames`, so large-artifact runtime is improved in structure but not yet closed
  - the compare harness also still fails to normalize huge outputs because `wasm-opt --print` overflows its current `spawnSync` buffer

## Next Slice
- Add a cheap candidate pre-scan so functions with no block-peel or loop-demotion candidates skip the full rewrite walk entirely.
- After that:
  - rerun the fresh-artifact shared prefix ending in `RemoveUnusedNames`
  - separate any remaining runtime issue from the already-known direct-path post-encode validation bug
