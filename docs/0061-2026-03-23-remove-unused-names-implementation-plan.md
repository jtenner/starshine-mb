# `RemoveUnusedNames` Implementation Plan

Status: active implementation plan for the next shared default-pipeline pass after `DeadCodeElimination`.

## Scope
- Pass:
  - `RemoveUnusedNames`
- Current local state:
  - scheduled in the default grouped function stage
  - dispatched through the generic func-local no-op shell in `src/optimization/optimization.mbt`
- Comparison target:
  - Binaryen `remove-unused-names` behavior as exercised in the explicit shared fresh-artifact prefix after `DFE -> RemoveUnusedModuleElements -> MemoryPacking -> OnceReduction -> DeadCodeElimination`
- Goal:
  - replace the current no-op with the intended typed-IR cleanup semantics
  - land the work in small validated slices
  - rerun the extended fresh-artifact prefix against Binaryen after completion

## Current Behavior

Current dispatch:

- `OptimizePass::RemoveUnusedNames` is classified as `FuncLocal`
- `make_entry_kind(...)` only special-cases `DeadCodeElimination`
- `RemoveUnusedNames` therefore currently runs as `noop_func_local_pass`

Practical consequence:

- the grouped default stage claims `DeadCodeElimination -> RemoveUnusedNames -> RemoveUnusedBrs -> ...`
- but the local pipeline only executes `DeadCodeElimination`; `RemoveUnusedNames` currently contributes no typed cleanup

## Intended Pass Semantics

On the current typed IR surface, the pass should do two things:

1. Peel redundant same-typed nested blocks:
   - if a `block bt` contains exactly one child instruction and that child is also `block bt`, the inner scope can be removed
   - when scopes are removed, branch labels inside the peeled body must be rebased
   - peeling must be skipped when a removed scope is still the target of a nested branch/catch that would change meaning after rebasing

2. Rewrite loops with no remaining continue target:
   - if a `loop bt body` has no branch targeting its own scope, it behaves like a `block bt body`
   - this applies to both void and value-producing loops on the current typed surface

This matches the historical local implementation and the Binaryen-facing cleanup intent: remove now-useless names/scopes without changing control-flow meaning.

## How The Pass Works

### Same-Typed Block Peeling

Input shape:

```text
block bt {
  block bt {
    body
  }
}
```

If the outer body has exactly one child block with the same `BlockType`, the outer and inner scopes are redundant. The pass peels the child body upward and then rebases branch labels inside that body to account for the removed scopes.

Key rule:

- if rebasing would retarget a branch that still semantically depends on one of the removed scopes, do not peel

### Loop Demotion

Input shape:

```text
loop bt {
  body
}
```

If `body` contains no branch to loop depth `0`, the loop has no continue edge left. It can be rewritten as:

```text
block bt {
  body
}
```

This is a structural cleanup, not a strength reduction: it is only valid when the loop label is unused.

## Pseudocode

```text
run_remove_unused_names(module):
  for each typed function body:
    repeat one structural walk:
      walk instructions bottom-up
      when visiting block(bt, body):
        peeled_scopes, peeled_body = peel_same_typed_child_blocks(bt, body)
        if peeled_scopes > 0:
          if has_branch_to_removed_scope(peeled_body, removed_scopes=peeled_scopes):
            keep original block
          else:
            rebased = rebase_labels_for_removed_scopes(peeled_body, peeled_scopes)
            replace with block(bt, rebased)
      when visiting loop(bt, body):
        if has_branch_to_current_scope(body) == false:
          replace with block(bt, body)
    if function body changed:
      store rewritten typed body
```

Supporting helpers:

```text
peel_same_typed_child_blocks(bt, body):
  removed = 0
  current = body
  while current == [block(child_bt, child_body)] and child_bt == bt:
    removed += 1
    current = child_body
  return removed, current

rebase_label(label, depth, removed_scopes):
  if label < depth:
    return label
  if label <= depth + removed_scopes:
    return depth
  return label - removed_scopes

has_branch_to_current_scope(body):
  return any branch/catch in body whose target depth == 0

has_branch_to_removed_scope(body, removed_scopes):
  return any branch/catch in body whose target depth is within the scopes that peeling would erase
```

## Correctness Constraints
- Never peel blocks when a removed scope is still a live control-flow target.
- Preserve value branch arity when rebasing typed `br` payloads.
- Do not demote loops that still contain any continue edge.
- Restrict this port to the current typed IR surface; do not invent EH/pop semantics that are not yet modeled elsewhere.
- Keep the implementation typed-only for now. The generated pipeline already pre-lifts raw functions before the grouped function stage.

## Validation Plan
1. Add typed whitebox regressions for:
   - no-candidate no-op
   - same-typed single-child block peeling
   - branch-depth rebasing after peeling
   - branch-to-removed-scope bailout
   - loop-to-block demotion
   - loop preservation when `br 0` remains
2. Wire `OptimizePass::RemoveUnusedNames` to a dedicated func-local runner.
3. Run `moon info && moon fmt` and `moon test`.
4. Rerun the fresh-artifact explicit prefix:
   - Starshine:
     - `DFE -> RemoveUnusedModuleElements -> MemoryPacking -> OnceReduction -> DeadCodeElimination -> RemoveUnusedNames`
   - Binaryen:
     - same explicit ordered prefix with `--remove-unused-names`
5. Compare:
   - byte size
   - validation
   - printed WAT for first concrete divergence if sizes still differ

## Performance Impact
- On large modules this pass should remove redundant control scopes and enable later cleanup passes to see simpler structure.
- The immediate size effect may be small on the fresh artifact, but it should no longer be a hard no-op in the shared prefix.
- The historical implementation used candidate and walk budgets; start with the simpler semantics-first port, then add budgeting only if needed.

## Implementation Slices

### Slice 1: Runner wiring and same-typed block peeling
- Add the dedicated `run_remove_unused_names` func-local runner in `src/optimization/optimization.mbt`
- Port:
  - block-peeling helper
  - label rebasing helper
  - focused typed regressions for no-op, peel, and branch-depth rebasing

### Slice 2: Live-target bailout
- Add the scan that detects branches/catches targeting removed scopes
- Port the regression that keeps the nested `if` / branch-target shape unchanged when peeling would retarget a live scope incorrectly

### Slice 3: Loop demotion
- Add loop-to-block demotion when no continue target remains
- Port both sides of the behavior:
  - loop demotes when no `br 0` survives
  - loop stays a loop when a continue branch is still present

### Slice 4: Fresh-artifact parity replay
- Run the explicit shared prefix through Starshine and Binaryen
- Record:
  - whether `RemoveUnusedNames` is now a real parity checkpoint or another clean no-op on the fresh artifact
  - any first remaining divergence and whether it is correctness, optimization coverage, or serializer/layout drift

## Open Questions
- Does the fresh rebuilt release artifact actually exercise any `RemoveUnusedNames` rewrite after the DCE-generated-prelift cleanup, or is the next real shared blocker later again?
- Are catch-target rebases needed immediately on the current typed surface, or do the fresh artifact and focused regressions stay within plain branch coverage?
- If the historical candidate/walk budgets are still needed, what is the smallest defensible version to reintroduce after semantics parity is closed?
