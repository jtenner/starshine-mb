# DAEO fresh wasm-smith and random-all evidence

Date: 2026-07-13

## Scope

This slice completed the two remaining direct `dae-optimizing` compare lanes after the touched-function tuple cleanup and exact trap-preservation changes. Both commands used the freshly rebuilt `_build/native/release/build/cmd/cmd.exe`, `--jobs auto`, and the required `drop-consts` plus `unreachable-control-debris` normalizers. Mismatch reduction was disabled for counted closeout runs.

## Explicit wasm-smith

Command:

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-wasm-smith-10000-20260713-post-tuple --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

Result:

- requested: `10000`;
- compared: `9956`;
- normalized matches: `9955`;
- cleanup-normalized matches: `1`;
- raw mismatches: `0`;
- validation/generator/property failures: `0/0/0`;
- command failures: `44`, all Binaryen/oracle tool classes:
  - `binaryen-rec-group-zero=39`;
  - `binaryen-invalid-tag-index=1`;
  - `binaryen-table-index-out-of-range=1`;
  - `binaryen-bad-section-size=3`;
- cache: wasm-smith `10000/0`, Binaryen `9956/0`, Binaryen failures `44/0` hits/misses.

Agent classification: direct parity is green for every comparable case. The one cleanup-normalized case is within the explicit DAE debris contract. The 44 non-compared cases are tool/Binaryen failures, not Starshine validation or semantic failures. The recovered imported-tag type-liveness repair remains closed: no Starshine command failure recurred.

## Random all-profiles

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass dae-optimizing --gen-valid-profile random-all-profiles --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-random-all-10000-20260713-post-tuple --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

Result:

- requested/compared: `10000/10000`;
- normalized matches: `9633`;
- cleanup-normalized matches: `0`;
- raw mismatches: `367`;
- validation/generator/property/command failures: `0/0/0/0`;
- Binaryen cache: `10000/0` hits/misses;
- reduction: disabled.

All 367 residuals are exactly the two previously reviewed generator families:

| Selected profile | Cases | Starshine raw delta | canonical delta | WAT delta | positive raw/canonical/WAT cases |
| --- | ---: | ---: | ---: | ---: | --- |
| `dae-effectful-args` | 124 | `-744` | `-744` | `-6200` | `0/0/0` |
| `coverage-forced-portable` | 243 | `-109475` | `-796742` | `-5459649` | `122/0/0` |
| total | 367 | `-110219` | `-797486` | `-5465849` | `122/0/0` |

A ten-file SHA-256 comparison for every residual directory against `.tmp/pass-fuzz-dae-optimizing-random-all-10000-after-typeidx-body-installation-20260712` found `0` changed cases across `3670` file comparisons: input wasm/WAT, Binaryen raw/canonical/WAT, Starshine raw/canonical/WAT, metadata, and failure text are byte-identical. The current tuple cleanup therefore did not create or alter a random-all residual.

### Agent classifications

- `dae-effectful-args` — **measured Starshine win**. Binaryen preserves a fresh local around each removed unused actual (`call producer; local.set`, with no later read), while Starshine emits `call producer; drop`. Both execute the same effectful producer in the same order and feed the same kept helper actual; Starshine removes the unused local and is smaller in every raw, canonical, and WAT artifact. Representative current case `case-007454-gen-valid` has exactly this shape.
- `coverage-forced-portable` — **measured/source-backed Starshine cleanup win** for the unchanged reviewed family. The generated coverage prelude reaches terminal control before later syntactic coverage debris; Starshine removes only the already reviewed pure/nontrapping dead prefix and unreachable-tail material while preserving the terminal control. The family is byte-identical to the prior reviewed lane, has no validation or command failures, and is smaller in every canonical/WAT artifact. Raw writer layout is larger in 122 cases, so raw bytes alone are not used as the win argument; canonical/WAT totals and the inspected semantic contract are the evidence.

Neither family is classified merely because outputs validate or because aggregate output is smaller. The classification rests on the inspected transform shapes, generator/control contract, unchanged prior reviewed artifacts, and per-family measurements. There are no unknown/risky, size-losing canonical, validation, or true-semantic residuals in this lane.

## Direct matrix state

Together with research note `1568`, the fresh direct DAEO matrix is now complete:

- regular GenValid `100000/100000` normalized;
- dedicated `dae-optimizing` `10000/10000` normalized;
- explicit wasm-smith `9956` compared, `9955` normalized plus `1` cleanup-normalized, zero mismatches, 44 Binaryen/tool failures;
- random-all `10000` compared, `9633` normalized plus `367` measured/source-backed Starshine-win residuals, zero failures.

DAEO still is not closed by this note. Scheduled public `optimize` / `shrink` O4z artifact and performance evidence, full release validation, docs/backlog reconciliation, and final `.mbti` review remain.
