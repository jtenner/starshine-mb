# DAE003 loop dropped-prefix carrier

Date: 2026-05-26

## Scope

Follow-up for `[DAE003-F]` structured constant/unread carriers. This slice broadens the accepted branch-free `loop` carrier from a single materializable leaf to the same narrow dropped-prefix shape already accepted for `block` and `try_table`: zero or more materializable constants followed by `drop`, then one final materializable leaf.

## Test-first evidence

Added `dae-optimizing materializes non-adjacent loop dropped-prefix constant carrier` in `src/passes/dae_optimizing_test.mbt`.

The first focused pass-suite run failed as expected:

```text
moon test src/passes
[...]
"dae-optimizing materializes non-adjacent loop dropped-prefix constant carrier" failed: `1 != 0`
```

The failure showed the target still had one parameter, so the non-adjacent caller-local actual was not materialized through the loop carrier.

## Implementation

`src/passes/dead_argument_elimination.mbt` now resolves `loop` carriers with `dae_materializable_dropped_const_prefix_leaf(...)`, matching the existing pure dropped-prefix policy used by `block`, `try_table`, and equal-arm `if` arms. The accepted shape remains intentionally narrow:

- every prefix producer must itself be a materializable constant or immutable-global leaf under the current caller;
- every prefix value must be immediately dropped;
- the final leaf must be materializable;
- branchy, trapping/effectful, computed, and control-sensitive loops remain deferred under `[DAE003-F]`.

## Validation

After implementation:

```text
moon test src/passes
Total tests: 1413, passed: 1413, failed: 0.

git diff --check && moon info && moon fmt && moon test
Total tests: 3485, passed: 3485, failed: 0.

bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003-loop-dropped-prefix-0656-1000
Compared cases: 45/1000
Normalized matches: 26
Validation failures: 0
Command failures: 1
Mismatches: 19
```

The Moon runs still report existing unrelated unused-helper warnings in `pass_manager_wbtest.mbt`. The 1000-case compare stopped at the known DAE threshold; agent classification keeps the 19 `gen-valid` mismatches in the accepted DAE010/DAE011 size-winning semantic-safe raw-cleanup family, and the single command failure in the existing Binaryen/tool failure class.

## Backlog impact

`[DAE003-F]` remains open. This note adds one positive structured-carrier family to the accepted surface but does not close branchy/computed block positives, broader throwing/control-sensitive try/try_table positives, broader unequal/control-sensitive `if` policy, or additional trap/effect/control negatives.
