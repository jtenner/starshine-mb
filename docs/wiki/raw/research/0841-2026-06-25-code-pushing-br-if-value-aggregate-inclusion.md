# Code-pushing value br_if aggregate inclusion

Date: 2026-06-25

## Scope

Follow-up for `[O4Z-AUDIT-CP]` after [`0840`](0840-2026-06-25-code-pushing-br-if-value-local-cleanup-normalizer.md) made the targeted `code-pushing-br-if-value` lane cleanup-normalized green at 200 requested cases.

## Larger targeted refresh

Before aggregating the leaf, reran the targeted value-`br_if` lane at 1000 requested cases with the documented local cleanup normalizer:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-br-if-value --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-br-if-value-copydrop-normalized-1000-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures
# compared 1000/1000; normalized 0; cleanup-normalized 1000; raw mismatches 0; validation/generator/property/command failures 0
# cache: wasm-smith 0 hits/0 misses; Binaryen 1000 hits/0 misses; Binaryen failures 0 hits/0 misses
```

Agent classification remains narrow compare-normalized local cleanup/lowering debris after the code-pushing movement fix, not a semantic mismatch or unproven Starshine win.

## Aggregate profile change

Added `CodePushingBrIfValueProfile` to the `CodePushingAllProfile` composite in `src/validate/gen_valid.mbt`.

TDD evidence:

```sh
moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing aggregate*'
# failed before implementation because the aggregate did not sample CodePushingBrIfValueProfile

moon test --target native src/validate/gen_valid_tests.mbt --filter '*code-pushing*'
# passed 3/3 after implementation
```

The aggregate now has 19 leaves.

## Aggregate smoke

Reran a bounded aggregate smoke after adding the leaf:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass code-pushing --gen-valid-profile code-pushing-all --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-code-pushing-all-br-if-value-aggregated-1000-20260625 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 100 --keep-going-after-command-failures
# compared 1000/1000; normalized 466; cleanup-normalized 534; raw mismatches 0; validation/generator/property/command failures 0
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

Both previously targeted generated value/prefix branch leaves are now aggregate-safe under the documented `local-cleanup-debris` normalizer. `[O4Z-AUDIT-CP]` is still not ready for final closeout: the broader audit still lists switch/`br_table` beyond the protected simple boundary, broader `br_on_*`/reference-carrying forms, broader ordered windows, local-copy dependency chains, precise `orderedBefore`/atomics/GC/EH/trap-option surfaces, a then-current 10000-case dedicated `code-pushing-all` lane, the required 100000 regular GenValid lane, and explicit final stop-condition documentation.
