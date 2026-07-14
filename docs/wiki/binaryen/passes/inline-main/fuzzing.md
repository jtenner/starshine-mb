---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ../inlining/index.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `inline-main` fuzzing status

## Current status: planned only

Do **not** run or advertise `bun fuzz compare-pass --pass inline-main ...` as a current parity lane.

- The harness allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not contain `inline-main`, so it rejects the flag before generation, Starshine, or Binaryen execution.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) tracks `inline-main` as **boundary-only**, not as an active module pass. An admitted request would still stop at Starshine's boundary-only guard.
- The pass's presence in Binaryen's shared inlining owner does not make it an alias for active Starshine `inlining`; its exact `main` / `__original_main` wrapper contract needs its own implementation and fixtures.
- Rejection and zero-comparison outcomes are roster status, not transform-oracle evidence; see the local pass-eligibility preflight and harness/registry sources cited above.

Use `bun fuzz compare-pass --list-passes` only to inspect the current harness roster.

## Future executable lane

Future admission needs an active Starshine pass, a harness-to-Binaryen `--inline-main` mapping, and fixtures that make the special-case pass act. An ordinary random direct-call profile is insufficient.

Required directed cases include:

- one defined `main` with exactly one direct call to defined `__original_main`;
- missing/imported endpoints and zero or multiple direct-call no-ops;
- wrapper return, local, label, and multivalue repair shapes inherited from the inliner; and
- a contrast case showing ordinary `inlining` may have different eligibility/planning.

After those gates are green, a future command may be:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass inline-main --count 10000 --seed 0x5eed \
  --gen-valid-profile <inline-main-wrapper-profile> \
  --out-dir .tmp/pass-fuzz-inline-main --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

This is a **future template**, not current signoff guidance.
