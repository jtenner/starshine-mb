# DAE003-F if dropped-prefix carrier

Date: 2026-05-26

## Scope

Advance `[DAE003-F]` by accepting one more structured constant-carrier shape for `dae-optimizing`: a non-adjacent caller-local producer where an `if` result has equal materializable leaves in both arms, and each arm may contain only dropped materializable constants before that leaf.

## Test-first evidence

Added `dae-optimizing materializes non-adjacent equal-arm if dropped-prefix constant carrier` in `src/passes/dae_optimizing_test.mbt`.

Initial focused pass-suite run failed as expected:

```text
moon test src/passes
... dae-optimizing materializes non-adjacent equal-arm if dropped-prefix constant carrier ... FAILED: `1 != 0`
```

The callee still had one parameter, proving the current structured-carrier recognizer did not materialize this shape.

## Implementation

`src/passes/dead_argument_elimination.mbt` now reuses the dropped-materializable-prefix leaf resolver for both `if` arms. A single-instruction arm remains accepted through the same helper, preserving the existing equal-arm single-leaf coverage while allowing prefixes such as:

```wat
(if (result i32)
  (then i32.const 7 drop i32.const 88)
  (else i32.const 9 drop i32.const 88))
```

The helper still rejects even-length stacks, computed expressions, trapping/effectful producers, unequal leaves, missing else arms, and branch/control-heavy bodies.

## Validation

- Test-first `moon test src/passes` failed on the new regression before implementation.
- `moon test src/passes` passed after implementation (`1409` tests) with existing unrelated unused-helper warnings.
- `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed (`3481` tests) with the same existing unused-helper warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003-if-prefix-20260526-1000` stopped at the known threshold with `45/1000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, and `1` Binaryen/tool command failure. Agent classification: the mismatch set remains the accepted DAE010/DAE011 gen-valid raw-cleanup family where Starshine strips dropped pure/nontrapping debris that Binaryen preserves; this slice does not introduce a new semantic or validation mismatch.

## Remaining DAE003-F work

Broader branchy/computed multi-instruction block positives, broader try/try_table positives, unequal/control-sensitive `if` policy, and additional trap/effect/control negatives remain open. This slice does not close `[DAE003-F]` or the full `[DAE]003` signoff.
