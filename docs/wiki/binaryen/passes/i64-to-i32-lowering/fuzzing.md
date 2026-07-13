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
  - ./abi-surface-and-opcode-coverage.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `i64-to-i32-lowering` Fuzzing Profile

## Current status: planned, not runnable

`i64-to-i32-lowering` is a local `BoundaryOnly` name, not an active Starshine transform. An explicit request is rejected before module-pass dispatch, and [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) does not include `--i64-to-i32-lowering` in `SUPPORTED_PASS_FLAGS`.

The former generic 10,000-case command was therefore misleading: it cannot compare one transformed module today. Parser rejection, a boundary-only error, or zero compared cases is not Binaryen-parity evidence.

## Why the future profile cannot be generic

This is whole-module wasm2js-style ABI lowering, not a local arithmetic pass. A useful lane must deliberately generate or replay flat functions with i64-bearing signatures, locals, globals, calls, returns, and supported body operations. It must separately classify the source-backed unsupported/helper-backed families in [`abi-surface-and-opcode-coverage.md`](abi-surface-and-opcode-coverage.md).

Before publishing a lane, satisfy all four compare-pass admission gates and add focused fixtures for:

- flatness precondition and single-evaluation temps;
- i64 parameter/local pair splitting and renamed high halves;
- function/type and direct/indirect-call remapping;
- return high-half global behavior and growable helper/import surfaces;
- defined-global lowering versus imported-global boundary behavior; and
- helper-backed reinterpret/atomic paths plus explicit unsupported opcode families.

## Future lane template

Only after a tested module pass and matching harness mapping exist:

```text
moon build --target native --release src/cmd
bun fuzz compare-pass --pass i64-to-i32-lowering --count 10000 --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-i64-to-i32-lowering --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --gen-valid-profile <future-flat-i64-abi-profile> \
  --min-compared <meaningful-i64-abi-count>
```

Keep direct reduced fixtures as the first oracle. Do not call the generic default profile a signoff lane unless its manifest proves it exercised the required ABI surface.
