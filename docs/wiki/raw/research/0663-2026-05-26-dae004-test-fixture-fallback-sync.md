# DAE004 test fixture fallback sync

Date: 2026-05-26

## Scope

Recovery continuation for open `[DAE]004`, specifically the `[DAE004-D]` selected dropped-result fallback retirement follow-up after note `0662`.

Note `0662` removed unobserved selected dropped-result fallback entry `3799` from the implementation and added a white-box guard that `dae_selected_dropped_result_fallback_neighborhood_defs()` no longer contains it. This follow-up removes the same stale entry from the broader black-box fixture list named `dae-optimizing removes selected mid-prefix dropped callee results` so the test inventory no longer advertises `3799` as an active selected fallback family.

## Test-first evidence

The prior `0662` white-box guard is the behavior guard for this cleanup. This slice is a fixture/docs consistency cleanup, not an optimizer behavior change, so no new intentionally failing behavior test was added.

## Implementation

Updated `src/passes/dae_optimizing_test.mbt` to remove `3799` from the selected mid-prefix dropped-result fixture list. The remaining fixture entries match the currently documented productive fallback families: `299`, `427`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `3834`, `4106`, `4229`, `4232`, `4240`, `4241`, `4242`, `4249`, and `503`; `298` remains covered by its dedicated branch-arm fixture.

## Validation

- `moon test src/passes` passed after the fixture sync.
- Standard quick signoff for this recovery commit also ran `moon info`, `moon fmt`, and `moon test`.

## Remaining work

`[DAE004-D]`, `[DAE004-H]`, and `[DAE004-I]` remain open. Productive fallback families still need trace metadata and/or a narrower family-specific bucketed path, artifact validation, pass-local timing inside the DAE011 target, and direct compare evidence before another fallback entry can be deleted or the fallback can be removed entirely.
