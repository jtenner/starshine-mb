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
