---
kind: workflow
status: working
last_reviewed: 2026-07-18
sources:
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `type-ssa` Fuzzing Profile

## Current status: planned, not runnable

`type-ssa` is upstream-only in Starshine today: it has no registry entry or owner, and the compare harness does not list `--type-ssa` in `SUPPORTED_PASS_FLAGS`. Any current command fails before a local transform runs, so it provides no Binaryen-parity evidence.

## Required future profile

A useful lane must be GC-aware and target allocation-type splitting rather than ordinary local SSA. The default portable generator cannot establish this surface by request count alone.

Before a lane becomes runnable, require active local module-pass dispatch, harness/oracle admission, a meaningful GC allocation profile, and reduced fixtures for:

- selected `struct.new`, `array.new`, `array.new_data`, `array.new_elem`, and `array.new_fixed` candidates;
- fresh private subtype/rec-group construction and allocation-result retagging;
- exact-observation blockers and public/final/open-disabled/descriptor bailouts;
- module-code, global, and element-segment type uses; and
- validator and binary roundtrip checks after every type-index remap.

Use [`created-exact-types-control-values-and-signature-rewrites.md`](created-exact-types-control-values-and-signature-rewrites.md) for the corrected allocation-subtype contract. A valid output alone is not enough: exact-type observation and rec-group remapping require focused semantic fixtures.

## Future lane template

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass type-ssa --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-type-ssa --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile <future-gc-allocation-profile> \
  --require-feature gc --min-compared <meaningful-allocation-count>
```

This is a future template only. Do not publish it as runnable until the four eligibility gates pass and the profile manifest proves it produced eligible allocation cases.
