# DAE004 seven high descending candidates

## Scope

Recovery/completion slice for `[DAE]004` selected result-removal broadening. The previous slice raised the large-module descending fact-driven dropped-result scheduler to six productive candidates for `4096 < defined <= 8192`, but `[DAE]004` remained open because the handpicked selected-def fallback was still required for remaining artifact result-removal families.

## Test-first failure

Updated the focused large-module starvation regression in `src/passes/dae_optimizing_test.mbt` from six to seven high dropped-result callees after forty low dropped-result candidates:

- test: `dae-optimizing reaches seven high dropped-result callees after low candidate budget`
- command: `moon test src/passes`
- before implementation: failed with the seventh high target still reporting one result (`1 != 0`).

## Implementation

Raised the large-module descending fact-driven dropped-result cap in `src/passes/dead_argument_elimination.mbt` from six to seven productive candidates for `4096 < defined <= 8192`.

The existing behavior remains unchanged for:

- ascending fact-driven queue for `defined <= 4096`;
- handpicked selected-def fallback after the bounded fact-driven queue;
- private/non-tail/all-current-direct-calls-dropped guards;
- caller-filtered result-removal helper and signature/type-liveness safeguards.

## Validation

Focused pass suite after implementation:

```text
moon test src/passes
Total tests: 1385, passed: 1385, failed: 0.
```

Focused regression after implementation:

```text
moon test src/passes -f "dae-optimizing reaches seven high dropped-result callees after low candidate budget"
Total tests: 1, passed: 1, failed: 0.
```

Quick signoff:

```text
moon info
Finished. moon: ran 1 task, now up to date
moon fmt
Finished. moon: ran 2 tasks, now up to date
moon test
Total tests: 3457, passed: 3457, failed: 0.
```

Artifact timing/validation and 10k direct compare should be run before closing or broadening `[DAE]004` further.

## Status

`[DAE]004` remains open. The next slice should add focused coverage for the next missed candidate-ordering family or prove that the selected-def fallback can be removed without reopening artifact validity or pass-local runtime cliffs.
