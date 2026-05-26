# DAE003-C local carrier negative guards

## Scope

This slice keeps `[DAE003-C]` open but closes two of the focused negative-test gaps left by [`0639`](0639-2026-05-26-dae003-non-adjacent-local-set-carrier.md):

- `local.tee` carrier prefixes are rejected because the tee both writes and leaves an additional stack value; broad materialization through that shape needs separate stack-shape proof.
- multiple writes to the same carrier local before the call actual are rejected because the narrow recognizer is intentionally limited to one prior constant-producing `local.set` with no earlier same-local read, tee, or duplicate write.

## Evidence

Added focused tests in [`../../../src/passes/dae_optimizing_test.mbt`](../../../src/passes/dae_optimizing_test.mbt):

- `dae-optimizing rejects non-adjacent local-tee constant actual carrier`
- `dae-optimizing rejects non-adjacent local-set carrier with multiple writes`

Both tests build high-module fixtures around target defined function `1500`, matching the positive non-adjacent local-set carrier lane from note `0639`, and assert the target parameter is preserved (`params.length() == 1`) with the caller-side carrier still present.

## Validation

- `moon test src/passes` passed after fixing the first `local.tee` fixture to drop the tee result before the call actual.

## Remaining DAE003-C work

`[DAE003-C]` still needs broader negative and positive coverage before closure: effecting or trapping carrier prefixes if policy requires rejecting them, self/escaped cycles, multiple reads beyond the current prefix guard, and structured carriers that are tracked under `[DAE003-F]`.
