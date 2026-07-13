---
kind: workflow
status: supported
last_reviewed: 2026-07-13
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/research/1568-2026-07-13-daeo-fresh-dedicated-and-regular-compare.md
  - ../dead-argument-elimination/fuzzing.md
---

# `dae-optimizing` Fuzzing Profile

## Dedicated profile

The pass-owned GenValid profile is `dae-optimizing`; `dae-optimizing-closeout` is an alias. It emits a deterministic five-function private-helper/direct-caller module where core DAE removes an unused helper parameter and leaves identity-add debris for the touched-function optimizing replay.

Use the DAE cleanup normalizers on all generated DAEO lanes:

```sh
--normalize drop-consts --normalize unreachable-control-debris
```

These normalizers cover only the documented dropped-constant and unreachable/control debris families. Any remaining mismatch still requires an agent semantic, size, validity, or tool-failure classification.

Recommended dedicated closeout lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --gen-valid-profile dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-profile-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

## Required closeout matrix

Report these independently with a freshly built explicit native binary:

1. regular GenValid: `100000`, seed `0x5eed`;
2. explicit wasm-smith: `10000`, seed `0x5eed`, `--wasm-smith`;
3. dedicated `dae-optimizing`: `10000`, seed `0x5eed`;
4. `random-all-profiles`: `10000`, seed `0x5555`.

For each lane report requested/compared counts, normalized and cleanup-normalized matches, raw mismatches, validation/generator/property failures, command-failure classes, cache counters, and selected subprofile counts when available.

## Fresh current evidence

Research note [`1568`](../../../raw/research/1568-2026-07-13-daeo-fresh-dedicated-and-regular-compare.md) records post-tuple-cleanup evidence from native commit `cf08ff06f`:

- dedicated `.tmp/pass-fuzz-dae-optimizing-dedicated-10000-20260713-post-tuple`: `10000/10000` normalized, zero cleanup-normalized matches, mismatches, or failures, selected `dae-optimizing=10000`, Binaryen cache `10000/0`;
- regular `.tmp/pass-fuzz-dae-optimizing-genvalid-100000-20260713-post-tuple`: `100000/100000` normalized, zero cleanup-normalized matches, mismatches, or failures, Binaryen cache `100000/0`.

The explicit wasm-smith, random-all, and scheduled O4z neighborhood/performance evidence still require a fresh post-change refresh before final closeout.
