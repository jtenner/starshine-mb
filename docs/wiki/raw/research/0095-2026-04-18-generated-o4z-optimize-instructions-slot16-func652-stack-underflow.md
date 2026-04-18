# 0095 - Generated `-O4z` slot 16 early `optimize-instructions` final-validate stack underflow

## Status

- Date: 2026-04-18
- Type: One-off raw corruption capture
- Shared audit note: [0093 - Generated cmd.wasm ordered -O4z pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- Saved audit root: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/`

## Scope

- Binaryen slot: `16`
- Observed Binaryen pass: `optimize-instructions`
- Starshine pass: `--optimize-instructions`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`
- Saved compare directory: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/13-slot16-optimize-instructions/`

## Failure summary

The compare harness never reaches output comparison because the Starshine pass command itself exits nonzero:

- compare command: `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/13-slot16-optimize-instructions --optimize-instructions`
- compare exit: nonzero
- failure site: direct Starshine invocation

The saved direct replay shows the pass dying in final module validation:

- `error: final module validate: stack underflow`
- offending function: `(Func 652)`
- saved direct log: `.artifacts/tmp-direct-optimize-instructions-failure.log`

## Direct Starshine replay

- command:
  - `_build/native/release/build/cmd/cmd.exe --optimize-instructions --out .artifacts/tmp-direct-optimize-instructions-failure.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm > .artifacts/tmp-direct-optimize-instructions-failure.log 2>&1`
- current key lines:
  - `error: final module validate: stack underflow`
  - `Offending function idx=(Func 652)`

## Saved compare evidence

- compare stderr: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/13-slot16-optimize-instructions/compare.stderr.log`
- compare stdout: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/13-slot16-optimize-instructions/compare.stdout.log`
- predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/12-slot15-remove-unused-names/binaryen.wasm`

The compare log shows the pass doing real work before the abort:

- trace mode: `pass`
- effective pass flags: `optimize-instructions`
- multiple mutated revisions are logged before the eventual nonzero exit

## Notes for later debugging

- This is the first of the two ordered `optimize-instructions` corruption slots.
- The same final-validation symptom and same offending function `Func 652` also show up one slot later when `vacuum` runs on the resulting Binaryen predecessor state.
- That pairing suggests this early state may already be teetering on an invalid stack shape before the `vacuum` replay, and `optimize-instructions` is one place where Starshine can no longer write back a valid final module.

## Open questions

- Is `Func 652` already malformed in Starshine's in-memory post-pass shape before final lower, or does the stack underflow only appear after lower/writeback?
- Which `optimize-instructions` rewrite in this predecessor state introduces or exposes the underflow?
- Can the predecessor input be reduced to a single-function replay that still dies in `Func 652`?

