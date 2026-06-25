---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1136-2026-06-25-heap-store-optimization-final-closeout-moon-validation.md
  - ./1135-2026-06-25-heap-store-optimization-post-raw-complete-validation.md
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO final compare matrix refresh

## Question

After the raw complete-default-chain path and final Moon validation refresh, does direct `heap-store-optimization` match Binaryen across the required compare-pass closeout matrix with the explicit native Starshine binary?

## Answer

Yes for the full four-lane matrix required by the pass signoff workflow. The current native release binary compared green on:

1. regular GenValid `100000` cases at seed `0x5eed`;
2. explicit `wasm-smith` `10000` requested cases at seed `0x5eed`;
3. dedicated HSO GenValid profile `10000` cases at seed `0x5eed` with the documented `local-cleanup-debris` normalizer; and
4. random all-profiles GenValid `10000` cases at seed `0x5555`.

There were no mismatches, validation failures, property failures, or generator failures. The explicit `wasm-smith` lane had `44` Binaryen/oracle command failures, classified here as tool/oracle boundaries rather than Starshine semantic mismatches because the compared cases all normalized and the command-failure classes are Binaryen parse/validation boundaries already seen in earlier lanes.

## Evidence

All lanes used the explicit native binary refreshed in `1136`:

```sh
target/native/release/build/cmd/cmd.exe
```

### Regular GenValid lane

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 100000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-final-genvalid-100000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

- requested/compared: `100000/100000`
- normalized matches: `100000`
- cleanup-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- cache: `.tmp/pass-fuzz-cache`; wasm-smith `0` hits / `0` misses; Binaryen `100000` hits / `0` misses; Binaryen failures `0` hits / `0` misses

### Explicit wasm-smith lane

```sh
bun scripts/pass-fuzz-compare.ts \
  --wasm-smith \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-final-wasm-smith-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

- requested/compared: `10000/9956`
- normalized matches: `9956`
- cleanup-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `44`
- command-failure classes: `binaryen-rec-group-zero=39`, `binaryen-bad-section-size=3`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`
- cache: `.tmp/pass-fuzz-cache`; wasm-smith `10000` hits / `0` misses; Binaryen `9956` hits / `0` misses; Binaryen failures `44` hits / `0` misses

### Dedicated HSO profile lane

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --gen-valid-profile heap-store-optimization \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-final-profile-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

- requested/compared: `10000/10000`
- normalized matches: `0`
- cleanup-normalized matches: `10000`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- selected profile counts: `heap-store-optimization=10000`
- cache: `.tmp/pass-fuzz-cache`; wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses

Interpretation: the only normalization needed here is the already documented dedicated-profile `local-cleanup-debris` normalizer. This remains scoped to the dedicated HSO generated profile and is not applied to regular GenValid, wasm-smith, or random all-profiles lanes.

### Random all-profiles GenValid lane

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5555 \
  --pass heap-store-optimization \
  --gen-valid-profile random-all-profiles \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-final-random-all-profiles-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

- requested/compared: `10000/10000`
- normalized matches: `10000`
- cleanup-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- selected profile counts: `pass-fuzz-stress=2062`, `coverage-forced-portable=2037`, `ssa-nomerge-smoke=1973`, `ssa-nomerge-parity=1970`, `binaryen-oracle-portable=1958`
- cache: `.tmp/pass-fuzz-cache`; wasm-smith `0` hits / `0` misses; Binaryen `10000` hits / `0` misses; Binaryen failures `0` hits / `0` misses

## Interpretation

The required direct compare matrix is current and green after the latest HSO performance path. HSO-J still remains open until refreshed O4z slot/neighborhood evidence and final docs/backlog cleanup are completed.
