# DAE004 dead-suffix call-drop repair coverage

Date: 2026-05-26

## Scope

Recovery picked `[DAE004-F]`: add or refresh coverage proving DAE repairs `call; drop` sites after a callee result is removed, including root-unreachable suffixes that are safe to rewrite.

## Evidence

Existing coverage already protected the simplest root-unreachable dropped-call suffix:

- `dae-optimizing collapses dropped dead-suffix calls when removing result` removes `$f`'s result and deletes the caller's dead-suffix `call $f; drop` after an `unreachable` prefix.

This slice adds a second focused regression in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing repairs live-prefix dead-suffix call drops after result removal` keeps a live prefix call to `$side`, removes `$f`'s now-unobserved result, and proves the post-unreachable `call $f; drop` suffix is deleted while the live prefix remains.

The new test passed on current code, so no optimizer behavior changed. That is acceptable for `[DAE004-F]` because the subtask allowed refreshed coverage rather than requiring a behavior change.

## Validation

- `moon test src/passes` passed: `1391/1391` tests.
- Commit-ready quick signoff passed: `moon info`, `moon fmt`, and `moon test` (`3463/3463` tests).

## Classification

Agent classification: coverage-only closure. The protected behavior is semantic-safe because all removed caller instructions are in a suffix dominated by root `unreachable`; the live side-effecting prefix remains in the test, and the callee result rewrite is already guarded by current DAE dropped-result rules.

## Backlog update

Mark `[DAE004-F]` closed. `[DAE]004` remains open for `[DAE004-D]`, `[DAE004-G]`, `[DAE004-H]`, and `[DAE004-I]`.
