# DCE parent-continuation escape analysis

## Scope
- Tighten `DeadCodeElimination`'s block escape classification for nested control flow.
- Distinguish true block escapes from branches that only jump to the immediate parent continuation.
- Keep the change limited to local escape analysis, without adding new cleanup rewrites.

## Current behavior
- Before this slice, `optimization_dead_code_elimination_block_escapes_parent` only blocked escape classification when the body had a live break to label `0`, the current block itself.
- That missed a second safe case: a nested child can branch to label `1`, the immediate parent continuation, and later siblings in the current block are still reachable.

## Root cause
- The old rule was:

```text
block_escapes_parent(body):
  if tail does not escape:
    return false
  return not has_live_break_to_label(body, 0)
```

- That is incomplete.
- A branch to label `1` from within a nested child still resumes at the current block body after that child completes.
- So later siblings in the current block remain live, and the block must not be treated as escaping its parent yet.

## Fixed behavior
- The escape predicate now requires both of these to be absent:
  - a live break to label `0` anywhere in the body
  - a live break to label `1` in the body prefix before the tail instruction

## Pseudocode

```text
block_escapes_parent(body):
  if body is empty:
    return false
  if tail does not escape enclosing expr:
    return false
  if has_live_break_to_label(body, 0):
    return false
  if body has at most one instruction:
    return true
  return not has_live_break_to_label(prefix_without_tail(body), 1)
```

## Correctness constraints
- A live break to label `0` means the block can still complete through its own label.
- A live break to label `1` only matters when it happens before the tail instruction, because that means a nested child can still rejoin the current block body and reach later siblings.
- A tail instruction that branches to label `1` still escapes the parent expression, because there are no later siblings left to preserve.

## Validation plan
- Whitebox regressions in `src/optimization/dead_code_elimination_wbtest.mbt` cover:
  - deep current-label breaks through nested blocks and `if`s
  - stacked-`if` current-label breaks
  - deep parent-label breaks through nested `if`s
- Run `moon info && moon fmt` and `moon test`.

## Performance impact
- Negligible.
- The extra check reuses the existing `has_live_break_to_label` scan with a different target depth.

## Open questions
- This fixes one missing escape-analysis condition, but it does not yet resolve the current fresh-artifact `func 448` / `func 444` DCE parity blocker.
- The next step is to reduce the remaining valid payload-loss shape to a generated-path regression before changing any more DCE rewrite logic.
