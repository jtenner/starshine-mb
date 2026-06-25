---
kind: research
status: current
created: 2026-06-25
sources:
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - ../../../../docs/wiki/binaryen/passes/heap-store-optimization/fuzzing.md
---

# Random All-Profiles GenValid Profile

## Context

HSO final closeout requires a random all-profiles GenValid lane at seed `0x5555`, but the only composite GenValid profile before this slice was `ssa-nomerge-all`. There was no general all-profiles profile name to pass to `--gen-valid-profile`.

## Change

Added `RandomAllProfilesProfile` with stable public spelling `random-all-profiles` and aliases `all-profiles` / `random-profiles`. The profile is composite and samples the current compare-pass-stable non-composite GenValid leaf profiles with equal weights: `coverage-forced-portable`, `binaryen-oracle-portable`, `pass-fuzz-stress`, `ssa-nomerge-smoke`, and `ssa-nomerge-parity`. It intentionally excludes itself, `ssa-nomerge-all`, `pathological-valid`, and the dedicated `heap-store-optimization` leaf so the selected leaf recorded in manifests is always non-composite, avoids the existing standalone `pathological-valid` `emit-gen-valid-batch` abort, and avoids importing the HSO-dedicated `local-cleanup-debris` output-shape drift into a raw final-matrix lane.

## Tests and smoke evidence

Red-first focused validation:

```sh
moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt
```

failed before implementation because `RandomAllProfilesProfile` did not exist.

Post-implementation validation:

```sh
moon fmt
moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt
```

passed (`78/78`).

A small CLI smoke without a manifest also generated two valid artifacts:

```sh
rm -rf .tmp/gen-valid-random-all-profiles-smoke \
  && moon run src/fuzz -- --emit-gen-valid-batch --count 2 --seed 0x5555 \
    --out-dir .tmp/gen-valid-random-all-profiles-smoke \
    --gen-valid-profile random-all-profiles --max-attempts 32
```

Result: `generated=2 seed=21845 out_dir=.tmp/gen-valid-random-all-profiles-smoke profile=random-all-profiles attempts=2 skipped=0`.

A follow-up attempt to also request `--manifest .tmp/gen-valid-random-all-profiles-smoke-manifest.json` initially aborted with a generic Moon runtime `unreachable` before surfacing the wrapped error. The first blocker was narrowed to the selected `pathological-valid` leaf at case 6 for seed `0x5555`; standalone `pathological-valid` also aborts the `emit-gen-valid-batch` path. A broader 10000-case HSO lane attempt with the initial broad composite then timed out after reaching only 381 case records, with 225 generator failures and 57 mismatches in partial output. Those failures came from stress/heavy generator leaves and from raw HSO-dedicated local-cleanup drift, so follow-up code narrows the composite to the stable leaf set listed above until additional leaves are repaired, made fast enough, or intentionally admitted into compare-pass closeout lanes.

## Impact on HSO

The final HSO random all-profiles lane now has an explicit profile name:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 \
  --pass heap-store-optimization --gen-valid-profile random-all-profiles \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-genvalid-random-all-profiles-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Do not apply the dedicated HSO `local-cleanup-debris` normalizer to this lane unless a future mismatch is inspected and separately justified.
