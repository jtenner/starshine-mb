# DAEO post-scratch-floor regular and wasm-smith refresh

Date: 2026-07-13

## Scope

This slice refreshed the regular GenValid and explicit wasm-smith `dae-optimizing` closeout lanes after the behavior-changing transient-local scratch-floor and transactional local-projection fix in research note `1570`.

The current native release binary was rebuilt explicitly with:

```sh
moon build --target native --release src/cmd
```

The build was current with no work needed. The tested binary was `_build/native/release/build/cmd/cmd.exe`, SHA-256 `5ee57c2cb70bc0a73faff5831fbc93db45ad3b7f9aac522e6d714f52f4ff50da`, timestamp `2026-07-13 11:26:16 UTC`. Both compare lanes used `--jobs auto`, that explicit binary, seed `0x5eed`, and the required DAE normalizers `drop-consts` plus `unreachable-control-debris`.

## Regular GenValid 100000

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-genvalid-100000-post-scratchfloor-20260713 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result:

- requested/compared: `100000/100000`;
- selected profile: `binaryen-oracle-portable=100000`;
- normalized matches: `100000`;
- cleanup-normalized matches: `0`;
- raw mismatches: `0`;
- validation/generator/property/command failures: `0/0/0/0`;
- cache: wasm-smith `0/0`, Binaryen `100000/0`, Binaryen failures `0/0` hits/misses;
- jobs: `16` (`auto`).

Agent classification: every generated case is a direct normalized Binaryen behavior-parity match. There is no residual whose safety must be inferred from validity or size.

## Explicit wasm-smith 10000

Command:

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-wasm-smith-10000-post-scratchfloor-20260713 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result:

- requested: `10000`;
- compared: `9956`;
- normalized matches: `9955`;
- cleanup-normalized matches: `1`;
- raw mismatches: `0`;
- validation/generator/property failures: `0/0/0`;
- command failures: `44`, all Binaryen/oracle tool failures:
  - `binaryen-rec-group-zero=39`;
  - `binaryen-invalid-tag-index=1`;
  - `binaryen-table-index-out-of-range=1`;
  - `binaryen-bad-section-size=3`;
- cache: wasm-smith `10000/0`, Binaryen `9956/0`, Binaryen failures `44/0` hits/misses;
- jobs: `16` (`auto`).

Agent classification: all `9956` comparable cases match Binaryen directly or through the explicit DAE cleanup contract. The `44` omitted cases are tool/Binaryen failures, not Starshine command, validation, or semantic failures. The imported-tag type-liveness and transient-local fixes therefore remain closed on this external-generator lane.

## Closeout state

The post-scratch-floor dedicated, regular, and wasm-smith lanes were green, and research note `1572` completed that matrix. Research note `1573` later fixed a separate DAEO flattened rec-group type-index bug, reran all four lanes with the final current binary, produced valid artifact output, completed the release gate, and found no `.mbti` diff. The remaining artifact blocker is a measured size-losing canonical parity gap.
