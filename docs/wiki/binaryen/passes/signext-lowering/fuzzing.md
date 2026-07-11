---
kind: workflow
status: working
last_reviewed: 2026-07-10
sources:
  - ../../../raw/binaryen/2026-07-10-signext-lowering-current-main-refresh.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `signext-lowering` Fuzzing Profile

## Current status: planned, not runnable

Do **not** run or advertise a compare-pass smoke lane yet. `signext-lowering` is absent from the harness `SUPPORTED_PASS_FLAGS` list in [`scripts/lib/pass-fuzz-compare-task.ts:246-292`](../../../../../scripts/lib/pass-fuzz-compare-task.ts), and Starshine has no active registry or dispatcher case. The command below therefore fails before generation; it is not parity evidence:

```text
bun fuzz compare-pass --pass signext-lowering ...
```

This follows the four-gate rule in [`../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight): until both the harness and Starshine admit a real transform, this page describes a **planned fuzzing profile** only.

## Future runnable lane

After a public implementation is registered in Starshine **and** admitted by `SUPPORTED_PASS_FLAGS`, start with an enabled-sign-extension fixture/profile. Binaryen's current owner is feature-gated: without `FeatureSet::SignExt`, it returns without rewriting. The first lane must therefore prove that generated inputs exercise the enabled path, set a meaningful `--min-compared`, and separately test the no-feature no-op boundary.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass signext-lowering --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-signext-lowering --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count> [--gen-valid-profile <future-profile>]
```

Before calling that lane signoff, include reduced fixtures for all five rewrite shapes, effectful children, `i64.extend_i32_s` preservation, enabled-feature cleanup, and no-feature no-op behavior. The Binaryen gate and feature-clear distinction are recorded in [`../../../raw/binaryen/2026-07-10-signext-lowering-current-main-refresh.md`](../../../raw/binaryen/2026-07-10-signext-lowering-current-main-refresh.md).
