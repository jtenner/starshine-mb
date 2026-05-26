# DAE004 selected fallback trace metadata

Date: 2026-05-26

## Scope

Recovery/completion slice for `[DAE004-D1]`: make selected dropped-result fallback attempts visible enough to group remaining productive fallback entries before deleting or replacing them.

## Test-first evidence

Added `dae-optimizing traces selected dropped-result fallback metadata` in `src/passes/dae_optimizing_test.mbt`.

Before implementation:

```sh
moon test src/passes -f 'dae-optimizing traces selected dropped-result fallback metadata' --target native
```

failed because the DAE trace only reported coarse core/selected-lane events and did not emit a selected dropped-result candidate metadata line.

## Implementation

`src/passes/dead_argument_elimination.mbt` now emits `pass[dae-optimizing]:selected-dropped-result-candidate ...` before each handpicked selected dropped-result fallback attempt. The line records:

- selected fallback defined-function index (`def`)
- absolute callee index (`callee_abs`)
- current direct caller defs (`callers`)
- current direct and dropped call counts (`direct`, `dropped`)
- current live-call count derived from those facts (`live`)
- dead-suffix classification placeholder (`dead_suffix=unknown`)
- fact source (`facts=current`)
- bucket membership (`bucket=selected-fallback`)
- whether the fact-driven lane had already attempted the candidate in this trace (`fact_attempted=false` for the current first metadata slice)

The placeholder fields keep the trace schema stable for `[DAE004-D2]` grouping without changing optimizer behavior in this slice.

## Validation

After implementation:

```sh
moon test src/passes -f 'dae-optimizing traces selected dropped-result fallback metadata' --target native
```

passed (`1` test). Existing unused-helper warnings from pass-manager files remain unrelated.

## Status

`[DAE004-D1]` is complete for the current metadata schema. `[DAE004-D2]` should use artifact traces to group productive selected entries by observed caller/fact/bucket behavior before choosing one smallest family for replacement.
