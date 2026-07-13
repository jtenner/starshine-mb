---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-signature-refining-v130-current-main-continuation-world-mode-recheck.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `signature-refining` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` lane for `signature-refining` today.

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) keeps the name in `pass_registry_boundary_only_names()`. An explicit Starshine request intentionally rejects; no local module pass exists.
- [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--signature-refining` in `SUPPORTED_PASS_FLAGS`. The harness rejects the argument before generation or either optimizer runs.
- A parser rejection, a local boundary-only error, or zero compared cases is a **status check**, not Binaryen-parity evidence. Follow the four admission gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the admitted harness roster:

```text
bun fuzz compare-pass --list-passes
```

## Why ordinary GenValid is insufficient by itself

The upstream pass is GC-aware and operates on nominal function heap types. Its decisive facts come from direct calls, `call_ref`, returned values, public/import/tag/subtype boundaries, and the whole shared signature family. A generic random module lane cannot establish that it exercised a meaningful type-rewrite case.

Before a runnable lane exists, focused fixtures must cover at least:

- absent-GC, table-present, public/import/tag/subtype, JS-called params-only, and continuation-used full no-change boundaries;
- several functions sharing one nominal signature, so the test rejects a false per-function rewrite;
- parameter-LUB and result-LUB positives separately, including body-local repair after parameter tightening;
- direct calls first, then binary/library `call_ref` and `return_call_ref` until ordinary `call_ref` WAST text is supported; and
- `call.without.effects` operands and its cloned-import result-signature repair once Starshine models that intrinsic.

See [`./wat-shapes.md`](./wat-shapes.md) for shapes and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the implementation order.

## Future runnable template

Enable a comparison lane only after all of these are true:

1. an active Starshine module pass rewrites shared nominal signatures, direct calls, affected locals, and its documented reference-call subset;
2. the registry no longer classifies `signature-refining` as boundary-only;
3. `SUPPORTED_PASS_FLAGS` admits `--signature-refining` and `bun fuzz compare-pass --list-passes` reports it; and
4. a GC/type-aware fixture corpus or generator profile yields a meaningful nonzero comparison count guarded by `--min-compared`.

Candidate command shape once those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass signature-refining --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-signature-refining --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a **future template**, not current signoff guidance. Record the eventual feature/profile mix, known unsupported call families, normalizers, and replay-artifact contract before using it as parity evidence.
