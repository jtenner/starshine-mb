---
kind: workflow
status: supported
last_reviewed: 2026-09-03
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ./index.md
related:
  - ./starshine-port-readiness-and-validation.md
  - ../inlining-optimizing/fuzzing.md
---

# `inlining` fuzzing and signoff

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Admission

`inlining` is an active module pass, admitted compare-pass name, and checked-in GenValid profile owner. Use a current native release binary and an explicit official Binaryen v132 oracle. The v131 campaigns below retain their historical identities.

## 2026-09-03 source-sized COW reservation renewal

The retained input is `.tmp/production-smoke/size-attribution-accurate/common-star-canonical.wasm`, 4,977,401 bytes with SHA-256 `4acd06537e4466bc372a73c2e37da46f1cd94c3baca1fd62c1aa5fe76b944721`. The oracle is explicit `wasm-opt version 131 (version_131)`, SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`. The baseline native is `.tmp/module-pass-sweep-20260903/bin/before-cmd.exe`, SHA-256 `3a60274e4ce8587de5b05385f736fce5b25e99735e8c2407e9320d5da8711101`; the source-sized-reservation native is `.tmp/module-pass-sweep-20260903/bin/cow-capacity-cmd.exe`, SHA-256 `222b78b78f82f2c704b968b8cfc7403ebf634b16c20c68743a4b7374994430bf`.

After one warmup per binary, five serial pairs ran under one held `/tmp/starshine-perf-sweep-heavy.lock`. Pair order alternated before/after, after/before, before/after, after/before, before/after. Every harness invocation also ran the explicit v131 oracle; `--moon /bin/true` bypassed the harness build preflight because both native binaries were already built and hashed.

| Pair | Before command | After command | v131 command | Before pass | After pass | v131 pass |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3156.258 | 3058.301 | 1767.911 | 2289.935 | 2252.623 | 1186.630 |
| 2 | 3083.828 | 3090.804 | 1755.411 | 2271.262 | 2253.548 | 1190.240 |
| 3 | 3042.282 | 2977.826 | 1738.366 | 2239.377 | 2175.963 | 1139.950 |
| 4 | 3233.237 | 3172.244 | 1684.308 | 2320.021 | 2377.634 | 1131.560 |
| 5 | 3147.313 | 3152.840 | 1675.968 | 2317.502 | 2302.402 | 1090.620 |
| median | 3147.313 | 3090.804 | 1738.366 | 2289.935 | 2253.548 | 1139.950 |

Times are milliseconds. Candidate medians improve by `56.508ms` (`1.80%`) command and `36.387ms` (`1.59%`) pass-local. Command time improves in three of five pairs; pass-local, aggregate rewrite, and the late one-function rewrite improve in four of five. Pair 4 is a correlated candidate-side pass/rewrite outlier, so the retained claim is limited to the stable owner medians rather than its best individual samples. The paired oracle ratios from this isolated campaign were `1.778x` command and `1.977x` pass-local; the integrated gate status below supersedes those environment-sensitive ratios without changing the causal before/after conclusion.

| Owner | Before samples | After samples | Median change |
|---|---|---|---:|
| aggregate `rewrite-all-calls` | 1231.137 / 1238.181 / 1203.694 / 1242.185 / 1257.042 | 1203.289 / 1208.505 / 1191.007 / 1305.864 / 1253.422 | `1238.181→1208.505ms` (`-2.40%`) |
| late one-function rewrite | 288.675 / 291.211 / 279.887 / 306.505 / 301.150 | 272.616 / 284.381 / 274.194 / 347.866 / 299.106 | `291.211→284.381ms` (`-2.35%`) |

The traced candidate's per-iteration `arrays:reserved_items:output_items` counters are deterministic in all five runs: `21253:384579:437397`, `13505:285708:314268`, `2799:82943:104407`, `212:10909:11292`, `1:54:281`, and final no-change `0:0:0`. Reserved capacity never exceeds produced output, including the small late rewrite, so the source-sized reservation does not create material retained-artifact over-allocation. The white-box regression also forces a 257-instruction source array, fails without a source-sized reservation, and permits only one reconstructed array.

Every before/after output is exact: raw 5,230,205 bytes, SHA-256 `bc8988df20e39e1430f9ef5246081346918acf3c92a55fc9f0b65040b18bdce4`; canonical 5,631,598 bytes, SHA-256 `1deb7e3918041984d774c86e7383df0b8a19be8f7246b9c5e4b8b38b4be418f0`. The v131 output is 6,776,619 bytes, SHA-256 `28374eeec04075ed2b280e0c67b79031e326631d53ecdd2b6d4a2b190e3c8acb`.

The source-pinned integrated run `.tmp/pass-performance-sweep-20260903-final-bracketed/` used final native SHA-256 `25dadf9167acd7c98dc86e26cae6a2ccd0135c58edd1efcfa7fb33ca5a177d0b`, one warmup, and three reference-bracketed samples. It reports Starshine `3091.212 +/- 4.150 ms` command / `2270.146 +/- 2.141 ms` pass-local versus Binaryen v131 `1609.625 +/- 12.177 ms` / `1057.560 +/- 19.430 ms`: the command gate is closed at `1.920x`, while pass-local remains open at `2.147x`. Final `.tmp/pass-fuzz-inlining-perf-sweep-final-10000/` is `10000/10000` canonical-equal with zero mismatches, validation failures, property failures, generator failures, or command failures.

Representative invocation inside the held lock:

```text
bun scripts/self-optimize-compare.ts \
  .tmp/production-smoke/size-attribution-accurate/common-star-canonical.wasm \
  --out-dir .tmp/module-pass-sweep-20260903/inlining-cow-ab/1-after \
  --starshine-bin .tmp/module-pass-sweep-20260903/bin/cow-capacity-cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --moon /bin/true --timing-only --wall-attribution --inlining
