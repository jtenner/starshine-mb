# 0097 - Generated `-O4z` slot 23 `vacuum` final-validate stack underflow after tuple-opt

## Status

- Date: 2026-04-18
- Type: One-off raw corruption capture
- Shared audit note: [0093 - Generated cmd.wasm ordered -O4z pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- Saved audit root: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/`

## Scope

- Binaryen slot: `23`
- Observed Binaryen pass: `vacuum`
- Starshine pass: `--vacuum`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm`
- Saved compare directory: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/18-slot23-vacuum/`

## Failure summary

The compare harness aborts because the Starshine `vacuum` command exits nonzero on the saved Binaryen predecessor state:

- compare command: `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/18-slot23-vacuum --vacuum`
- compare exit: nonzero
- failure site: direct Starshine invocation

Direct replay confirms a final module validation failure:

- `error: final module validate: stack underflow`
- offending function: `(Func 652)`
- saved direct log: `.artifacts/tmp-direct-vacuum-slot23.log`

## Direct Starshine replay

- command:
  - `_build/native/release/build/cmd/cmd.exe --vacuum --out .artifacts/tmp-direct-vacuum-slot23.raw.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm > .artifacts/tmp-direct-vacuum-slot23.log 2>&1`
- current key lines:
  - `error: final module validate: stack underflow`
  - `Offending function idx=(Func 652)`

## Saved compare evidence

- compare stderr: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/18-slot23-vacuum/compare.stderr.log`
- compare stdout: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/18-slot23-vacuum/compare.stdout.log`
- predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/17-slot21-tuple-optimization/binaryen.wasm`

The compare trace shows `vacuum` mutating functions before the final abort, so this is not a trivial no-op failure.

## Notes for later debugging

- This slot shares its final-validation symptom and offending function with the immediately earlier `optimize-instructions` slot: both die on `Func 652`.
- That makes this a useful paired follow-up with [0095](./0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md):
  - either `optimize-instructions` produces a shape that `vacuum` also cannot finalize
  - or the underlying ordered-prefix state already exposes a shared lower/writeback weakness that both passes touch

## Open questions

- Is the `vacuum` failure a true `vacuum` mutation bug, or does it merely surface the same invalid stack state that the earlier `optimize-instructions` slot already created?
- Does `Func 652` fail before or after the pass's local mutations are lowered back to wasm?
- Can the tuple-opt predecessor state be reduced to a minimal repro that still fails under `--vacuum` with `Func 652`?

