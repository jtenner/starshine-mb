---
kind: workflow
status: supported
last_reviewed: 2026-07-19
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

## Admission

`inlining` is an active module pass, admitted compare-pass name, and checked-in GenValid profile owner. Use a current native release binary and an explicit official Binaryen v131 oracle.

## 2026-08-27 wall-time repair renewal

Native SHA-256 `ae0f3a06cac025de34e729295b4343ce14bd2a85b9b92192900c2ea148a0f1c1` preserves the pre-repair canonical output while reducing repeated planning, HOT classification, graph analysis, caller reconstruction, and prune allocation.

- Regular GenValid: `.tmp/pass-fuzz-inlining-wall-regular-10000` is `10000/10000` normalized with zero mismatches or validation/property/generator/command failures, deterministic bytes `10000/10000`, codec idempotence `10000/10000`, external `wasm-tools` validation, and canonical equality `10000/10000` at `42,157,334` bytes per tool.
- Dedicated `pass-inlining`: `.tmp/pass-fuzz-inlining-wall-profile-10000-noreduce` completes `10000/10000` with zero Starshine validation/property/generator/command failures. Every raw mismatch is canonically smaller Starshine output: `84,211,036` versus `84,450,492` Binaryen bytes. The sampled family removes retained unbranched `block { unreachable }` wrappers. A detached clean committed-HEAD replay under `.tmp/inlining-perf-20260827/clean-head-replay/` is byte-identical to the repaired binary, so this output family predates the performance slice and is an inspected cleanup win rather than a new regression. The first attempted reducer-enabled lane stopped after 121 records at its independent two-hour timeout because every case triggered expensive reduction; no subprocesses remained.
- Runtime-callable: `.tmp/pass-fuzz-inlining-wall-runtime-100` completes 100/100 self-semantic checks with 100 exact runtime matches, zero blocked/mismatching/failing cases, and 100 canonically smaller Starshine outputs. The selected leaves are return-call, cleanup-payoff, direct-wrapper, and parameter-spill.

Canonical timing evidence is `.tmp/inlining-perf-20260827/retained-endpoint/median.json`: Starshine medians are `2451.927ms` pass-local and `3640.708ms` no-trace command versus Binaryen `1031.770ms` and `1601.316ms`. Traced/no-trace outputs are byte-identical in every sample, and raw output remains SHA-256 `bc8988df20e39e1430f9ef5246081346918acf3c92a55fc9f0b65040b18bdce4`. The P0 remains open because both ratios are still above `2x`.

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
