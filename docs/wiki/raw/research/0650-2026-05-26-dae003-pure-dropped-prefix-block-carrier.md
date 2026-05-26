# DAE003 pure dropped-prefix block carrier

Date: 2026-05-26

## Scope

Advance `[DAE003-F]` structured constant-carrier support by accepting one additional safe block shape for non-adjacent caller-local constant materialization.

## Test-first evidence

Added `dae-optimizing materializes non-adjacent pure dropped-prefix block carrier` in `src/passes/dae_optimizing_test.mbt`.

Initial focused pass-suite run:

```sh
moon test src/passes
```

failed as expected with the new target still retaining one parameter (`1 != 0`). This proved the existing recognizer rejected the new multi-instruction block carrier.

## Implementation

`src/passes/dead_argument_elimination.mbt` now has `dae_materializable_dropped_const_prefix_leaf(...)`, used only by `dae_materializable_control_const(...)` for `block` carriers. The accepted shape is intentionally narrow:

- block body length is odd and at least three instructions;
- every prefix pair is `materializable-const; drop`;
- the final instruction is a materializable constant (or immutable global when that lane opts in);
- no trapping, effectful, branchy, or computed-expression prefix is accepted.

For the covered fixture, `block (result i32) { i32.const 7; drop; i32.const 88 }` is semantically the same call actual as `i32.const 88`, so DAE can remove the callee parameter and rewrite its local reads to `88` without changing effects or trap order.

The existing multi-instruction `i32.const 40; i32.const 2; i32.add` block negative guard remains conservative because the new helper does not fold computed expressions.

## Validation

- `moon test src/passes` failed before implementation on the new regression.
- `moon test src/passes` passed after implementation (`1407` tests) with existing unrelated unused-helper warnings in `pass_manager_wbtest.mbt`.
- `git diff --check` passed.
- `moon info` passed.
- `moon fmt` passed.
- `moon test` passed (`3479` tests).
- `bun fuzz compare-pass --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003-pure-prefix-block-20260526` stopped at the known early mismatch threshold with `45/1000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, `0` generator failures, and `1` Binaryen/tool command failure. Agent classification: the mismatches remain in the accepted DAE010/DAE011 gen-valid raw-cleanup / size-winning semantic-safe family because this slice only recognizes a pure dropped-constant prefix before the same final materialized leaf and does not change trapping/effectful/control-sensitive carriers.

## Remaining DAE003-F work

Structured carriers remain open for branchy/multi-instruction blocks beyond pure dropped-prefix debris, try/try_table positives, broader unequal/control-sensitive `if` policy, and additional trap/effect/control negatives. This slice does not close `[DAE003-F]`.
