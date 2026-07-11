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

# `const-hoisting` Fuzzing Status

## Current state: planned, not runnable

Do **not** treat `bun fuzz compare-pass --pass const-hoisting ...` as a current smoke lane.

- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does **not** admit `const-hoisting` in `SUPPORTED_PASS_FLAGS`; the request stops before generation or comparison.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) classifies `const-hoisting` as **Removed**. No active local transform or dispatcher exists.
- A rejected request or zero compared cases is status evidence only, not proof about literal identity, byte-size profitability, or parity.

Safe inspection only:

```text
bun fuzz compare-pass --list-passes
```

## Future executable lane

A future lane needs an active implementation, explicit Binaryen flag mapping, and a corpus that proves repeated literal identity and profitability rather than merely generating constants. Include `+0.0`/`-0.0`, NaN payloads, scalar widths, repeated versus near-miss values, local prelude placement, trap/effect boundaries, and output-size checks. Use a meaningful `--min-compared` threshold and record size deltas before judging any output-shape difference a Starshine win.

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass const-hoisting --count 10000 --seed 0x5eed \
  --gen-valid-profile <repeated-literal-profile> \
  --out-dir .tmp/pass-fuzz-const-hoisting --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

The command is future-only while the registry entry remains removed.
