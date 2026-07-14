---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveImports.cpp
  - ../../../raw/binaryen/2026-07-10-remove-imports-current-source-read.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../remove-unused-module-elements/index.md
  - ../duplicate-import-elimination/index.md
  - ../tracker.md
---

# `remove-imports` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` lane for `remove-imports` today.

- The comparison harness's `SUPPORTED_PASS_FLAGS` allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--remove-imports`. The argument is rejected before input generation or either optimizer executes.
- Starshine has no `remove-imports` registry entry or dispatcher implementation in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). Its import-section model is prerequisite representation, not a transform.
- That rejection is a **status check**, not a failed smoke lane or Binaryen-parity evidence. A successful process with zero applicable modules would not be parity evidence either; use the four gates in [`../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the current harness roster:

```text
bun fuzz compare-pass --list-passes
```

`remove-imports` should remain absent until Starshine deliberately implements and admits it.

## Why generic generated modules are insufficient

The upstream pass is intentionally semantics-changing: it replaces direct calls to imported functions with `nop` or a default result literal, then removes imported functions not retained by element/table references. Its purpose is reference-interpreter inspection, not ordinary behavior-preserving optimization. See [`index.md`](index.md) and current-main [`RemoveImports.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveImports.cpp).

Therefore, a future fuzz lane needs an **explicit stubbing/disposability policy**. It must not report a normalized WAT match as evidence that arbitrary host-call effects or results are irrelevant. In particular, an ordinary `gen-valid` module with arbitrary imports cannot establish that it is valid to erase those imports' calls.

## Future runnable template

Enable a compare lane only after all of the following are true:

1. a documented Starshine mode permits replacement of the selected imported calls and results;
2. an active Starshine module pass is registered and dispatched, not merely boundary-only;
3. `SUPPORTED_PASS_FLAGS` admits `--remove-imports`, and the local spelling maps to Binaryen's public `--remove-imports` flag;
4. a dedicated generator/profile creates function imports, direct calls with `none` and value results, and element/table references while encoding the stubbing policy; and
5. the lane uses a meaningful `--min-compared` threshold plus focused fixture coverage for index repair and host-facing behavior.

Candidate command shape **after** those gates are satisfied:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass remove-imports --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-remove-imports --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

This is a future template, not current guidance.

## Required targeted cases before signoff

A meaningful port-specific corpus should distinguish at least these cases:

| Case | Expected test purpose |
| --- | --- |
| Imported `none`-result direct call | Prove the explicit policy permits replacement with `nop`; preserve surrounding stack/control validity. |
| Imported value-result direct call | Prove default-literal replacement is type-correct **and** policy-authorized; validation alone is insufficient. |
| Effectful or result-observed import | Keep unsupported unless the policy says otherwise; this is the key negative family. |
| Function import named by an element segment | Retain the import declaration while testing the separate direct-call rewrite rule. |
| Non-function imports | Preserve them; Binaryen's reviewed owner is function-import-specific. |
| Imported-prefix index repair | Verify calls, `ref.func`, exports, start, elements, names, annotations, and binary/WAST roundtrips after removal. |
| Default presets | Assert that ordinary `optimize`/`shrink` do not silently acquire host-call deletion. |

When a lane exists, report host-call policy, compared-case count, raw/normalized results, validation outcomes, and every mismatch classification separately. A matching canonical WAT output cannot prove the embedding behavior that made the call erasable in the first place.
