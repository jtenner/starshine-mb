---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./small-module-threshold-scoring-and-proof.md
  - ./starshine-strategy.md
  - ../reorder-globals/index.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `reorder-globals-always` Fuzzing Status

## Current status: planned only

`reorder-globals-always` has no runnable Starshine compare-pass lane.

- Current Binaryen `main` registers `reorder-globals` as the production pass but registers `reorder-globals-always` with `registerTestPass`; the latter exists to make the shared global-ordering algorithm observable below the production small-module cutoff. The official `reorder-globals.wast` fixture exercises that test-oriented name.
- Starshine intentionally keeps only `reorder-globals-always` boundary-only in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). Production `reorder-globals` is already a separate active module pass; do not mistake its status or fuzz evidence for this sibling's evidence.
- `SUPPORTED_PASS_FLAGS` in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not contain `--reorder-globals-always`, so the old generic command fails before either optimizer runs.

Binaryen current-main [`pass.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp), its [`reorder-globals.wast`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/reorder-globals.wast) fixture, and the cited local sources establish this admission boundary. A rejected command, zero comparisons, or a Binaryen-only test invocation is not Starshine parity evidence.

## Required future evidence

A future compatibility or internal lane needs all four compare-pass eligibility gates plus a profile that constructs **small** global sections where production mode would deliberately no-op. Retain reduced fixtures for:

- the under-128 production cutoff versus always-mode positive;
- smooth `1.0 + (i / 128.0)` scoring versus production stepped-size scoring;
- imports-first and initializer-dependency legality;
- `global.get` and `global.set` heat, exports, and every numeric `GlobalIdx` remap surface; and
- a clear policy for whether Starshine exposes this upstream test-oriented name to users or uses it only as a shared-engine test mode.

See [`small-module-threshold-scoring-and-proof.md`](small-module-threshold-scoring-and-proof.md) for the upstream shape contract and [`../reorder-globals/index.md`](../reorder-globals/index.md) for the active production implementation.

## Future lane template

Only after active dispatch, harness admission, a Binaryen test-pass mapping decision, and a feature-producing profile exist:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass reorder-globals-always --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-reorder-globals-always --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile <future-small-global-ordering-profile> \
  --min-compared <meaningful-small-module-count>
```

Until then, use the upstream fixture and local roster/registry inspection to document status. Do not label a failed parser request as a smoke test.
