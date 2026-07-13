# DAEO fresh dedicated and regular compare evidence

Date: 2026-07-13

## Scope

This slice rebuilt native Starshine from commit `cf08ff06f4da78e3c0deedbffee0dd945978d0c0` after the touched-function `tuple-optimization` and trap-preservation changes, then refreshed the direct `dae-optimizing` dedicated-profile and regular GenValid closeout lanes.

The native binary was `_build/native/release/build/cmd/cmd.exe`, SHA-256 `22714173c2ef24e549aa321f8fcf5b6e4b8023e6dc4af76d224f809cf186392d`, built at `2026-07-13 10:11:08 UTC`. Both lanes explicitly used `--jobs auto`, that binary, and the required DAE normalizers `drop-consts` plus `unreachable-control-debris`. Mismatch reduction was disabled because these were counted closeout lanes and neither produced a mismatch.

## Dedicated `dae-optimizing` profile

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --gen-valid-profile dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-dedicated-10000-20260713-post-tuple --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

Result:

- requested/compared: `10000/10000`;
- normalized matches: `10000`;
- cleanup-normalized matches: `0`;
- raw mismatches: `0`;
- validation/generator/property/command failures: `0/0/0/0`;
- selected profile: `dae-optimizing=10000`;
- Binaryen cache: `10000` hits / `0` misses;
- Binaryen failure cache: `0/0`;
- wasm-smith cache: `0/0`.

The deterministic profile exercises the pass-owned boundary rewrite plus touched-function optimizing replay. The new tuple cleanup and exact trap guards therefore remain compatible with the generated positive contract at full dedicated scale.

## Regular GenValid

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-genvalid-100000-20260713-post-tuple --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

Result:

- requested/compared: `100000/100000`;
- normalized matches: `100000`;
- cleanup-normalized matches: `0`;
- raw mismatches: `0`;
- validation/generator/property/command failures: `0/0/0/0`;
- Binaryen cache: `100000` hits / `0` misses;
- Binaryen failure cache: `0/0`;
- wasm-smith cache: `0/0`.

## Agent classification

There are no residuals to classify in either lane. These are direct normalized Binaryen behavior-parity matches, not an inference from validity or size alone.

The evidence does not by itself close DAEO. The explicit wasm-smith and random-all lanes still need a fresh post-change run, and the scheduled `optimize` / `shrink` O4z neighborhood still needs current artifact and performance evidence. Plain `dead-argument-elimination` remains a separate raw-red surface and must not acquire the optimizing-only nested replay.
