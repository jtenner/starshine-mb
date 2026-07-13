# DAEO post-scratch-floor random-all refresh

Date: 2026-07-13

## Scope

This slice completed the direct `dae-optimizing` compare-matrix refresh after the transient-local scratch-floor and transactional local-projection fix from research note `1570`. It reran the required random all-profiles GenValid lane with the current native release binary and compared every residual artifact against the pre-fix lane from research note `1569`.

The explicit tested binary was `_build/native/release/build/cmd/cmd.exe`, SHA-256 `5ee57c2cb70bc0a73faff5831fbc93db45ad3b7f9aac522e6d714f52f4ff50da`. The lane used seed `0x5555`, `--jobs auto`, the `random-all-profiles` composite, the required DAE normalizers `drop-consts` plus `unreachable-control-debris`, and disabled mismatch reduction for counted closeout evidence.

## Command

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass dae-optimizing --gen-valid-profile random-all-profiles --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae-optimizing-random-all-10000-post-scratchfloor-20260713 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```

## Result

- requested/compared: `10000/10000`;
- normalized matches: `9633`;
- cleanup-normalized matches: `0`;
- raw mismatches: `367`;
- validation/generator/property/command failures: `0/0/0/0`;
- Binaryen cache: `10000/0` hits/misses;
- Binaryen failure and wasm-smith caches: `0/0`;
- jobs: `16` (`auto`);
- mismatch reduction: disabled.

The selected-profile distribution for the full composite is retained in `result.json`. Every mismatch belongs to the same two reviewed families:

| Selected profile | Cases | Starshine raw delta | canonical delta | WAT delta | positive raw/canonical/WAT cases |
| --- | ---: | ---: | ---: | ---: | --- |
| `dae-effectful-args` | 124 | `-744` | `-744` | `-6200` | `0/0/0` |
| `coverage-forced-portable` | 243 | `-109475` | `-796742` | `-5459649` | `122/0/0` |
| total | 367 | `-110219` | `-797486` | `-5465849` | `122/0/0` |

## Residual identity check

The post-fix and pre-fix failure-directory sets are identical: `367` directories in each lane, with no added or removed case. A SHA-256 comparison covered all ten files in every directory — input wasm/WAT, Binaryen raw/canonical/WAT, Starshine raw/canonical/WAT, metadata, and failure text — for `3670` comparisons. Changed files: `0`.

The local safety fix therefore did not create, remove, or alter a random-all residual. The same inspected transform and generator/control contracts remain applicable.

## Agent classifications

- `dae-effectful-args` — **measured Starshine win**. Binaryen preserves each removed effectful actual through a fresh local that is never read, while Starshine executes the same producer in the same order and drops its unused result directly. Starshine is smaller in every raw, canonical, and WAT case.
- `coverage-forced-portable` — **measured/source-backed Starshine cleanup win**. The generated coverage prelude reaches terminal control before later syntactic coverage debris; Starshine removes only the reviewed pure/nontrapping dead prefix and unreachable-tail material while preserving terminal control. Every canonical and WAT artifact is smaller. The `122` raw-positive writer-layout cases are not used as the win argument; the inspected semantic contract, unchanged artifact identity, and canonical/WAT measurements are the evidence.

These are agent judgments, not harness-provided semantic claims. There are no unknown/risky, canonical- or WAT-size-losing, validation, or true-semantic residuals in the lane.

## Direct matrix state

The complete direct post-scratch-floor matrix is current:

- dedicated `dae-optimizing`: `10000/10000` normalized, zero failures;
- regular GenValid: `100000/100000` normalized, zero failures;
- explicit wasm-smith: `9956` compared, `9955` normalized plus `1` cleanup-normalized, zero mismatches and no Starshine failures; `44` Binaryen/oracle failures;
- random-all: `10000` compared, `9633` normalized plus `367` unchanged measured/source-backed Starshine-win residuals, zero failures.

DAEO is not yet closed. The current-artifact nondefaultable-local final-validation owner, full `moon test`, full release validation, docs/backlog reconciliation, and `.mbti` review remain open.
