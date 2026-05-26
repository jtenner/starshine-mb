# DAE003 self/escaped local-carrier policy

Date: 2026-05-26

## Scope

This note advances `[DAE003-C]` and closes `[DAE003-E]` for the current non-adjacent local-set carrier surface by making the self/escaped-cycle policy executable.

The policy is intentionally conservative: the new non-adjacent carrier recognizer may materialize a straight-line `const; local.set; local.get; call` actual only for a private direct callee that does not participate in the inspected self-recursive/escaped carrier families. Direct simple self-recursive operand pruning from `[DAE]001` and the case-000690 escaped self-call operand preservation rule remain the governing behavior for those older surfaces.

## Tests

Added two focused regressions in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing rejects non-adjacent self-recursive local-set constant cycle`
  - Shape: a private `$target` recursively calls itself through `i32.const 77; local.set 0; local.get 0; call $target`.
  - Expected result: preserve `$target`'s parameter and keep the self-call/local carrier in the body.
- `dae-optimizing rejects non-adjacent local carrier when callee escapes through ref.func`
  - Shape: `$target` has a `ref.func` escape through an exported function and a separate non-adjacent local carrier caller.
  - Expected result: preserve `$target`'s parameter and keep the caller's local carrier.

Both tests passed on the current implementation, so no optimizer behavior change was required.

## Result

For the current DAE003 local-carrier slice, the supported positive surface remains the narrow private direct-call `const; local.set; local.get; call` family from note `0639`. The negative policy now explicitly covers `local.tee`, multiple same-local writes, earlier same-local reads, trapping producers, effectful producers, self-recursive local-carrier cycles, and `ref.func` escapes.

`[DAE003-E]` is closed for this current conservative safe subset. Broader recursive-cycle materialization would be a new behavior-widening slice requiring positive and negative tests plus artifact/fuzz evidence.

`[DAE003-C]` still needs closeout validation/classification after any remaining structured-carrier decision, and broader structured carriers remain tracked by `[DAE003-F]`.

## Validation

- `moon test src/passes` passed (`1400` tests).
