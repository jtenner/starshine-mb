# DAE003 nested dropped-prefix block carrier

Date: 2026-05-26

## Scope

Advance `[DAE003-F]` structured constant/unread-parameter carriers by allowing dropped-prefix structured block carriers to resolve nested materializable constant carriers, not just direct constant leaves.

## Test-first evidence

Added focused regression in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing materializes non-adjacent nested dropped-prefix block carrier`

Before implementation, `moon test src/passes` failed with `params.length(): 1 != 0`, proving the target parameter was still preserved when the caller stored a typed `block` whose dropped prefix and final value were themselves typed `block` constant carriers.

## Implementation

Updated `src/passes/dead_argument_elimination.mbt` so multi-instruction `block`, `loop`, and `try_table` dropped-prefix carrier recognition resolves each dropped prefix and final leaf through the same recursive structured-carrier recognizer used by equal-arm `if` arms.

The existing safety policy remains intact:

- each prefix must still be a materializable carrier followed immediately by `drop`;
- the final leaf must resolve to the guaranteed call actual;
- computed, trapping, effectful, throwing, and branch/control-sensitive prefixes still fail unless already covered by the structured-recognizer safe subset.

## Validation

- Test-first `moon test src/passes` failed on the new regression with the target still taking one parameter.
- After implementation, `moon test src/passes` passed (`1415/1415`) with only pre-existing unused helper warnings in `pass_manager_wbtest.mbt`.
- `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed (`3487/3487`).
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003f-nested-dropped-prefix-20260526-1000` stopped at the known threshold with `45/1000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, `0` generator failures, and `1` Binaryen/tool command failure.

## Classification

This is a narrow semantic-safe behavior widening for pure structured carriers. The removed parameter is replaced in the callee with the same materialized constant proven to be the caller's guaranteed actual; dropped prefix carriers are only removed after proving they are materializable and explicitly dropped. No trapping/effectful/control-transfer carrier family is newly accepted. The 1000-case fuzz mismatches stay in the previously accepted DAE010/DAE011 gen-valid raw-cleanup/size-winning semantic-safe family; no validation failures or new semantic mismatch family appeared in this slice.

## Follow-up

`[DAE003-F]` remains open for branchy/computed multi-instruction positives where provably safe, broader throwing/control-sensitive `try` / `try_table` positives, broader unequal/control-sensitive `if` policy, and additional trap/effect/control negatives.
