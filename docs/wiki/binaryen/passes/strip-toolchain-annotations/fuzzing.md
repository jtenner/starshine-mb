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

# `strip-toolchain-annotations` Fuzzing Status

## Current status: planned only

Do **not** run or advertise a Starshine-vs-Binaryen `compare-pass` smoke lane for `strip-toolchain-annotations` today.

- The comparison harness's `SUPPORTED_PASS_FLAGS` set in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not admit `--strip-toolchain-annotations`. The argument is rejected before input generation or either optimizer executes.
- Starshine has no `strip-toolchain-annotations` registry entry in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), so no local transform exists to compare.
- That parser rejection is a **status check**, not a failed smoke lane or Binaryen-parity evidence. A successful process with no comparisons would not be parity evidence either; see the four required gates in [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md#pass-eligibility-preflight).

Use this harmless discovery command only to inspect the harness roster:

```text
bun fuzz compare-pass --list-passes
```

`strip-toolchain-annotations` should remain absent until Starshine deliberately implements and admits it.

## Future runnable template

Enable a comparison lane only after all of the following are true:

1. an active Starshine module pass owns the supported annotation representation and focused fixtures prove it can run;
2. `SUPPORTED_PASS_FLAGS` admits `--strip-toolchain-annotations` and `bun fuzz compare-pass --list-passes` reports it;
3. the local spelling maps to Binaryen's public `--strip-toolchain-annotations` flag; and
4. a generated or fixture-backed input surface can produce removable and retained annotation payloads with a meaningful `--min-compared` threshold.

Candidate command shape once those prerequisites are true:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass strip-toolchain-annotations --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-strip-toolchain-annotations --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --min-compared <meaningful-count>
```

The command is a **future template**, not current guidance. Before treating it as signoff, add fixture-backed coverage for removal of `removableIfUnused`, `idempotent`, and (when locally modeled) `jsCalled`; preservation of `metadata.code.inline`; mixed and empty annotation entries; and import/function-index integrity after neighboring module rewrites. The upstream transform contract and local representation gap are documented in [`./index.md`](index.md) and [`./starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).
