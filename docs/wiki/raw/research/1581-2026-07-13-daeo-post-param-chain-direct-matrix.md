# DAEO post-exact-param-chain direct compare matrix

Date: 2026-07-13

## Scope

This note refreshes the full required direct `dae-optimizing` matrix after note `1580` changed retained behavior. Every lane uses both documented DAE normalizers, `--jobs auto`, the explicit freshly rebuilt native binary, persistent cache, and reduction-disabled counting.

Fresh binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `48abcd5da8b92b45423915c0cd70740ff072cd420d21ab76e55ceabb0e5e5812`.

## Dedicated aggregate

Command shape:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass dae-optimizing --gen-valid-profile dae-optimizing \
  --normalize drop-consts --normalize unreachable-control-debris \
  --out-dir .tmp/pass-fuzz-dae-optimizing-dedicated-10000-post-param-chain-20260713 \
  --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

Result:

- requested/compared `10000/10000`;
- normalized `10000`;
- cleanup-normalized `0`;
- mismatches `0`;
- validation/generator/property/command failures `0`;
- selected profile `dae-optimizing=10000`;
- Binaryen cache `10000` hits / `0` misses;
- no wasm-smith or Binaryen-failure cache traffic.

## Regular GenValid

Output directory: `.tmp/pass-fuzz-dae-optimizing-genvalid-100000-post-param-chain-20260713`.

Result:

- seed `0x5eed`;
- requested/compared `100000/100000`;
- normalized `100000`;
- cleanup-normalized `0`;
- mismatches `0`;
- validation/generator/property/command failures `0`;
- selected profile `binaryen-oracle-portable=100000`;
- Binaryen cache `100000` hits / `0` misses.

## Explicit wasm-smith

Output directory: `.tmp/pass-fuzz-dae-optimizing-wasm-smith-10000-post-param-chain-20260713`.

Result:

- seed `0x5eed`;
- requested `10000`, compared `9956`;
- normalized `9955`;
- cleanup-normalized `1`;
- mismatches `0`;
- validation/generator/property failures `0`;
- command failures `44`, all Binaryen/oracle classes: `binaryen-rec-group-zero=39`, `binaryen-invalid-tag-index=1`, `binaryen-table-index-out-of-range=1`, `binaryen-bad-section-size=3`;
- wasm-smith cache `10000/0` hits/misses;
- Binaryen cache `9956/0`;
- Binaryen-failure cache `44/0`;
- no Starshine command or validation failure.

Agent judgment: tool/Binaryen failures only. The one cleanup-normalized case is the documented generated cleanup-debris family, not a remaining raw mismatch.

## Random all-profiles

Output directory: `.tmp/pass-fuzz-dae-optimizing-random-all-10000-post-param-chain-20260713`.

Result:

- seed `0x5555`;
- requested/compared `10000/10000`;
- normalized `9633`;
- cleanup-normalized `0`;
- mismatches `367`;
- validation/generator/property/command failures `0`;
- Binaryen cache `10000/0`;
- `reduceMismatches=false`.

Selected DAE-relevant profile counts include `coverage-forced-portable=1017` and `dae-effectful-args=124`; the complete selected-profile map remains in `result.json`.

The failure-directory set is exactly the same `367` cases as `.tmp/pass-fuzz-dae-optimizing-random-all-10000-post-recgroup-20260713`, and all `3670` compared failure artifacts are byte-identical. Therefore the existing source/diff/replay/size classification remains current:

- `coverage-forced-portable=243`;
- `dae-effectful-args=124`;
- aggregate Starshine deltas `-110219` raw / `-797486` canonical / `-5465849` WAT bytes;
- no canonical/WAT-positive case;
- agent classification: measured/source-backed Starshine cleanup wins, not harness-proved semantic safety.

No unknown/risky, size-losing generated residual, Starshine validation failure, or true semantic mismatch remains in the fresh direct matrix.

## Status

The direct matrix is current after note `1580`. DAEO remains active because scheduled current-artifact `optimize` / `shrink` / synthesized O4z output and performance, full release validation, final docs/backlog reconciliation, and the remaining direct artifact canonical gap still require closeout work.
