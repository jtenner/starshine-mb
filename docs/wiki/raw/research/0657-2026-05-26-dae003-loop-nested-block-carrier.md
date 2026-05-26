# DAE003 loop nested-block carrier

Date: 2026-05-26

## Scope

Advance `[DAE003-F]` structured constant/unread-parameter carriers by allowing the existing branch-free loop carrier recognizer to recurse through a single nested structured carrier when proving a non-adjacent local-set constant actual.

## Test-first evidence

Added focused regression in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing materializes non-adjacent loop nested block constant carrier`

Before implementation, `moon test src/passes` failed with `params.length(): 1 != 0`, proving the target parameter was still preserved when the caller stored a `loop (result i32)` containing a single typed `block` with `i32.const 88` before the call.

## Implementation

Updated `src/passes/dead_argument_elimination.mbt` so `dae_materializable_control_const(...)` treats one-instruction `loop` and `try_table` bodies like one-instruction `block` bodies:

- first accept a direct materializable leaf;
- otherwise recurse into `dae_materializable_control_const(...)` for the nested single carrier.

Multi-instruction loop / try_table bodies still use the existing dropped-materializable-prefix policy, so this does not widen computed, trapping, effectful, or branchy prefixes.

## Validation

- `moon test src/passes` passed after the change (`1414/1414`), with only pre-existing unused helper warnings in `pass_manager_wbtest.mbt`.
- `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed (`3486/3486`).
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003f-loop-nested-block-20260526-1000` stopped at the known threshold with `45/1000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, and `1` Binaryen/tool command failure.

## Classification

This is a narrow semantic-safe behavior widening for branch-free structured carriers. The recognized value is still the guaranteed call actual, and the callee parameter is replaced with the same materialized constant. The 1000-case fuzz mismatches stay in the previously accepted DAE010/DAE011 gen-valid raw-cleanup/size-winning semantic-safe family; no artifact or fuzz mismatch classification changed in this slice.

## Follow-up

`[DAE003-F]` remains open for broader structured carriers: branchy/computed multi-instruction block positives, broader throwing/control-sensitive try/try_table positives, broader unequal/control-sensitive `if` policy, and additional trap/effect/control negatives.
