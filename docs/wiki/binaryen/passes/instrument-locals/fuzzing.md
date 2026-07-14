---
kind: workflow
status: working
last_reviewed: 2026-07-11
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/InstrumentLocals.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./unsupported-types-effects-and-import-roster.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `instrument-locals` Fuzzing Profile

## Current status: planned, not runnable

Starshine does not register `instrument-locals`, and the compare-pass harness does not admit `--instrument-locals` in `SUPPORTED_PASS_FLAGS`. The command therefore cannot execute a local transform today; unknown-pass or parser failure is not Binaryen-parity evidence.

The pass is particularly unsuitable for a generic no-op lane. It injects imports, wraps selected local accesses with effectful helper calls, and intentionally changes what later effect-sensitive cleanup can remove. A meaningful future profile must observe all three surfaces: rewritten function bodies, generated imports, and effect behavior.

## Required future evidence

Before a runnable lane is documented, require:

1. active Starshine module-pass dispatch and a public-name decision;
2. harness admission and exact Binaryen flag mapping;
3. fixtures for scalar `local.get`, `local.set`, and `local.tee`, including helper-import ABI and one shared call-id sequence;
4. explicit preserved cases for ordinary `i64`, unsupported references, `Pop`, and unreachable assigned values;
5. feature-gated `v128` and nullable-reference coverage when those local surfaces are supported; and
6. an effects-composition fixture showing that the new helper calls invalidate/remodel global-effects assumptions rather than being treated as pure identity wrappers.

The current owner and its partial type surface are documented in [`unsupported-types-effects-and-import-roster.md`](unsupported-types-effects-and-import-roster.md).

## Future lane template

After the four compare-pass admission gates and a local-access generator profile exist:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass instrument-locals --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-instrument-locals --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile <future-local-access-profile> \
  --min-compared <meaningful-instrumented-count>
```

Do not use a green process with no instrumentable local traffic as signoff. Keep import ABI and effect tests outside normalized WAT comparison as focused validation obligations.
