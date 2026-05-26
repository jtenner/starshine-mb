# DAE004 dead-suffix mixed call policy

Date: 2026-05-26

## Scope

Recovery classification slice for the remaining `[DAE004-E]` dead-suffix wording after research note `0633` added live mixed dropped/undropped call coverage.

## Classification

The open question was whether fact-driven dropped-result removal must preserve a callee result when an apparently undropped caller occurs only after a root `unreachable` in the caller.

Current Starshine DAE policy intentionally treats root-unreachable suffixes as dead for this result-removal family. The existing focused regression `dae-optimizing ignores undropped calls in root-unreachable dead suffixes` proves the accepted behavior:

- `$f` has a result initially.
- One live caller executes `call $f; drop`.
- Another caller reaches `unreachable` before an undropped `call $f`.
- DAE removes `$f`'s result, keeps the dead-suffix caller valid, and strips the unreachable suffix call.

That behavior is consistent with the broader DAE cleanup contract: dead suffixes after root `unreachable` are not live observations of the callee result. The live mixed-call guard from `0633` remains the protection for callers that can actually observe the result.

## Outcome

`[DAE004-E]` is closed as a classification/test-coverage slice without optimizer behavior changes:

- live mixed dropped/undropped calls preserve the callee result (`0633`);
- root-unreachable undropped suffix calls do not block result removal because they are dead by the existing DAE policy;
- future changes to treat such suffixes as blockers would be a policy change and need new focused tests plus artifact/fuzz evidence.

## Validation

No pass logic changed in this slice. Existing focused coverage is in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing preserves fact-discovered results with mixed dropped and live callers`
- `dae-optimizing ignores undropped calls in root-unreachable dead suffixes`

Final validation for this docs/backlog recovery slice should include `moon info`, `moon fmt`, and `moon test`.
