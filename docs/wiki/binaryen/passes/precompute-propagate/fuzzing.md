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
  - ../precompute/fuzzing.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `precompute-propagate` Fuzzing Status

## Current state: planned, not runnable

Do **not** advertise `bun fuzz compare-pass --pass precompute-propagate ...` as a current Starshine parity lane.

- The harness allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does **not** contain `precompute-propagate`, so command parsing fails before input generation or a comparison.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) records the local name as **Removed**, without an active descriptor or dispatch route.
- A parser rejection, removed-pass diagnostic, or zero compared cases is not evidence for the upstream propagate mode.

Use `bun fuzz compare-pass --list-passes` only to inspect the harness roster.

## Future executable lane

First land an active implementation and explicit Binaryen mapping. Then add a profile or direct fixture corpus that distinguishes this mode from active plain `precompute`: converged reaching-set literals, fallthrough values, defaultable-local entry values, parameter/nondefaultable-local bailouts, tuple/type agreement, and the single extra evaluation pass. Require a meaningful `--min-compared` threshold before calling a run signoff evidence.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass precompute-propagate --count 10000 --seed 0x5eed \
  --gen-valid-profile <precompute-propagate-local-facts-profile> \
  --out-dir .tmp/pass-fuzz-precompute-propagate --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

This is a future template only. The runnable plain-pass guidance remains in [`../precompute/fuzzing.md`](../precompute/fuzzing.md).
