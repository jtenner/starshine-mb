# DAE004 mixed live call guard

Date: 2026-05-26

## Scope

Recovery slice for `[DAE004-E]`, focused on making the existing fact-driven dropped-result scheduler guard explicit for mixed dropped/live direct callers.

## Test-first result

Added `dae-optimizing preserves fact-discovered results with mixed dropped and live callers` in `src/passes/dae_optimizing_test.mbt`.

The fixture has a private `$target (param i32) (result i32)` with one exported caller that immediately drops `$target`'s result and another exported caller that returns `$target`'s result. The expected behavior is to preserve `$target`'s result signature and leave the dropped call/drop pair intact, because not all direct calls drop the result.

The guard already passes on the current implementation, so this slice does not change optimizer behavior. It protects the contract implemented by current call facts plus `dae_try_remove_dropped_results(...)`: result removal is allowed only when the current direct-call count is nonzero and equals the dropped-call count, with an additional undropped-call scan before rewriting.

## Dead-suffix note

A speculative stricter guard for undropped calls after a root `unreachable` was tried during recovery and failed against current behavior. Existing DAE policy intentionally treats root-unreachable suffixes as dead for several no-param/result cleanup paths (for example, `dae-optimizing ignores undropped calls in root-unreachable dead suffixes`). Therefore this slice does not close the dead-suffix portion of `[DAE004-E]`; that part needs a separate classification that reconciles the backlog wording with the existing dead-suffix cleanup policy before any behavior change.

## Validation

- `moon test src/passes` initially failed with the speculative dead-suffix guard (`0 != 1` for the preserved result assertion), confirming that part is not current behavior.
- Final validation for the committed slice should include `moon test src/passes`, `moon info`, `moon fmt`, and `moon test`.

## Status

`[DAE004-E]` is partially advanced, not closed. Live mixed dropped/undropped direct-call result preservation now has focused coverage. Remaining work: classify and, if needed, test the dead-suffix policy for mixed dropped/undropped calls without contradicting existing accepted DAE cleanup behavior.
