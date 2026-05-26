# DAE004 eight high descending candidates

## Scope

Recovery/completion slice for `[DAE]004` selected result-removal broadening. The previous slice raised the large-module descending fact-driven dropped-result scheduler to seven productive candidates for `4096 < defined <= 8192`; `[DAE]004` remained open because the handpicked selected-def fallback was still required for remaining artifact result-removal families.

## Test-first failure

Updated the focused large-module starvation regression in `src/passes/dae_optimizing_test.mbt` from seven to eight high dropped-result callees after forty low dropped-result candidates:

- test: `dae-optimizing reaches eight high dropped-result callees after low candidate budget`
- command: `moon test src/passes -f "dae-optimizing reaches eight high dropped-result callees after low candidate budget"`
- before implementation: failed with the eighth high target still reporting one result (`1 != 0`).

## Implementation

Raised the large-module descending fact-driven dropped-result cap in `src/passes/dead_argument_elimination.mbt` from seven to eight productive candidates for `4096 < defined <= 8192`.

The existing behavior remains unchanged for:

- ascending fact-driven queue for `defined <= 4096`;
- handpicked selected-def fallback after the bounded fact-driven queue;
- private/non-tail/all-current-direct-calls-dropped guards;
- caller-filtered result-removal helper and signature/type-liveness safeguards.

## Validation

Focused regression before implementation failed as expected:

```text
moon test src/passes -f "dae-optimizing reaches eight high dropped-result callees after low candidate budget"
FAILED: `1 != 0`
Total tests: 1, passed: 0, failed: 1.
```

Focused regression and pass suite after implementation:

```text
moon test src/passes -f "dae-optimizing reaches eight high dropped-result callees after low candidate budget"
Total tests: 1, passed: 1, failed: 0.

moon test src/passes
Total tests: 1385, passed: 1385, failed: 0.
```

Quick signoff is recorded in the commit/report for this slice. Artifact timing/validation and 10k direct compare should be run before closing `[DAE]004` or broadening selected-fallback removal further.

## Status

`[DAE]004` remains open. The next slice should add focused coverage for the next missed candidate-ordering family or prove that the selected-def fallback can be removed without reopening artifact validity or pass-local runtime cliffs.
