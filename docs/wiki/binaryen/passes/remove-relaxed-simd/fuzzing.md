---
kind: workflow
status: working
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

# `remove-relaxed-simd` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `remove-relaxed-simd` today.

- The comparison harness's `SUPPORTED_PASS_FLAGS` set in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--remove-relaxed-simd`. The argument is rejected before input generation or either optimizer executes.
- Starshine has no `remove-relaxed-simd` registry entry in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). Starshine can round-trip relaxed SIMD instructions, but it has no local removal transform to execute.
- That parser rejection is a **status check**, not a failed smoke lane or Binaryen-parity evidence. A successful process with no comparisons would not be parity evidence either; see the four required gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the harness roster:

```text
bun fuzz compare-pass --list-passes
```

`remove-relaxed-simd` should remain absent until Starshine deliberately implements and admits it.

## Future runnable template

Enable a comparison lane only after all of the following are true:

1. an active Starshine pass can rewrite relaxed SIMD operations while preserving operand effects and validating typed `v128` trap contexts;
2. `SUPPORTED_PASS_FLAGS` admits `--remove-relaxed-simd` and `bun fuzz compare-pass --list-passes` reports it;
3. the local spelling maps to Binaryen's public `--remove-relaxed-simd` flag; and
4. a relaxed-SIMD-capable generator/profile plus direct fixtures produces unary, binary, and ternary relaxed operation shapes with a meaningful `--min-compared` threshold.

Candidate command shape once those prerequisites are true:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass remove-relaxed-simd --count 10000 --seed 0x5eed \
  --gen-valid-profile binaryen-oracle-relaxed-simd \
  --out-dir .tmp/pass-fuzz-remove-relaxed-simd --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

The command is a **future template**, not current guidance. Before treating it as signoff, add fixture-backed coverage for unary, binary, and ternary relaxed opcode families; effectful operands localized before the trap; typed result contexts; ordinary SIMD preservation; all local relaxed opcode spellings; and final validation. The upstream trap-replacement contract and the Starshine WAT spelling boundary are documented in [`./index.md`](index.md) and [`./starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).
