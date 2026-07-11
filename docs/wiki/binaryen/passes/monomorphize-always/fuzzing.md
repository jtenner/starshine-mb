---
kind: workflow
status: planned
last_reviewed: 2026-07-11
sources:
  - ../../../raw/fuzzing/2026-07-11-pass-fuzz-admission-boundary-audit.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ../monomorphize/index.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `monomorphize-always` fuzzing status

## Current status: planned only

Do **not** run or advertise `bun fuzz compare-pass --pass monomorphize-always ...` as a current parity lane.

- The compare-pass `SUPPORTED_PASS_FLAGS` allowlist does not admit `monomorphize-always`, so parsing fails before generation or either optimizer runs.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) tracks the sibling as **boundary-only**, not as an active cloning pass.
- The upstream testing-oriented sibling removes the normal usefulness gate; it does **not** remove call-context legality, clone-repair, or validation requirements.
- Rejection or zero comparisons is only local status evidence, never parity evidence.

Use `bun fuzz compare-pass --list-passes` only to inspect the current admitted roster.

## Future executable lane

Admit this lane only after Starshine deliberately implements the shared clone engine, exposes the `-always` behavior separately, maps it to Binaryen, and can generate direct-call contexts. Keep fixtures for imported, indirect, recursive, effect-order, signature-repair, dropped-result, and tail-call bailouts, then add a paired case proving that an otherwise legal specialization rejected by normal `monomorphize` for insufficient benefit is retained by `monomorphize-always`.

A future command may be shaped as:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass monomorphize-always --count 10000 --seed 0x5eed \
  --gen-valid-profile <call-context-specialization-profile> \
  --out-dir .tmp/pass-fuzz-monomorphize-always --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-threshold>
```

This is a **future template**, not current signoff guidance.
