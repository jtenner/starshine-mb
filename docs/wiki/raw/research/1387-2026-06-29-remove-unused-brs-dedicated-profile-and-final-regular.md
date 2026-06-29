---
kind: research-note
status: active
created: 2026-06-29
sources:
  - ../../binaryen/passes/remove-unused-brs/fuzzing.md
  - ../../binaryen/passes/remove-unused-brs/parity.md
  - ../../binaryen/passes/remove-unused-brs/starshine-strategy.md
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - ../../../../agent-todo.md
---

# `remove-unused-brs` RUB-Q dedicated profile and final regular lane refresh

## Summary

This slice added a first in-tree `remove-unused-brs-all` GenValid aggregate and completed the previously missing regular `100000` normalized direct lane. The regular lane is now green, but RUB-Q final closeout is still blocked because the new dedicated profile is not green: its compact branch/switch/cleanup leaves expose Starshine validation failures before Binaryen comparison.

The validation failures are actionable pass/generator-profile evidence, not command/tool failures and not completed signoff. They should be reduced/fixed before this profile can serve as the required dedicated final-closeout lane.

## Profile wiring

Added GenValid profile constructors and aliases:

- `remove-unused-brs-control`
- `remove-unused-brs-switch`
- `remove-unused-brs-cleanup`
- `remove-unused-brs-gc` singleton remains available for targeted experimentation but is intentionally excluded from the aggregate because early smoke runs showed GC cases are boundary-heavy.
- `remove-unused-brs-all` / aliases `remove-unused-brs`, `remove-unused-brs-closeout`, `remove-unused-brs-all-profiles`, `rub`, `rub-closeout`

The closeout aggregate currently samples:

- `remove-unused-brs-control` weight `3`
- `remove-unused-brs-switch` weight `2`
- `remove-unused-brs-cleanup` weight `1`

Focused generator tests added in `src/validate/gen_valid_tests.mbt` prove name resolution, composite membership, deterministic leaf sampling, and the branch-heavy/typed-generator config bits. `moon fmt` refreshed `src/validate/pkg.generated.mbti` for the public enum/profile API change.

The profile deliberately skips the huge coverage prelude for the RUB-focused compact leaves, so it generates small control/payload shapes rather than megabyte-scale coverage bodies. The older prelude-backed prototype was too expensive for a 10k batch and not suitable as a required lane.

## Commands and results

### Red-first and profile tests

- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt` after adding tests first failed at compile time because the `RemoveUnusedBrs*Profile` constructors did not exist.
- After implementation: `moon fmt && moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt` passed, `99/99`.
- `moon info && moon build --target native --release src/cmd` passed; `moon info` reported existing warnings in `decode.mbt`, `encode.mbt`, `hot_verify.mbt`, `gen_valid.mbt`, and `gen_valid_ssa.mbt`.

### Completed final regular lane

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-regular-100000-normalized-rerun-long --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: passed.

- Requested/compared: `100000/100000`
- `normalizedMatchCount=14604`
- `cleanupNormalizedMatchCount=85396`
- `mismatchCount=0`
- `validationFailureCount=0`
- `propertyFailureCount=0`
- `generatorFailureCount=0`
- `commandFailureCount=0`
- cache: Binaryen `67100` hits / `32900` misses; wasm-smith `0/0`; Binaryen failures `0/0`
- selected profile: `binaryen-oracle-portable=100000`
- artifact: `.tmp/pass-fuzz-remove-unused-brs-rub-q-regular-100000-normalized-rerun-long/result.json`

This replaces the earlier timed-out `.tmp/pass-fuzz-remove-unused-brs-rub-q-regular-100000-normalized` partial lane as the current final-regular evidence.

### Dedicated profile experiments

1. First aggregate with GC included and the default coverage prelude:

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass remove-unused-brs --gen-valid-profile remove-unused-brs-all --normalize drop-consts --normalize unreachable-control-debris --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-100-smoke-norm3 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: completed but failed as a profile candidate: compared `100/100`, `76` cleanup-normalized matches, `24` mismatches, all from `remove-unused-brs-gc`. The inspected sample was boundary-heavy GC `br_on_cast*` output drift. This is why `remove-unused-brs-gc` is not part of the aggregate closeout profile yet.

2. Aggregate without GC but still using coverage prelude:

```sh
bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass remove-unused-brs --gen-valid-profile remove-unused-brs-all --normalize drop-consts --normalize unreachable-control-debris --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-100-smoke-norm3-nogc --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: passed the small smoke, `100/100` compared, `100` cleanup-normalized matches, no failures. But the follow-up `10000` run at `.tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-10000-normalized` failed during `moon run --target native --release src/fuzz -- --emit-gen-valid-batch ...` after writing all `10000` wasm files but before a usable manifest/result; this was treated as a command/tool/resource failure of the prelude-heavy prototype, not pass signoff.

3. Compact aggregate after skipping the huge coverage prelude:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --gen-valid-profile remove-unused-brs-all --normalize drop-consts --normalize unreachable-control-debris --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-1000-compact-norm3 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: completed and failed before comparison:

- Requested: `1000`
- Compared: `0/1000`
- Starshine output validation failures: `1000`
- Generator/property/command failures: `0`
- Selected profiles: `remove-unused-brs-control=487`, `remove-unused-brs-switch=338`, `remove-unused-brs-cleanup=175`
- Artifact: `.tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-1000-compact-norm3/result.json`

Sample `case-000001-gen-valid` input is a compact typed payload-control module with many `block (result T) { value; br/br_if/br_table; unreachable }` shapes. Starshine's `--remove-unused-brs` output failed validation with `func 1 failed to validate: type mismatch: expected i64 but nothing on stack`. This appears to be a validation/correctness gap exposed by the compact dedicated profile, not a Binaryen/tool command failure.

## Current classification

- Completed regular `100000` lane: green, no mismatches or failures.
- Dedicated `remove-unused-brs-all` profile: added but **not closeout-green**.
- The profile blocker is a Starshine validation failure family in compact payload-control branch cleanup. Reduce/fix this before declaring RUB-Q complete or before using the profile as the required final dedicated lane.
- The older prelude-backed prototype is not a viable substitute for final signoff because the `10000` batch failed before manifest/result emission.

## Reopening / next steps

1. Reduce `.tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-1000-compact-norm3/failures/case-000001-gen-valid` to a focused `remove_unused_brs_test.mbt` validation regression.
2. Determine whether the invalid output is caused by an existing payload `br`/`br_if`/`br_table` cleanup family, a raw/HOT writeback issue, or an overly broad generated compact shape that should be split into supported and boundary leaves.
3. Fix the pass or narrow the aggregate profile only with exact source-backed boundary criteria.
4. Rerun `remove-unused-brs-all` at `1000` first, then `10000` with the accepted RUB normalizers once green.
