# Code-pushing br_on_non_null prefix aggregate inclusion

Date: 2026-06-25

## Scope

Follow-up for `[O4Z-AUDIT-CP]` after [`0838`](0838-2026-06-25-code-pushing-prefix-local-cleanup-normalizer.md) made the targeted `code-pushing-br-on-non-null-prefix` lane cleanup-normalized green at 200 requested cases.

## Larger targeted refresh

Before aggregating the leaf, reran the targeted prefix-payload lane at 1000 requested cases with the documented local cleanup normalizer:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-br-on-non-null-prefix --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-on-non-null-prefix-copydrop-normalized-1000-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures
# compared 1000/1000; normalized 0; cleanup-normalized 1000; raw mismatches 0; validation/generator/property/command failures 0
# cache: wasm-smith 0 hits/0 misses; Binaryen 1000 hits/0 misses; Binaryen failures 0 hits/0 misses
```

Agent classification remains narrow compare-normalized local cleanup/allocation debris after the code-pushing movement fix, not a semantic mismatch or unproven Starshine win.

## Aggregate profile change

Added `CodePushingBrOnNonNullPrefixProfile` to the `CodePushingAllProfile` composite in `src/validate/gen_valid.mbt`.

TDD evidence:

```sh
moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing aggregate*'
# failed before implementation because the aggregate did not sample CodePushingBrOnNonNullPrefixProfile

moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'
# passed 3/3 after implementation
```

The aggregate now has 18 leaves. `code-pushing-br-if-value` remains targeted-only because its value-`br_if` lowering temporary-local family is still open.

## Aggregate smoke

Reran a bounded aggregate smoke after adding the leaf:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-all-prefix-aggregated-1000-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures
# compared 1000/1000; normalized 507; cleanup-normalized 493; raw mismatches 0; validation/generator/property/command failures 0
# cache: wasm-smith 0 hits/0 misses; Binaryen 1000 hits/0 misses; Binaryen failures 0 hits/0 misses
```

## Validation

Additional validation for this slice:

```sh
moon fmt
moon info
# passed with pre-existing warnings

moon test src/validate
# passed 1627/1627
```

## Remaining work

The prefix-payload leaf is now aggregate-safe under the documented `local-cleanup-debris` normalizer. `[O4Z-AUDIT-CP]` is still not ready for final closeout: `code-pushing-br-if-value` remains out of the aggregate, and the broader audit still lists switch/`br_table` beyond the protected simple boundary, broader `br_on_*`/reference-carrying forms, broader ordered windows, local-copy dependency chains, precise `orderedBefore`/atomics/GC/EH/trap-option surfaces, and the final direct-compare matrix.
