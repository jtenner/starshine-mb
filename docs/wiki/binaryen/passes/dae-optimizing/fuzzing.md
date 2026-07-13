---
kind: workflow
status: supported
last_reviewed: 2026-07-13
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/research/1568-2026-07-13-daeo-fresh-dedicated-and-regular-compare.md
  - ../../../raw/research/1569-2026-07-13-daeo-fresh-wasm-smith-and-random-all.md
  - ../../../raw/research/1570-2026-07-13-daeo-scheduled-replay-localization-safety.md
  - ../../../raw/research/1571-2026-07-13-daeo-post-scratchfloor-regular-and-wasm-smith.md
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

Research note [`1569`](../../../raw/research/1569-2026-07-13-daeo-fresh-wasm-smith-and-random-all.md) completes the fresh direct matrix:

- explicit wasm-smith requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `1`, mismatches `0`, with `44` Binaryen/oracle tool failures and no Starshine failure;
- random-all requested/compared `10000/10000`, normalized `9633`, left `367` byte-identical previously reviewed residuals (`dae-effectful-args=124`, `coverage-forced-portable=243`), and had zero failures. The two residual families are agent-classified as measured/source-backed Starshine cleanup wins; the aggregate deltas are `-110219` raw, `-797486` canonical, and `-5465849` WAT bytes, with no canonical/WAT-positive case.

Research note [`1570`](../../../raw/research/1570-2026-07-13-daeo-scheduled-replay-localization-safety.md) adds post-fix scheduled evidence: public `optimize`, public `shrink`, and synthesized `-O4z` each run DAEO exactly once in the locked late neighborhood and produce the same valid `38`-byte output as Binaryen O4z on the dedicated profile. It also fixes an artifact-discovered scratch-local collision and reruns the dedicated lane at `10000/10000` normalized. The current stripped wasm-gc artifact meets the pass-local ratio target (`9692.498ms` Starshine versus `8083.49ms` Binaryen) but remains blocked at Starshine final validation on nondefaultable GC body-local initialization.

Research note [`1571`](../../../raw/research/1571-2026-07-13-daeo-post-scratchfloor-regular-and-wasm-smith.md) refreshes two more lanes with the post-fix native binary SHA-256 `5ee57c2cb70bc0a73faff5831fbc93db45ad3b7f9aac522e6d714f52f4ff50da`:

- regular GenValid `.tmp/pass-fuzz-dae-optimizing-genvalid-100000-post-scratchfloor-20260713`: `100000/100000` normalized, zero mismatches or failures, Binaryen cache `100000/0`;
- explicit wasm-smith `.tmp/pass-fuzz-dae-optimizing-wasm-smith-10000-post-scratchfloor-20260713`: requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `1`, zero mismatches and no Starshine failures; the `44` command failures are the unchanged Binaryen/oracle classes (`rec-group-zero=39`, invalid-tag=1, table-index=1, bad-section-size=3), with caches wasm-smith `10000/0`, Binaryen `9956/0`, and Binaryen failures `44/0`.

The post-fix dedicated, regular, and wasm-smith lanes are current. The random-all lane above remains pre-fix evidence and must be refreshed before final closeout.
