# DAE003 trapping/effectful local-carrier guards

Date: 2026-05-26

## Scope

This note advances `[DAE003-C]` by covering the remaining non-adjacent local-set carrier negative policy for trapping and effectful carrier producers.

## Tests

Added two focused regressions in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing rejects non-adjacent trapping local-set carrier`
  - Shape: `i32.const 1; i32.const 0; i32.div_s; local.set 0; local.get 0; call $target`.
  - Expected result: preserve `$target`'s parameter and keep the trapping producer in the caller.
- `dae-optimizing rejects non-adjacent effectful local-set carrier`
  - Shape: `call $effect; local.set 0; local.get 0; call $target`.
  - Expected result: preserve `$target`'s parameter and keep the effect-producing call/local carrier in the caller.

The first focused `moon test src/passes` run failed because the initial effectful fixture placed `$effect` before `$target`, so the assertion inspected the wrong defined-function index. After fixing the fixture ordering, both guards passed without optimizer behavior changes.

## Result

The current non-adjacent local-set carrier recognizer remains narrow: it accepts only one prior materializable constant/immutable-global producer, rejects `local.tee`, earlier same-local reads, multiple same-local writes, trapping arithmetic producers, and effectful call producers before the call actual.

`[DAE003-C]` is now reduced to self/escaped-cycle policy, structured carriers, and closeout validation/classification. The broader `[DAE]003` slice remains open.

## Validation

- `moon test src/passes` passed (`1398` tests) after the fixture-index correction.
