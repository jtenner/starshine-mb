# DAE003 try_table carrier

Date: 2026-05-26

## Scope

Advance `[DAE003-F]` structured constant/unread carrier support for a narrow `try_table` value carrier feeding a non-adjacent `local.set; local.get; call` actual.

## Test-first failure

Added focused coverage in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing materializes non-adjacent try-table constant carrier`

The fixture uses a typed outer block and a `try_table (result i32)` with a tag catch targeting that block. The normal fallthrough body is a single `i32.const 88`, then the value is stored to a local and forwarded to a private direct callee parameter.

Before implementation, the focused command failed because the target function still had one parameter:

```text
moon test src/passes -f 'dae-optimizing materializes non-adjacent try-table constant carrier' --target native
FAILED: `1 != 0`
```

## Implementation

Updated `src/passes/dead_argument_elimination.mbt` so `dae_materializable_control_const`:

- accepts a single-leaf `try_table` body when the leaf is already materializable, and
- recursively unwraps a single-instruction block carrier so an outer result block around the `try_table` does not hide the materializable leaf.

This keeps the accepted surface narrow: the `try_table` body must have exactly one materializable leaf, and broader throwing, computed, branchy, or multi-instruction carriers remain deferred.

## Validation

After implementation, the focused native test passed with only existing unrelated unused-helper warnings:

```text
moon test src/passes -f 'dae-optimizing materializes non-adjacent try-table constant carrier' --target native
Total tests: 1, passed: 1, failed: 0.
```

Additional validation in this recovery run:

```text
git diff --check
moon info
moon fmt
moon test
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003-try-table-20260526-1k
```

Results: `moon test` passed `3480/3480` with existing unrelated unused-helper warnings. The 1000-case direct compare stopped at the known early command-failure threshold with `45/1000` compared, `26` normalized matches, `19` mismatches, `0` validation failures, `0` generator failures, and `1` Binaryen/tool command failure. Agent classification keeps the mismatches in the accepted DAE010/DAE011 gen-valid raw-cleanup/size-winning semantic-safe family; this slice did not introduce a new semantic or validation failure.

`[DAE003-F]` remains open for broader try/try_table positives, branchy/computed structured carriers, broader unequal/control-sensitive `if` policy, and additional trap/effect/control negatives.
