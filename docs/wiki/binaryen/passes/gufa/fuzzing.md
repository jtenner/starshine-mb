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
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `gufa` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `gufa` today.

- `gufa` is a `BoundaryOnly` registry name in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), and [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) has no GUFA dispatcher or module-pass owner.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--gufa` in `SUPPORTED_PASS_FLAGS`; the harness rejects the argument before generating a module or invoking either optimizer.
- A rejected command, command failure, or zero compared cases is a **status check**, not Binaryen-parity evidence. Apply the four admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the current harness roster:

```text
bun fuzz compare-pass --list-passes
```

## Future admission requirements

Enable a lane only after all of the following are true:

1. Starshine has a real module-wide closed-world contents oracle, active `gufa` owner, registry admission, and dispatcher;
2. `SUPPORTED_PASS_FLAGS` admits `--gufa` and `--list-passes` reports it;
3. the Binaryen mapping includes the required closed-world execution policy; and
4. a GC/reference-capable generator profile or fixture corpus reaches meaningful cases with an explicit `--min-compared` threshold.

The first fixture/profile set must cover no-contents `unreachable` rewrites with preserved effects, unique literal/global/`ref.func` values, impossible and guaranteed `ref.eq` / `ref.test`, existing-cast refinement, and tuple/ordered-memory/open-world bailouts. See [`./wat-shapes.md`](./wat-shapes.md) and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

Candidate command shape after those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass gufa --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-gufa --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. No new external source ingest was needed for this correction: current harness and registry code are authoritative for admission, while the existing GUFA dossier remains the upstream-transform evidence.
