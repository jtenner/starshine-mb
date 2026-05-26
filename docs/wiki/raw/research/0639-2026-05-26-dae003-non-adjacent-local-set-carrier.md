# DAE003 non-adjacent local-set carrier

Date: 2026-05-26

## Scope

This slice advances `[DAE003-C]` by covering the focused non-adjacent caller-local constant carrier:

```wat
i32.const 77
local.set 0
local.get 0
call $target
```

Before this change, the DAE uniform-constant collector saw the call actual as a `local.get` of a caller local, but the forwarded-constant resolver only chased parameter locals through caller/callee chains. A high-module focused regression therefore left `$target` with its `i32` parameter instead of materializing `77` in the callee.

## Change

- Added `dae-optimizing materializes non-adjacent local-set constant actual` in `src/passes/dae_optimizing_test.mbt`.
- Added `dae_resolve_local_set_const_carrier(...)` in `src/passes/dead_argument_elimination.mbt` and routed singleton `local.get` call actuals through it when the existing parameter-local resolver cannot prove a uniform constant.
- The new helper accepts only a narrow straight-line carrier before the call: one prior `local.set` to the same local whose immediate producer is a materializable constant or allowed immutable global, with no earlier read, tee, or multiple write to that local before the call actual.

## Validation

- Test-first failure: `moon test src/passes` failed on `dae-optimizing materializes non-adjacent local-set constant actual` with the target still having one parameter.
- After the implementation: `moon fmt` passed.
- After the implementation: `moon test src/passes` passed (`1393` tests).
- Commit-gate validation: `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed (`3465` tests).
- Focused compare refresh: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003c-local-set-carrier-20260526-1000` stopped after the existing max-failure threshold with `45/1000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, and `1` Binaryen/tool command failure (`binaryen-rec-group-zero`). Agent classification: the mismatch set is the already accepted DAE010/DAE011 gen-valid raw-cleanup family; the only wasm-smith failure dir is the Binaryen parse/tool failure, not a Starshine semantic mismatch.

## Remaining DAE003-C work

This does not close `[DAE003-C]`. The backlog still needs focused negative tests for `local.tee`, multiple writes/gets, effecting or trapping carrier prefixes if policy requires rejecting them, and escaped/self-cycle interactions before the non-adjacent forwarding surface can be considered complete.
