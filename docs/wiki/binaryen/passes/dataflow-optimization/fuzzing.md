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
  - ../../../tooling/pass-fuzz-compare.md
---

# `dataflow-optimization` Fuzzing Status

## Current state: planned, not runnable

Do **not** advertise `bun fuzz compare-pass --pass dataflow-optimization ...` as a current parity lane.

- `SUPPORTED_PASS_FLAGS` in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does **not** admit `dataflow-optimization`; parsing stops before a module is generated or compared.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lists the local name as **Removed**, with no active descriptor or dispatch path.
- A rejected command or zero compared cases demonstrates only admission status, never transform parity.

Use `bun fuzz compare-pass --list-passes` only to inspect the current admitted roster.

## Future executable lane

A future lane needs: an active Starshine implementation; an explicit harness mapping to Binaryen's public flag; and a flat-input corpus/profile that proves `Flat::verifyFlatness`-relevant control, local, and DataFlow-IR shapes. Require direct fixtures for reachable constants, joins, effect/trap barriers, branches, and unsupported non-flat forms before publishing a 10,000-case command.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass dataflow-optimization --count 10000 --seed 0x5eed \
  --gen-valid-profile <flat-dataflow-profile> \
  --out-dir .tmp/pass-fuzz-dataflow-optimization --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

The command is future-only. Classify any eventual differences using the pass contract and measured evidence, not output validity alone.
