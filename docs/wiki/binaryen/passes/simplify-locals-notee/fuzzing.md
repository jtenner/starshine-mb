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
  - ../simplify-locals/fuzzing.md
  - ../../../tooling/pass-fuzz-compare.md
---

# Binaryen `simplify-locals-notee` Fuzzing Status

## Current state: planned, not runnable

Do **not** treat `bun fuzz compare-pass --pass simplify-locals-notee ...` as current Starshine-vs-Binaryen evidence.

- The harness allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) contains neither Binaryen's `simplify-locals-notee` spelling nor the local historical placeholder.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) preserves only `simplify-locals-no-tee` as a **Removed** local name; it is not an active alias for the upstream pass.
- Therefore a rejected upstream spelling, a rejected local placeholder, or zero compared cases proves only spelling/registry status. It does not exercise the no-new-tee policy.

Safe inspection only:

```text
bun fuzz compare-pass --list-passes
```

## Future executable lane

First choose and document an active local spelling and map it to Binaryen `--simplify-locals-notee`. Then add focused tests/profile coverage for single-use sinks, multi-use candidates that must not grow a tee, structure formation that remains allowed, late equivalent-copy/dead-set cleanup, and effect/trap/EH barriers. Keep this separate from the active full [`../simplify-locals/fuzzing.md`](../simplify-locals/fuzzing.md) lane and from the no-structure sibling.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass <chosen-local-spelling> --count 10000 --seed 0x5eed \
  --gen-valid-profile <simplify-locals-notee-profile> \
  --out-dir .tmp/pass-fuzz-simplify-locals-notee --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

This is a future template, not a current runnable command.
