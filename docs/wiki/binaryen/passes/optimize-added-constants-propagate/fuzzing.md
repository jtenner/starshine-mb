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
  - ../optimize-added-constants/fuzzing.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `optimize-added-constants-propagate` Fuzzing Status

## Current state: planned, not runnable

Do **not** treat `bun fuzz compare-pass --pass optimize-added-constants-propagate ...` as a current smoke lane.

- `SUPPORTED_PASS_FLAGS` in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does **not** admit the pass, so it fails before any generated case reaches either optimizer.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) retains this local name as **Removed**, not active.
- A rejected request or zero compared cases is admission-status evidence only; it cannot establish parity for the propagate-specific local-pair analysis.

Safe inspection only:

```text
bun fuzz compare-pass --list-passes
```

## Future executable lane

In addition to the plain sibling's low-memory direct-address cases, a future lane must prove the extra propagation surface: conservative reaching-set/local-pair analysis, multiple-use bailouts, helper-local insertion or equivalent repair, and preservation of pointer/effect/trap behavior. Admit the local spelling and verify its Binaryen mapping before using a lane for evidence.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass optimize-added-constants-propagate --count 10000 --seed 0x5eed \
  --gen-valid-profile <low-memory-propagate-profile> \
  --out-dir .tmp/pass-fuzz-optimize-added-constants-propagate --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

This future template does not authorize a comparison against today's removed pass. See [`../optimize-added-constants/fuzzing.md`](../optimize-added-constants/fuzzing.md) for the direct-fold sibling boundary.