```

## 2026-08-27 wall-time repair renewal

Native SHA-256 `ae0f3a06cac025de34e729295b4343ce14bd2a85b9b92192900c2ea148a0f1c1` preserves the pre-repair canonical output while reducing repeated planning, HOT classification, graph analysis, caller reconstruction, and prune allocation.

- Regular GenValid: `.tmp/pass-fuzz-inlining-wall-regular-10000` is `10000/10000` normalized with zero mismatches or validation/property/generator/command failures, deterministic bytes `10000/10000`, codec idempotence `10000/10000`, external `wasm-tools` validation, and canonical equality `10000/10000` at `42,157,334` bytes per tool.
- Dedicated `pass-inlining`: `.tmp/pass-fuzz-inlining-wall-profile-10000-noreduce` completes `10000/10000` with zero Starshine validation/property/generator/command failures. Every raw mismatch is canonically smaller Starshine output: `84,211,036` versus `84,450,492` Binaryen bytes. The sampled family removes retained unbranched `block { unreachable }` wrappers. A detached clean committed-HEAD replay under `.tmp/inlining-perf-20260827/clean-head-replay/` is byte-identical to the repaired binary, so this output family predates the performance slice and is an inspected cleanup win rather than a new regression. The first attempted reducer-enabled lane stopped after 121 records at its independent two-hour timeout because every case triggered expensive reduction; no subprocesses remained.
- Runtime-callable: `.tmp/pass-fuzz-inlining-wall-runtime-100` completes 100/100 self-semantic checks with 100 exact runtime matches, zero blocked/mismatching/failing cases, and 100 canonically smaller Starshine outputs. The selected leaves are return-call, cleanup-payoff, direct-wrapper, and parameter-spill.

Canonical timing evidence is `.tmp/inlining-perf-20260827/retained-endpoint/median.json`: Starshine medians are `2451.927ms` pass-local and `3640.708ms` no-trace command versus Binaryen `1031.770ms` and `1601.316ms`. Traced/no-trace outputs are byte-identical in every sample, and raw output remains SHA-256 `bc8988df20e39e1430f9ef5246081346918acf3c92a55fc9f0b65040b18bdce4`. Those absolute values are historical and superseded by the integrated 2026-09-03 renewal above; the current pass-local ratio remains narrowly over `2x`.

## Current closeout

```text
.tmp/pass-fuzz-inlining-v131-closeout-10000
pass: inlining
profile: pass-inlining
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

Oracle and executable:

- `.tmp/binaryen-version-131-bin/bin/wasm-opt` reporting `wasm-opt version 131 (version_131)`;
- `_build/native/release/build/cmd/cmd.exe` from a current `moon build --target native --release src/cmd`.

Reproduction shape:

```text
bun fuzz compare-pass --pass inlining --count 10000 --seed 0x5eed \
  --gen-valid-profile pass-inlining --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --out-dir .tmp/pass-fuzz-inlining-v131-closeout-10000
```

## What the profile proves

`pass-inlining` is a bounded scalar direct/tail-call lane. It proves the ordinary registry, dispatcher, generator, encoder, validator, oracle, direct-call planner, and plain stop point over 10,000 deterministic cases.

It does not replace focused fixtures for every family. The `120/120` inlining tests and `14/14` white-box tests remain the evidence for:

- toolchain/no-inline policy;
- complete trivial classes and tuning boundaries;
- Pattern A/B splitting;
- multivalue and local repair;
- nullable/nonnullable locals;
- direct/indirect/ref tail handling;
- EH operand localization and hoisting;
- table64 spills and branch/catch depth repair;
- roots, helper deletion, metadata remap, and plain-vs-optimizing separation.

## Optimizing sibling

`inlining-optimizing` independently reached `10000/10000` normalized matches with its focused aggregate in `.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000`. Do not use optimizing cleanup to excuse a plain-pass mismatch; the public stop points remain distinct.

## Reopening rule

Save and minimize any new mismatch. Classify it as semantic, validation, size-losing, performance, tooling/oracle, or proven Starshine win. A raw output difference is not automatically acceptable, and a generic random no-op lane is not evidence for `inline-main`.

## 2026-09-10 recursive type indexing repair

Prebuilt native CLI SHA-256
`efab56b63e08234a8dbcb44fd9b32f6f836072eae185b862e1b04d4d423a6a6f`
passes both 10,000-case lanes at seed `0x5eed`, with pinned Binaryen 131,
`--jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20`:

- Regular GenValid: 10,000 normalized matches; canonical totals 42,157,334
  bytes for each tool.
- Aggregate `pass-inlining`: 10,000 normalized matches; canonical totals
  84,211,036 bytes for each tool.
- Both lanes: zero mismatches, validation/property/generator/command failures.

Raw outputs remain larger than Binaryen (42,190,083 and 127,110,648 bytes);
normalization removes that difference. These counts do not claim a raw size
win or new runtime coverage. Runtime evidence comes from the direct Dewdrop
source suite and the two engines. External generators were not requested.

The cold release build took 215.782 seconds; the cold focused native regression
compile took 51.581 seconds. These exceed Dewdrop's 30-second activity target
and remain build performance problems. The warm CLI regression takes 0.026
seconds. Build timings are separate from per-module optimization timings.

The full pinned native Starshine suite passes 10,988 tests in 429.197 seconds.
That aggregate lane is also reported over the parent project's activity budget.
`moon info` passes with no public API diff in 3.857 seconds.
