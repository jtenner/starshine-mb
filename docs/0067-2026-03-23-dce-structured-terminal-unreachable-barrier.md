# DCE Structured Terminal Unreachable Barrier

## Scope

- Fix the remaining `DeadCodeElimination` correctness blocker on the fresh release artifact.
- Preserve valid optimization opportunities instead of disabling structured dead-tail truncation.
- Match Binaryen's safety boundary: non-fallthrough control can be cleaned up aggressively, but the emitted raw Wasm must still validate.

## Current Behavior

Starshine DCE was truncating typed expression tails after structured instructions that were proven semantically non-fallthrough:

- `block`
- `if`
- `try_table`

That was correct at the typed/control-flow level, but the lowered raw Wasm was invalid in a specific family:

```wat
(block
  ;; body does not fall through at runtime
  ...
)
;; removed by DCE
<required terminal barrier>
```

Raw Wasm does not treat a plain `block` or `if` as terminal just because all inner paths return, branch out, or trap. If code after that structured instruction is removed, the enclosing raw sequence still needs an explicit terminal barrier.

## Reduced Repro

Input:

```wat
(module
  (func $side (param i32)
    local.get 0
    drop)
  (func (export "run") (param i32) (result i64)
    block
      block (result i32)
        block
          i32.const 1
          if (result i32)
            i32.const 1
            if (result i32)
              local.get 0
            else
              local.get 0
              call $side
              br 2
            end
          else
            local.get 0
            call $side
            br 1
          end
          br 1
        end
        i64.const 42
        return
      end
      i64.const 0
      return
    end
    i64.const 1))
```

Before the fix, Starshine `--dead-code-elimination` removed the trailing `i64.const 1` and emitted an invalid function ending at the outer `block`.

After the fix, Starshine emits:

```wat
(func (param i32) (result i64)
  block
    ...
  end
  unreachable)
```

This preserves the dead-tail optimization while making the non-fallthrough explicit in raw form.

## Binaryen Comparison

Binaryen does not rely on the structured instruction itself being terminal in raw form. On the reduced repro it keeps a validating explicit continuation after the rewritten structure rather than assuming the `block` alone is enough.

That is the important parity rule:

- Binaryen may simplify non-fallthrough structure.
- Binaryen still emits validating raw Wasm.
- Starshine should preserve the optimization, but must also preserve an explicit raw non-fallthrough barrier.

## Root Cause

`optimization_dead_code_elimination_truncate_after_first_unreachable` was using `optimization_dead_code_elimination_instr_terminates_current_expr` to decide where to cut off an enclosing typed expression.

That is valid for:

- `unreachable`
- `return*`
- `throw*`
- direct branch-family terminals

But it is not enough for raw lowering when the terminating item is a structured instruction.

The missing step was:

```text
if structured instruction is semantically non-fallthrough:
  keep the instruction
  append explicit unreachable
  truncate later siblings
```

## Implemented Change

In `src/optimization/optimization.mbt`:

- `optimization_dead_code_elimination_truncate_after_first_unreachable` now appends `TUnreachable` after a terminating structured instruction before truncating later siblings.
- New helper:
  - `optimization_dead_code_elimination_instr_needs_unreachable_barrier`

It currently applies to:

- `TBlock`
- `TIf`
- `TTryTable`

Pseudo-code:

```text
for instr in expr:
  keep instr
  if instr terminates current expr:
    if instr is structured and only semantically terminal:
      keep unreachable
    break
```

## Correctness Constraints

- Do not remove the optimization route.
- Do not weaken DCE into "leave all trailing code alone".
- Preserve validation of lowered raw Wasm, not just typed IR.
- Keep direct branch/return/throw cases unchanged; they already encode as explicit raw terminals.

## Validation

Code checks:

- `moon info && moon fmt`
- `moon test`
- `moon build --target native --release src/cmd`

Focused repro checks:

- Reduced raw repro after Starshine `--dead-code-elimination` now validates with `wasm-tools`.
- Fresh artifact direct `--dead-code-elimination` now validates:
  - Starshine: `2517968`
  - Binaryen `--all-features --dce`: `2534636`
- Fresh artifact shared five-pass prefix now validates:
  - Starshine: `2352767`
  - Binaryen `--all-features --duplicate-function-elimination --remove-unused-module-elements --memory-packing --once-reduction --dce`: `2374783`

## Performance Impact

- No new global analysis.
- One extra local decision during truncation.
- Possible extra emitted `unreachable` nodes in reduced bodies.

This is negligible compared with the existing DCE walk.

## Open Questions

- The remaining Binaryen delta is now output-shape / size parity, not a validation blocker.
- Starshine is currently smaller than Binaryen on the fresh artifact at these two checkpoints; verify that difference is entirely safe and not hiding another validator blind spot.
- After this correctness fix, the next parity slice should compare normalized output for the direct DCE checkpoint and decide whether any remaining difference belongs in DCE itself or in later cleanup/canonicalization passes.
