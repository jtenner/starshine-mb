# DAE004 large-module low-candidate regression guard

Date: 2026-05-26

## Scope

Recovery continuation for open `[DAE]004` selected result-removal broadening. This slice adds a focused regression guard for the scheduling boundary identified in research note `0629`: large modules must not lose lower-index fact-discovered dropped-result candidates merely because the descending high-candidate lane consumes its bounded productive budget first.

## Change

Added `src/passes/dae_optimizing_test.mbt` coverage named `dae-optimizing reaches low dropped-result callee after large descending budget`.

The fixture builds a module above the `4608` defined-function threshold with:

- one lower-index dropped-result target at defined function `600`;
- eight higher-index dropped-result targets starting at defined function `4644`;
- an exported caller that drops all of those results.

The assertion requires DAE to remove the result from both the lower target and all eight high targets. This protects the current fact-driven scheduling surface while `[DAE]004` remains open and before any handpicked fallback removal or batching/worklist replacement.

## Result

The focused regression already passes on the current implementation. No optimizer behavior changed in this slice.

## Classification

This is a regression-guard and evidence slice, not a fuzz/compare mismatch classification. It does not prove that the selected fallback can be removed: the debug artifact still has the handpicked selected-def fallback inventory and ordering/cap classification from notes `0628` and `0629`.

## Next work

`[DAE004-C]` remains the next behavior-changing design slice: prove or implement a runtime-neutral large-module batching/worklist strategy that can retire the handpicked selected dropped-result fallback without regressing high-candidate reach, validation, or pass-local timing.

## Validation

- `moon test src/passes -f dae-optimizing` reported no matching test entry in this workspace invocation.
- `moon test src/passes` passed: `1388` tests passed.
