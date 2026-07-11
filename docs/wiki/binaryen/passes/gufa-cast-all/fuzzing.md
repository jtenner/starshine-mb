---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `gufa-cast-all` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `gufa-cast-all` today.

- `gufa-cast-all` is a `BoundaryOnly` registry name in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), and [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) has neither a shared GUFA owner nor a post-refinalize cast-insertion path.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--gufa-cast-all` in `SUPPORTED_PASS_FLAGS`; the harness rejects the argument before generation or either optimizer runs.
- A rejected command, command failure, or zero compared cases is a **status check**, not Binaryen-parity evidence. Apply the four admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the current harness roster:

```text
bun fuzz compare-pass --list-passes
```

## Future admission requirements

Enable a lane only after the shared `gufa` oracle/dispatcher gates are met and all of these sibling-specific requirements are true:

1. Starshine has a separate post-rewrite cast-all walk that only considers castable reference sites and validates every inserted cast;
2. the walk preserves feature-sensitive exactness downgrades and does **not** run the optimizing sibling's cleanup pair;
3. `SUPPORTED_PASS_FLAGS` admits `--gufa-cast-all`; and
4. a closed-world GC/reference fixture profile reaches meaningful compared cases with an explicit `--min-compared` threshold.

The initial corpus must cover struct and function reference cast insertion, existing-cast refinement versus fresh insertion, descriptor/exactness feature boundaries, trapping behavior, preserved uncastable/no-improvement cases, and imported/exported tag or EH conservatism. See [`./cast-insertion-exactness-and-boundaries.md`](./cast-insertion-exactness-and-boundaries.md) and [`./wat-shapes.md`](./wat-shapes.md).

Candidate command shape after those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass gufa-cast-all --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-gufa-cast-all --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. No new external source ingest was needed for this correction: current harness and registry code decide admission, while the existing sibling dossier remains the upstream-transform evidence.
