---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-added-constants-propagate/fuzzing.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `optimize-added-constants` Fuzzing Status

## Current state: planned, not runnable

Do **not** treat `bun fuzz compare-pass --pass optimize-added-constants ...` as current Starshine-vs-Binaryen evidence.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does **not** list `optimize-added-constants` in `SUPPORTED_PASS_FLAGS`, so the harness rejects the request before generation or comparison.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) marks the name **Removed**; there is no active local transform or dispatcher route.
- A parser or removed-pass rejection proves only present admission status. It is not a smoke result and does not exercise Binaryen's `--low-memory-unused` contract.

Use `bun fuzz compare-pass --list-passes` only as a safe roster check.

## Future executable lane

Before a runnable lane exists, Starshine needs an active direct address-to-offset implementation, explicit harness admission/mapping, and fixtures or a profile that proves the required `--low-memory-unused` option plus direct `load`/`store` pointer shapes. The corpus must include strict threshold edges, merged offsets, memory32/memory64 constant-pointer overflow cases, and no-change/effectful pointer boundaries.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass optimize-added-constants --count 10000 --seed 0x5eed \
  --gen-valid-profile <low-memory-direct-offset-profile> \
  --out-dir .tmp/pass-fuzz-optimize-added-constants --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

This is a future template. Keep the propagation sibling's different local-pair proof surface separate in [`../optimize-added-constants-propagate/fuzzing.md`](../optimize-added-constants-propagate/fuzzing.md).
