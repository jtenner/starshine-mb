# DAE003 branch-free loop carrier

## Scope

Advance `[DAE003-F]` by accepting the narrow non-adjacent structured constant-carrier shape where a caller-local producer is a branch-free `loop` containing exactly one materializable constant/global leaf, then `local.set`, `local.get`, and `call` forward that value to a private direct callee.

## Test-first evidence

- Updated `src/passes/dae_optimizing_test.mbt` so the existing loop-carrier regression now expects `dae-optimizing` to materialize the constant and remove the target parameter.
- Confirmed the intended failure before implementation with:
  - `moon test src/passes --filter 'dae-optimizing materializes non-adjacent branch-free loop constant carrier'`
  - Failure: `params.length()` was `1`, expected `0`.

## Implementation

- Extended `dae_materializable_control_const(...)` in `src/passes/dead_argument_elimination.mbt` to treat `Loop(_, body)` like the existing single-instruction `Block` carrier only when the body has exactly one materializable leaf.
- This keeps multi-instruction blocks, branchy/control-sensitive carriers, unequal `if` arms, trapping/effectful producer expressions, and broader try/try_table shapes out of scope.

## Validation

- Focused post-fix validation passed:
  - `moon test src/passes --filter 'dae-optimizing materializes non-adjacent branch-free loop constant carrier'`
- `git diff --check`, `moon info`, `moon fmt`, and `moon test` passed.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003-loop-carrier-20260526` stopped at the known threshold with `45/1000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, and `1` Binaryen/tool command failure. Agent classification: the mismatches remain in the accepted DAE010/DAE011 gen-valid raw-cleanup semantic-safe/size-winning family; the command failure is a Binaryen/tool failure, not a Starshine validation failure.

## Backlog impact

`[DAE003-F]` remains open for broader structured carriers: branchy/multi-instruction block positives, try/try_table positives, broader if policy, and additional trap/effect/control negatives. This note closes only the branch-free single-leaf loop carrier subset.
