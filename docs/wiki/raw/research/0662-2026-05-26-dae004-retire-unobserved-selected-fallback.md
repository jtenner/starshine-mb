# DAE004 retire unobserved selected dropped-result fallback

Date: 2026-05-26

## Scope

Recovery continuation for open `[DAE]004`, specifically `[DAE004-D]` selected fallback entry retirement.

This slice removes the stale selected dropped-result fallback entry for defined function `3799`. Research note `0628` identified `3799` as the only entry in the handpicked selected dropped-result fallback list that was not observed as productive in the latest debug-artifact trace, while every still-productive fallback entry remained blocked by large-module ordering plus the eight-productive-attempt cap in note `0629`.

## Test-first evidence

Added a white-box guard in `src/passes/dead_argument_elimination_wbtest.mbt`:

- `dae selected dropped-result fallback skips unobserved Func3799`

The initial focused pass-suite run failed as expected because `dae_selected_dropped_result_fallback_neighborhood_defs()` still contained `3799`:

```text
moon test src/passes
FAILED: `true` is not false
```

## Implementation

Removed `3799` from both selected dropped-result fallback lists in `src/passes/dead_argument_elimination.mbt`:

- `dae_selected_dropped_result_fallback_neighborhood_defs()`
- the active selected dropped-result fallback loop in `dae_run_core`

This is a conservative fallback deletion: it removes one artifact-specific handpicked retry that current tracing did not observe as productive. The fact-driven candidate lanes remain responsible for principled dropped-result discovery.

## Validation

- Test-first `moon test src/passes` failed on the new white-box guard before implementation.
- `moon test src/passes` passed after implementation: `1417` tests, `0` failures.

Full artifact timing, direct compare refresh, and broad fallback deletion are still required before closing `[DAE004-D]`, `[DAE004-H]`, or `[DAE004-I]`.

## Remaining work

`[DAE004-D]` remains open for the productive fallback families: `298`, `299`, `427`, `445`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `3834`, `4106`, `4229`, `4232`, `503`, `4240`, `4241`, `4242`, and `4249`. Next behavior-changing slices should add trace metadata and/or a narrower family-specific bucketed path, then prove artifact validation, pass-local timing inside the DAE011 target, and direct compare stability before deleting another fallback entry.
