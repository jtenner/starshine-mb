# DCE concrete-block wrapper preservation

## Scope
- Diagnose the next `DeadCodeElimination` parity blocker after the `if` label-depth fix.
- Reduce the fresh-artifact failure to a small raw-valid shape.
- Keep Starshine aligned with Binaryen’s local DCE behavior by preserving label depth when demoting concrete blocks.

## Current behavior
- The reduced raw-valid shape is:

```wat
(block (result i32)
  (block
    (block (result i32)
      (i32.const 1)
      (if
        (then br 2)
        (else
          (i32.const 0)
          return))
      (i32.const 5)
      br 0))
  (i32.const 7))
```

- DCE correctly removes the dead `i32.const 5; br 0` tail.
- Before this slice, Starshine then made one of two wrong follow-up rewrites:
  - keep the inner block concrete, which leaves a stale result in an enclosing `void` block on the raw path
  - or drop the block wrapper entirely when the rewritten body collapses to a single `if`, which shifts branch depths on the typed path

## Root cause
- `optimization_dead_code_elimination_rewrite_block` was using one rule for all escaping concrete blocks:

```text
if block escapes parent and block is concrete:
  if rewritten body has exactly one child:
    replace block with child
  else:
    retag block as void
```

- That is only safe when removing the block cannot change branch targets.
- In the reduced shape, the surviving `br 2` still depends on the demoted block contributing one label depth between the `if` body and the outer `void` block.
- Replacing the block with its lone child changes that `br 2` into a branch to the enclosing result block instead.

## Fixed behavior
- Escaping concrete blocks with no live breaks to their own label still demote away from the concrete result type.
- But single-child replacement now only happens when the body has no live breaks past the current label.
- If a surviving child still branches outward, Starshine keeps a `void` block wrapper so label depth stays stable.

## Pseudocode

```text
rewrite_block(block_type, body):
  if not block_escapes_parent(block_type, body):
    return block(block_type, body)

  if block_type is not concrete:
    return block(block_type, body)

  if body has one child:
    if body has live break past current label:
      return block(void, body)
    return child

  return block(void, body)
```

## Correctness constraints
- Demoting a concrete block is safe only if no live path still needs that block’s own result label.
- Replacing a block with its single child is safe only if doing so cannot rebind outward branch targets.
- Keeping a `void` wrapper is sufficient here because DCE already proved the current block result is dead.

## Validation plan
- Typed whitebox regressions in `src/optimization/dead_code_elimination_wbtest.mbt` now cover:
  - no live break to the current label for the reduced body
  - retagging concrete blocks when only outer breaks remain
- Generated-path regression in `src/cmd/generated_pipeline_wbtest.mbt` ensures the reduced raw fixture stays encodable after `--dead-code-elimination`.
- Rebuild `src/cmd`, rerun direct `--dead-code-elimination` on `_build/wasm/release/build/cmd/cmd.wasm`, and confirm the first failure moves forward again.

## Performance impact
- None intended.
- The new guard reuses the existing `expr_has_live_break_past_current_label` analysis and only changes the single-child rewrite choice.

## Open questions
- The fresh direct-DCE artifact replay now gets past the earlier `func 407` blocker and first fails later at `func 448`.
- Rerun the five-pass prefix after this slice and reduce the new first failing shape before taking another parity conclusion.
