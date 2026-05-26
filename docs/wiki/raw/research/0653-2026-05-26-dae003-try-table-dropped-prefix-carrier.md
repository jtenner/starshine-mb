# DAE003-F try_table dropped-prefix carrier

Date: 2026-05-26

## Scope

Advance `[DAE003-F]` by accepting one more structured constant-carrier shape for `dae-optimizing`: a non-adjacent caller-local producer where a `try_table` result body contains only dropped materializable constants before a final materializable leaf.

## Test-first evidence

Added `dae-optimizing materializes non-adjacent try-table dropped-prefix constant carrier` in `src/passes/dae_optimizing_test.mbt`.

Initial focused pass-suite run failed as expected:

```text
moon test src/passes
... dae-optimizing materializes non-adjacent try-table dropped-prefix constant carrier ... FAILED: `1 != 0`
```

The callee still had one parameter, proving the existing `try_table` carrier recognizer only accepted a single-leaf body.

## Implementation

`src/passes/dead_argument_elimination.mbt` now routes `try_table` carrier bodies through the same dropped-materializable-prefix leaf resolver already used for `block` bodies and equal-arm `if` arms. This keeps the accepted subset narrow: each prefix value must be materializable and immediately dropped, and the final body leaf must be materializable. Computed, trapping/effectful, branchy, throwing, and other control-sensitive `try_table` bodies remain rejected by the same helper.

## Validation

- Test-first `moon test src/passes` failed on the new regression before implementation.
- `moon test src/passes` passed after implementation (`1410` tests) with existing unrelated unused-helper warnings.
- `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed (`3482` tests).
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003-try-table-prefix-20260526-1000` stopped at the known threshold with `45/1000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, and `1` Binaryen/tool command failure. Agent classification: the mismatch set remains the accepted DAE010/DAE011 gen-valid raw-cleanup family where Starshine strips dropped pure/nontrapping debris that Binaryen preserves; this slice does not introduce a new semantic or validation mismatch.

## Remaining DAE003-F work

Broader branchy/computed multi-instruction block positives, broader throwing/control-sensitive try/try_table positives, unequal/control-sensitive `if` policy, and additional trap/effect/control negatives remain open. This slice does not close `[DAE003-F]` or the full `[DAE]003` signoff.
