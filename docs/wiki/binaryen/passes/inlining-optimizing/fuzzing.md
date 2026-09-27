---
kind: workflow
status: supported
last_reviewed: 2026-09-27
sources:
  - ../../../tooling/tracing-playbook.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ./index.md
related:
  - ./starshine-port-readiness-and-validation.md
  - ../inlining/fuzzing.md
---

# `inlining-optimizing` fuzzing and performance

## September 27 performance-campaign renewal

The [shared final campaign](../../../tooling/tracing-playbook.md#september-27-2026-precompute-cleanup-and-pass-allocation-campaign)
uses native CLI `5d009c4396b65d613acdc187e443f6c2cee843c7bfbc48ee726ba633de2aac54`,
verified Binaryen 133, seed `0x5eed`, `--jobs auto --max-subprocesses 8` and 10,000 cases
per lane. It supersedes earlier current-baseline wording; historical v131/v132
results retain their original scope. The shared report owns exact profiles,
normalizers, cache use, runtime limits, size deltas and baseline replays.

| Lane | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | ---: | ---: | ---: | ---: |
| `inlining-optimizing` | 10,000 / 0 | 0 | 0 | 10,000 / 0 |

All listed lanes report zero validation, generator, property, command and observed
Starshine/original semantic failures. Runtime-blocked cases remain unverified;
shape/size classifications and any scoped exceptions are agent judgments in
the shared report, not conclusions implied by validation or normalization.

Local reports: `.tmp/pass-perf-campaign-20260927/final-fuzz-inlining-optimizing/result.json`.

## September 26 final allocation/indexing renewal

The [final shared campaign](../../../tooling/tracing-playbook.md#september-26-2026-pass-time-allocation-and-indexing-renewal)
uses frozen native CLI `da5f112b6bbf092476d2d6ac6694128e19adca3d288003526ab01c3e0b0bfcbb`,
verified Binaryen 133 and 10,000 cases per documented aggregate at seed `0x5eed`.
The shared record owns exact commands, profiles, normalizers, cache counts,
runtime limits and baseline replays. This supersedes earlier current-baseline
wording; historical v131/v132 results keep their original scope.

| Lane | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | ---: | ---: | ---: | ---: |
| `inlining-optimizing` | 10,000 / 0 | 0 | 0 | 10,000 / 0 |

All listed lanes report zero validation, generator or command failures and no
observed Starshine/original semantic mismatches. Cases blocked on the original
input remain unverified.
Residuals remain open parity gaps; canonically larger outputs remain quality
gaps even when cleanup normalization matches. Valid or smaller output alone is not an accepted win. Saved residuals and all canonically larger
cases reproduce the starting compiler bytes, as recorded in the shared replay.

Local reports: `.tmp/pass-perf-work-20260926/final4-fuzz-inlining-optimizing/result.json`.

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Historical official-v131 closeout

The August 12 guarded-large-module refresh uses native SHA-256 `04c07833321cb6b6013f3ae2cbba4dc692ea802ff6f5a04810b2640120768c10` and the same explicit verified Binaryen v131 oracle. The dedicated `inlining-optimizing-all` lane at `.tmp/pass-fuzz-inlining-optimizing-v131-onecaller4-10000-20260812` compares and normalizes `10000/10000`, with zero mismatches and zero validation/property/generator/command failures. Binaryen cache is `9984` hits / `16` misses. This directly refreshes the pass after the O4z-only 286+-definition call/bulk-memory fallback admitted shrinking-trivial helpers, the default two-instruction always-inline class, and one-caller helpers through four instructions; the generated aggregate remains exact because its direct modules do not require the production guard.

```text
.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000
pass: inlining-optimizing
profile: inlining-optimizing-all
seed: 0x5eed
jobs: 16
10000/10000 compared
10000 normalized matches
0 mismatches
0 validation failures
0 property failures
0 generator failures
0 command failures
```

The run used:

- `_build/native/release/build/cmd/cmd.exe` from a current native release build;
- `.tmp/binaryen-version-131-bin/bin/wasm-opt` reporting `wasm-opt version 131 (version_131)`;
- explicit wasm-tools `1.251.0`;
- persistent Binaryen oracle caching.

Reproduction shape:

```text
bun fuzz compare-pass --pass inlining-optimizing --count 10000 --seed 0x5eed \
  --gen-valid-profile inlining-optimizing-all --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --out-dir .tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000
```

## 2026-08-13 appended-local liveness refresh

The conservative inline-replacement change that omits provably dead appended-local default initialization was refreshed against the verified-v131 aggregate at `.tmp/pass-fuzz-inlining-default-liveness-profile-10000`:

```text
pass: inlining-optimizing
profile: inlining-optimizing-all
seed: 0x5eed
jobs: 16
10000/10000 compared
10000 normalized matches
0 mismatches
0 validation failures
0 property failures
0 generator failures
0 command failures
Binaryen cache: 9984 hits / 16 misses
```

Selected profile counts were direct-wrapper `3019`, parameter-spill `2993`, return-call `1998`, and cleanup-payoff `1990`. Plain `inlining` independently remained exact at `10000/10000` with `pass-inlining` in `.tmp/pass-fuzz-inlining-default-liveness-plain-profile-10000`. These lanes complement the focused read-before-write tests for root writes, conditional reads, structured-control boundaries, and legacy exception bodies and catches.

## Aggregate profile

`inlining-optimizing-all` samples focused direct-wrapper, parameter-spill, return-call, and cleanup-payoff leaves. It is the ordinary dedicated profile for this pass. Use singleton leaves only for targeted reduction or regression work.

The profile complements, rather than replaces, focused tests for toolchain/no-inline policy, complete trivial classes, splitting, EH tail hoisting, multivalue/local repair, roots, metadata, exact nested order, and touched filtering.

## Plain sibling

Plain `inlining` independently reached `10000/10000` normalized matches in `.tmp/pass-fuzz-inlining-v131-closeout-10000`. Keep the two stop points separate in mismatch classification.

## Performance lane

The durable pass-local timing fixture is the inline-heavy helper-chain matrix under `.tmp/io-perf-20260705/measurements/`. It compares Starshine's traced `pass:inlining-optimizing` median with Binaryen `BINARYEN_PASS_DEBUG=1` over 1, 5, 10, 20, 50, and 100 helpers.

Accepted post-repair Starshine/Binaryen ratios are:

- 1 helper: `0.443x`;
- 5 helpers: `0.735x`;
- 10 helpers: `0.797x`;
- 20 helpers: `0.970x`;
- 50 helpers: `0.535x`;
- 100 helpers: `0.246x`.

Reopen performance on repeated median regression above `1x` Binaryen or a new nested-cleanup scaling cliff.

## Mismatch workflow

For any new failure:

1. preserve input, both raw outputs, normalized outputs, and command logs;
2. minimize before implementation;
3. identify direct-engine versus nested-cleanup ownership;
4. classify semantic, validation, size, performance, Starshine win, or tool/oracle failure;
5. add the focused regression first;
6. rerun the dedicated aggregate and the relevant singleton leaf.

Do not hide local-allocation, unreachable-control, or dropped-value differences behind a normalizer without source-backed semantic and size evidence.
