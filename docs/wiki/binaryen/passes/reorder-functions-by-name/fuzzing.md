---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../tooling/pass-fuzz-compare.md
  - ./index.md
  - ./starshine-port-readiness-and-validation.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../reorder-functions/fuzzing.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `reorder-functions-by-name` fuzzing status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` lane for `reorder-functions-by-name` today.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) keeps this public Binaryen name in `pass_registry_boundary_only_names()`. Starshine recognizes it but rejects an execution request; no module pass exists.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--reorder-functions-by-name` in `SUPPORTED_PASS_FLAGS`. The harness rejects it before generation or either optimizer runs.
- Therefore a rejected command, or a command comparing zero useful cases, is a **status check**, not Binaryen-parity evidence. The old copied 10,000-case command was invalid and is superseded by this page.

Safe roster inspection only:

```text
bun fuzz compare-pass --list-passes
```

## Future admission gates

Create a real comparison lane only after all of these are true:

1. Starshine has an active, behavior-tested module implementation and registry entry.
2. The harness accepts the exact canonical spelling in `SUPPORTED_PASS_FLAGS`.
3. Focused fixtures prove lexical ordering plus a total function-index permutation: import prefix, paired function/code sections, direct and tail calls, `ref.func`, start, exports, element segments, initializer expressions, names, and annotations.
4. The Binaryen oracle contract remains source-captured: ascending internal function-name order, body preservation apart from required local representation repair, and no invented count-model behavior.

Then build a native executable and use the standard signoff shape:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass reorder-functions-by-name --out-dir .tmp/pass-fuzz-reorder-functions-by-name --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

This is a **future template**, not a runnable command today. Give targeted permutation fixtures equal weight with randomized comparison: a text/binary diff can miss an incorrect `FuncIdx` remap.

## Related pages

- [`index.md`](index.md) — upstream lexical-order contract and local boundary-only status.
- [`starshine-strategy.md`](starshine-strategy.md) — module-wide permutation/remap design.
- [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) — validation ladder.
- [`../reorder-functions/fuzzing.md`](../reorder-functions/fuzzing.md) — matching planned-only status for the count-based sibling.
