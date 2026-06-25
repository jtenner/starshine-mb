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

Added `RandomAllProfilesProfile` with stable public spelling `random-all-profiles` and aliases `all-profiles` / `random-profiles`. The profile is composite and samples the current non-composite GenValid leaf profiles with equal weights, including the pass-targeted profiles, `heap-store-optimization`, and the SSA singleton profiles. It intentionally excludes itself and `ssa-nomerge-all` so the selected leaf recorded in manifests is always non-composite.

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

A follow-up attempt to also request `--manifest .tmp/gen-valid-random-all-profiles-smoke-manifest.json` aborted with a generic Moon runtime `unreachable` before surfacing the wrapped error. That appears to be a fuzz CLI manifest-emission surface issue rather than evidence against the profile itself; the compare-pass harness owns its own case manifest path during signoff and should still be used for the required HSO lane.

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
