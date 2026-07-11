---
kind: workflow
status: working
last_reviewed: 2026-07-10
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `type-finalizing` Fuzzing Profile

## Current state: planned, not runnable

Do **not** treat a compare-pass command as a current smoke lane for this pass.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) owns the accepted `--pass` names. Its `SUPPORTED_PASS_FLAGS` set does **not** include `type-finalizing`, so `bun fuzz compare-pass --pass type-finalizing ...` fails during option parsing before it generates or compares a case.
- Even if the harness later accepts the spelling, Starshine currently categorizes `type-finalizing` as `BoundaryOnly` in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). A direct CLI request therefore ends at the intentional “boundary-only and is not implemented in the hot pipeline” error instead of running a transform.
- A parser rejection, a Starshine command failure, or zero compared cases is **not** Binaryen-parity evidence. The current verifiable state is the registry/status contract in [`./starshine-strategy.md`](starshine-strategy.md), not a 10,000-case oracle lane.

This distinction prevents a misleading failure report: Binaryen exposes `--type-finalizing`, but neither the local comparison harness nor Starshine's active dispatcher exposes an executable counterpart yet. The general preflight rule is documented in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

## Future executable lane

Enable a compare lane only after all of these conditions hold:

1. Starshine promotes the pass from `BoundaryOnly` to an active module/pass dispatcher entry and focused fixtures prove it can run.
2. `SUPPORTED_PASS_FLAGS` admits `--type-finalizing`; `bun fuzz compare-pass --list-passes` then reports `type-finalizing`.
3. A GC-capable GenValid profile and direct WAT fixtures establish a meaningful compared surface. Start with the shared GC/reference profile only after confirming its feature facts include the required type-finality shapes.
4. The first documented run records an explicit `--min-compared` threshold, Binaryen version, feature filters, and any command-failure exclusions before it is used for signoff.

Candidate command shape once those prerequisites are true:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass type-finalizing --gen-valid-profile pass-gc-ref \
  --require-feature gc --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-type-finalizing --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

The command is a **future template**, not an instruction to run it against today's boundary-only implementation. Add a dedicated profile only when the generic GC/reference input mix has demonstrated an insufficient type-finality surface; record the chosen profile, required feature facts, normalizers, and replay-artifact contract here.
