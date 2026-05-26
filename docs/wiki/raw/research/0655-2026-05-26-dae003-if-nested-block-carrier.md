# DAE003 if nested block carrier

Date: 2026-05-26

## Scope

Follow-up for `[DAE003-F]` structured constant/unread carriers. This slice broadens the already accepted equal-arm `if` carrier surface to allow a nested single-leaf typed `block` in both arms when both arms resolve to the same materializable constant.

## Test-first evidence

Added `dae-optimizing materializes non-adjacent equal-arm if nested block carrier` in `src/passes/dae_optimizing_test.mbt`.

The first focused pass-suite run failed as expected:

```text
moon test src/passes
[...]
"dae-optimizing materializes non-adjacent equal-arm if nested block carrier" failed: `1 != 0`
```

The failure showed the target still had one parameter, so the non-adjacent caller-local actual was not materialized through the nested `if`/`block` carrier.

## Implementation

`src/passes/dead_argument_elimination.mbt` now lets equal-arm `if` arm leaves resolve through the existing `dae_materializable_control_const(...)` recognizer after a direct materializable-leaf check fails. This keeps the equal-arm requirement and dropped-prefix policy unchanged while reusing the already narrow block/loop/try_table/if control-carrier recognizers for arm leaves.

The accepted shape is intentionally narrow:

- both `if` arms must resolve to materializable constants;
- the resolved constants must be equal;
- nested control still has to satisfy the existing structured-carrier recognizers;
- computed, trapping/effectful, branchy, unequal-arm, and control-sensitive carriers remain deferred under `[DAE003-F]`.

## Validation

After implementation:

```text
moon test src/passes
Total tests: 1412, passed: 1412, failed: 0.

git diff --check && moon info && moon fmt && moon test
Total tests: 3484, passed: 3484, failed: 0.

bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003-if-nested-block-0655-1000
Compared cases: 45/1000
Normalized matches: 26
Validation failures: 0
Command failures: 1
Mismatches: 19
```

The Moon runs still report existing unrelated unused-helper warnings in `pass_manager_wbtest.mbt`. The 1000-case compare stopped at the known DAE threshold; agent classification keeps the 19 `gen-valid` mismatches in the accepted DAE010/DAE011 size-winning semantic-safe raw-cleanup family, and the single command failure in the existing Binaryen/tool failure class.

## Backlog impact

`[DAE003-F]` remains open. This note adds one positive structured-carrier family to the accepted surface but does not close the remaining branchy/computed block, broader try/try_table, or broader unequal/control-sensitive `if` policy work.
