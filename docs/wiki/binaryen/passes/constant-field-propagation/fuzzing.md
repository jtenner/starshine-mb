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
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `constant-field-propagation` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` lane for `constant-field-propagation` today.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) keeps the full-name parent pass and its `constant-field-null-test-folding` sibling boundary-only. Starshine intentionally rejects an explicit request; it has no active closed-world field-analysis pass.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--constant-field-propagation` in `SUPPORTED_PASS_FLAGS`, and it does not provide a local mapping for Binaryen's `cfp` / `cfp-reftest` spellings.
- A rejected command, command failure before generation, or zero comparisons is a **status check**, not Binaryen-parity evidence. Follow the four admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the admitted harness roster:

```text
bun fuzz compare-pass --list-passes
```

## Why ordinary GenValid is insufficient by itself

CFP is a closed-world GC field-read rewrite driven by whole-module write and copy facts. It needs values that agree across exact and inexact references, not merely a module containing `struct.get`.

Before a runnable lane exists, focused fixtures must cover at least:

- non-GC/open-world and public-type boundaries;
- literal and immutable-global positives, conflicting writes, default values, and field-copy fixed points;
- exact versus inexact subtype views, including subtype-field propagation and the narrow two-value `cfp-reftest` split;
- packed-field sign/zero-extension repairs, nullable-null trap preservation, and the ordered-atomic-read bailout versus known-trap rewrite split; and
- type, binary, and validator checks after every read replacement.

See [`./wat-shapes.md`](./wat-shapes.md) and [`./copies-subtypes-ref-tests-and-atomics.md`](./copies-subtypes-ref-tests-and-atomics.md) for the before/after families.

## Future runnable template

Enable a comparison lane only after all of these are true:

1. an active Starshine closed-world module pass implements a documented CFP subset and keeps the `cfp-reftest` variant status explicit;
2. the registry exposes canonical local spellings and a documented Binaryen flag mapping;
3. `SUPPORTED_PASS_FLAGS` admits the active spelling and `bun fuzz compare-pass --list-passes` reports it; and
4. a GC/type-aware fixture corpus or generator profile yields meaningful compared cases guarded by `--min-compared`.

Candidate command shape once those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass constant-field-propagation --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-constant-field-propagation --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. Record the selected CFP variant, closed-world configuration, profile/fixture mix, normalizers, and replay-artifact contract before relying on it as oracle evidence.
