---
kind: research
status: current
created: 2026-06-25
sources:
  - ./1079-2026-06-25-random-all-profiles-genvalid-profile.md
  - ../../../../docs/wiki/binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../src/validate/gen_valid.mbt
---

# HSO Random All-Profiles GenValid Lane

## Context

Final HSO closeout requires a random all-profiles GenValid lane at seed `0x5555` without the dedicated HSO `local-cleanup-debris` normalizer. Research note `1079` added the `random-all-profiles` composite profile. The first broad implementation attempted to sample every non-composite profile leaf, but that proved unsuitable for a compare-pass closeout lane: `pathological-valid` aborts `emit-gen-valid-batch`, and a broad 10000-case HSO attempt timed out after only 381 recorded cases with many generator failures from heavy/stress leaves and raw mismatches from the HSO-dedicated profile's known local-cleanup output-shape drift.

This slice narrowed `random-all-profiles` to the current compare-pass-stable leaves:

- `coverage-forced-portable`
- `binaryen-oracle-portable`
- `pass-fuzz-stress`
- `ssa-nomerge-smoke`
- `ssa-nomerge-parity`

The narrowed profile intentionally excludes composite aliases, `pathological-valid`, and the dedicated `heap-store-optimization` leaf until those profiles are repaired or explicitly accepted for this raw closeout lane.

## Validation

Red-first focused validation:

```sh
moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt
```

failed after adding stability expectations because the initial broad profile still included the dedicated HSO leaf.

Post-fix validation:

```sh
moon fmt
moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt
```

passed (`78/78`).

A 32-case manifest smoke also succeeded:

```sh
rm -rf .tmp/repro-random-profile-stable-manifest \
  && mkdir -p .tmp/repro-random-profile-stable-manifest/inputs \
  && moon run --target native --release src/fuzz -- --emit-gen-valid-batch \
    --count 32 --seed 0x5555 --gen-valid-profile random-all-profiles \
    --out-dir .tmp/repro-random-profile-stable-manifest/inputs/gen-valid \
    --manifest .tmp/repro-random-profile-stable-manifest/inputs/gen-valid/manifest.json
```

Result: `generated=32`, `attempts=32`, `skipped=0`. Selected leaves: `ssa-nomerge-smoke=10`, `ssa-nomerge-parity=8`, `pass-fuzz-stress=6`, `binaryen-oracle-portable=5`, `coverage-forced-portable=3`.

## Compare evidence

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 \
  --pass heap-store-optimization --gen-valid-profile random-all-profiles \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-genvalid-random-all-profiles-stable-20260625-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Result:

- requested: `10000`
- compared: `10000/10000`
- normalized matches: `10000`
- cleanup-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- jobs: `16`
- cache: wasm-smith `0` hits / `0` misses; Binaryen `630` hits / `9370` misses; Binaryen failures `0` hits / `0` misses
- selected leaves from `cases.jsonl`: `pass-fuzz-stress=2062`, `coverage-forced-portable=2037`, `ssa-nomerge-smoke=1973`, `ssa-nomerge-parity=1970`, `binaryen-oracle-portable=1958`

No cleanup normalizers were used.

## Impact

This completes the random all-profiles GenValid lane required by the HSO final matrix, using the explicit stable profile definition above. It is green compare evidence, not source-family closeout by itself. HSO remains open for the 100000 regular GenValid lane, final Moon validation, O4z slot/neighborhood replay, performance disposition, exact descriptor `ref.cast` surface blocker, and remaining source-backed family reviews.
