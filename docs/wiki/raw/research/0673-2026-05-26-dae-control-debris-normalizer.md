# DAE unreachable/control-debris compare normalizer

Date: 2026-05-26

## Scope

Add an explicit pass-fuzz compare normalizer for the DAE/gen-valid family where Binaryen keeps generated unreachable/control debris that Starshine removes earlier. This follows the policy that if Binaryen's output is worse only because later cleanup handles representation/debris differently, the compare harness may normalize that diagnostic noise rather than report it as a raw mismatch.

The normalizer is intentionally opt-in as `--normalize unreachable-control-debris`, separate from `--normalize drop-consts`, so reports still distinguish exact normalized matches from matches reached only by explicit cleanup normalization.

## Implementation

`scripts/lib/pass-fuzz-compare-task.ts` now accepts `unreachable-control-debris` as a compare normalizer. The normalizer:

- strips local same-block `br_table` debris immediately before `unreachable` when the block has no calls, memory/table/global operations, local/ref/aggregate observations, exception operations, or escaping branches;
- canonicalizes unused unreferenced helper functions whose bodies reduce to unreachable after dropped-constant/control-debris cleanup;
- strips printed function type declarations and `(type $n)` annotations so type-index churn from those unreachable/debris-only helpers does not keep otherwise-equivalent outputs red.

It does not replace mismatch classification: any remaining mismatch after the normalizer still requires agent judgment.

## Test-first evidence

Added `runPassFuzzCompareUnreachableControlDebrisNormalizerCommandTest` in `scripts/test/pass-fuzz-compare-command.ts` with a fake Binaryen output containing a local `br_table $block $block` before `unreachable` and a Starshine output containing only `unreachable`.

Before implementation, the test failed because `unreachable-control-debris` was an unsupported normalizer. After implementation, the script test passed.

## Validation

- `bun scripts/test/pass-fuzz-compare-command.ts`
  - Result: passed.
- Replayed the recent Func503 DAE lane with both DAE normalizers:
  - `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --max-failures 20 --out-dir .tmp/pass-fuzz-dae004-d7-func503-control-normalized2-20260526`
  - Result: `998/1000` compared, `615` exact normalized matches, `373` compare-normalized matches, `10` remaining mismatches, `0` validation failures, `0` generator failures, and `2` Binaryen/tool command failures (`binaryen-rec-group-zero`).

The new normalizer moved many previously raw DAE/gen-valid debris mismatches into `cleanupNormalizedMatchCount`, but did not hide all remaining drift. The `10` remaining mismatches still need normal DAE mismatch classification before any closeout claim.

## Status

Use DAE compare lanes with both explicit normalizers:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing
```

Continue reporting `normalizedMatchCount`, `cleanupNormalizedMatchCount`, remaining mismatches, validation failures, and command-failure classes separately.
