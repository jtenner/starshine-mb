# DAE003 equal-arm if carrier

Date: 2026-05-26

## Scope

Advance `[DAE003-F]` structured constant/unread carriers by accepting the narrow non-adjacent caller-local shape where a prior `local.set` producer is a value-producing `if` whose then/else arms each contain exactly one identical materializable constant.

## Test-first evidence

Added focused regression `dae-optimizing materializes non-adjacent equal-arm if constant carrier` in `src/passes/dae_optimizing_test.mbt` by changing the previous conservative equal-arm `if` guard from preserving the target parameter to expecting constant materialization.

Initial focused run failed as intended:

```text
moon test src/passes
FAILED: `1 != 0`
```

The target still had one parameter before implementation.

## Implementation

Renamed the narrow structured producer helper from `dae_materializable_block_const` to `dae_materializable_control_const` in `src/passes/dead_argument_elimination.mbt` and extended it to accept:

- single-instruction `block` carriers already covered by note `0644`; and
- `if` carriers only when both arms have exactly one materializable constant and `dae_materialized_const_equal(...)` proves the constants identical.

The recognizer still rejects loops, try/try_table, multi-instruction blocks, non-identical arms, and non-materializable arm expressions. The producer condition is not materialized into the callee; the original caller-side producer remains in place until cleanup proves it removable, preserving any condition evaluation effects or traps.

## Validation

- `moon test src/passes` passed after the implementation (`1404` tests).
- `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed (`3476` tests; existing unused-helper warnings in `pass_manager_wbtest.mbt`).
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003f-if-20260526-1000` stopped at the known mismatch threshold with `45/1000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, and `1` Binaryen/tool command failure. Agent classification: the mismatches remain in the accepted DAE010/DAE011 gen-valid raw-cleanup / size-winning semantic-safe family; no new validation failure was observed.

## Remaining DAE003-F work

`[DAE003-F]` remains open for branchy/multi-instruction block positives where provably safe, loop positives, try/try_table positives, unequal/control-sensitive `if` policy, and additional trap/effect/control negative tests.
