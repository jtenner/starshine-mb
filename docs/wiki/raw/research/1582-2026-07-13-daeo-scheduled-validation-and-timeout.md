# DAEO scheduled evidence, release validation, and large-artifact timeout

Date: 2026-07-13

## Scope

This slice refreshes the scheduled `optimize` / `shrink` / synthesized `-O4z` evidence after note `1580`, runs the full release validation ladder, reviews public API snapshots, and records the current large-artifact scheduled-performance blocker without hiding it behind direct-pass results.

Fresh explicit native binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `48abcd5da8b92b45423915c0cd70740ff072cd420d21ab76e55ceabb0e5e5812`.

## Ordered dedicated-profile scheduling

Input:

- `.tmp/pass-fuzz-dae-optimizing-dedicated-10000-post-param-chain-20260713/inputs/gen-valid/gen-valid-000001.wasm`;
- `94` bytes.

Outputs and traces live under `.tmp/daeo-scheduled-post-param-chain-20260713/`.

Public `--optimize`, public `--shrink`, and synthesized `-O4z` each:

- execute exactly one top-level `pass[dae-optimizing]:start`;
- place it immediately after the late `heap-store-optimization` line and before `inlining-optimizing`;
- validate with `wasm-tools validate --features all`;
- produce the same `38`-byte output;
- produce SHA-256 `6412e2f194adbecb12178dc516b0e5e491eec20f83c8d73bf6d82a8095cd3c30`;
- complete in `5ms` whole-command wall time.

Exact ordered trace positions:

| mode | late HSO | DAEO start | inlining-optimizing start | DAEO pass-local |
|---|---:|---:|---:|---:|
| `--optimize` | 268 | 269 | 491 | `668us` |
| `--shrink` | 268 | 269 | 491 | `665us` |
| `-O4z` | 235 | 236 | 425 | `733us` |

The public schedule tables/tests remain unchanged: exactly one `dae-optimizing` after late `heap-store-optimization` and before `inlining-optimizing` in both public presets.

## Large current-artifact scheduled blocker

Input:

- `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`;
- `3204405` bytes;
- valid under wasm-tools.

A traced public `--optimize` attempt under `.tmp/daeo-scheduled-current-artifact-post-param-chain-20260713/optimize.trace` timed out after `7200s`. It produced about `24.7MB` / `178269` trace lines and never reached `pass[dae-optimizing]:start`; the tail remains in the pre-DAEO vacuum/remove-unused-names function lane with repeated `raw-vacuum-guarded-hazard` skips.

A second no-trace public `--optimize` attempt also timed out after `3600s` without producing an output. Therefore the blocker is not trace-volume-only. Public `--shrink` and `-O4z` large-artifact attempts were not rerun after the optimize timeout because they share the same pre-DAEO neighborhood and would not add DAEO-local attribution.

Agent attribution: concrete **pre-DAEO scheduled whole-command blocker**, centered in the earlier vacuum/remove-unused-names neighborhood, not a DAEO pass-local regression. Direct DAEO on the same input remains valid and within the pass-local ratio target (`5645.054ms` versus Binaryen `8083.49ms`). The representative scheduled large-artifact output/performance criterion is therefore blocked before DAEO executes; file the runtime owner under the existing whole-command/preset performance track rather than weakening the DAEO direct-pass claim.

## Validation

Final current-tree validation:

- `moon info`: `11` existing warnings, `0` errors;
- `moon fmt`: green;
- DAE white-box: `207/207`;
- pass-manager white-box: `217/217`;
- public DAEO: `310/310`;
- `moon test src/passes`: `5348/5348`;
- full `moon test`: `8805/8805`;
- native release build: green with existing warnings;
- `bun validate full --profile ci --target wasm-gc`: green at seed `1783976162242000`, including `8805/8805` Moon tests and every reported fuzz/roundtrip/validation suite;
- `.mbti` diff from pre-slice commit `b02d9115d` through the current commits: empty.

## Closeout status

DAEO remains active and must not be claimed complete.

Current completed evidence:

- exact Func-37/38/41 chain closure;
- current four-lane direct matrix;
- exact-once ordered dedicated-profile `optimize` / `shrink` / O4z scheduling;
- direct pass-local performance and validity;
- full release validation and empty `.mbti` diff.

Remaining blockers:

1. the direct current artifact still has a `+15995` canonical-byte gap versus Binaryen; note `1580` closes the exact-param owner but does not classify the remaining gap as a Starshine win;
2. scheduled current-artifact optimize/shrink/O4z output and timing cannot be captured because public optimize stalls for more than one hour in a pre-DAEO vacuum/remove-unused-names neighborhood;
3. the next iteration must attribute a new direct artifact diff family and separately reduce or route around the pre-DAEO scheduled whole-command blocker before final closeout.
