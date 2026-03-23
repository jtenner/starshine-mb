# DCE Recursive Dead Terminal Result Cleanup

## Scope

- Keep moving direct `DeadCodeElimination` parity forward on the fresh release artifact.
- Preserve Binaryen-style dead-result cleanup without globally retagging nested structured instructions in operand position.
- Fix the next fresh-artifact blocker by making dead-result cleanup follow the terminal structured chain created by truncation.

## Current Behavior

After the earlier structured-terminal barrier and type-canonicalization slices, direct fresh-artifact `--dead-code-elimination` still hit a correctness blocker in a function shaped like:

```text
if (void)
  then:
    loop (result T)
      ...
  else:
    return ...
unreachable
```

The enclosing `if` result was already dead under truncation, but Starshine only dropped the dead result type at the outermost structured instruction. Nested terminal structured children in the taken arm could still keep a dead concrete result type, which later failed during binary lowering.

## Binaryen Comparison

Binaryen’s DCE is tree-based and uses `TypeUpdater` as it rewrites control structure types. The important parity point here is not “retag every nested structured node aggressively”, but:

- when a terminal result becomes dead because the enclosing expression is truncated,
- Binaryen keeps cleaning that dead result type through the structured chain,
- while still preserving valid IR.

Our previous local `rewrite_if(...)` experiment was too broad for the local typed stack IR because it changed nested operand-position `if`s even when the enclosing expression had not yet proven their result dead. The correct repair point is the truncation boundary itself.

Source:
- Binaryen DCE source: https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DeadCodeElimination.cpp

## Root Cause

`optimization_dead_code_elimination_truncate_after_first_unreachable(...)` already knew when an enclosing expression was being cut off after a terminal `if` / `block` / `try_table`. But its dead-result cleanup only rewrote the single outer instruction.

That missed the next nested terminal result-carrier, for example:

```text
if (void)
  then:
    loop (result i32)
      ...
  else:
    return
unreachable
```

Once the enclosing `if` is terminal and the rest of the sequence is dead, the loop result is dead too. Leaving the loop concrete can still force invalid raw lowering later.

## Implemented Change

In [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt):

- `optimization_dead_code_elimination_truncate_after_first_unreachable(...)` now runs dead-result cleanup before keeping the terminal structured instruction.
- New helper:
  - `optimization_dead_code_elimination_drop_dead_terminal_expr_result(...)`
- `optimization_dead_code_elimination_drop_dead_structured_result(...)` now recursively follows the terminal structured chain:
  - `if`
  - `block`
  - `loop`
  - `try_table`

Pseudo-code:

```text
truncate expr after first terminal child
if kept terminal child is structured:
  drop its dead result type
  if that exposes a dead terminal child expr result:
    recurse into the last child expression
append explicit unreachable barrier when raw lowering still needs one
```

## Correctness Constraints

- Do not globally retag nested structured instructions at generic rewrite time.
- Only drop nested result types when the enclosing expression has already proven that result dead.
- Keep the optimized typed module validating in local whitebox fixtures.
- Treat this as a truncation-boundary cleanup rule, not as a new generic control-flow simplifier.

## Validation

Code checks:

- `moon test src/optimization`

Focused regressions:

- `dead code elimination retags concrete if when both arms only break out to parent`
- `dead code elimination may retag nested result-typed ifs whose arms escape an outer label`

Fresh artifact checkpoint:

- before this slice, direct fresh-artifact `--dead-code-elimination` first failed at `Func 27`
- after this slice, that blocker is gone
- the next direct fresh-artifact blocker is now later at `Func 716`

## Performance Impact

- No new whole-function scan.
- The recursive cleanup only runs on the terminal structured chain of an expression that DCE is already truncating.
- This is bounded by nesting depth, not by repeated subtree rescans.

## Open Questions

- The next direct artifact blocker is now a later nested `block (result ...)` family around `Func 716`.
- Once that later blocker is fixed, rerun the direct and five-pass checkpoints again to see whether the remaining gap is still correctness or has become pure Binaryen parity drift.
