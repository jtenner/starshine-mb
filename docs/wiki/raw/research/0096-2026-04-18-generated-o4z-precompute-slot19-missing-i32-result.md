# 0096 - Generated `-O4z` slot 19 early `precompute` invalid raw output

## Status

- Date: 2026-04-18
- Type: One-off raw corruption capture
- Shared audit note: [0093 - Generated cmd.wasm ordered -O4z pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- Saved audit root: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/`

## Scope

- Binaryen slot: `19`
- Observed Binaryen pass: `precompute-propagate`
- Starshine pass: `--precompute`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/15-slot18-pick-load-signs/binaryen.wasm`
- Saved compare directory: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/16-slot19-precompute/`

## Failure summary

The compare harness reaches Starshine raw output emission, but the emitted module is invalid before canonical comparison can finish:

- compare command: `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/15-slot18-pick-load-signs/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/16-slot19-precompute --precompute`
- compare exit: nonzero
- failure site: `wasm-opt .../starshine.raw.wasm --all-features --strip-debug`
- Binaryen symptom: `[parse exception: popping from empty stack]`

The saved raw output also fails direct validation:

- `func 108 failed to validate`
- cause: `type mismatch: expected i32 but nothing on stack`
- saved raw path: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/16-slot19-precompute/starshine.raw.wasm`

## Direct Starshine replay

The bug reproduces with a direct Starshine pass invocation that exits zero but emits invalid wasm:

- command:
  - `_build/native/release/build/cmd/cmd.exe --precompute --out .artifacts/tmp-direct-precompute-slot19.raw.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/15-slot18-pick-load-signs/binaryen.wasm`
- validation:
  - `wasm-tools validate .artifacts/tmp-direct-precompute-slot19.raw.wasm`
- current result:
  - `func 108 failed to validate`
  - `type mismatch: expected i32 but nothing on stack (at offset 0xae01)`

The direct command log is saved at:

- `.artifacts/tmp-direct-precompute-slot19.log`

## Saved compare evidence

- compare stderr: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/16-slot19-precompute/compare.stderr.log`
- compare stdout: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/16-slot19-precompute/compare.stdout.log`
- Starshine raw output: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/16-slot19-precompute/starshine.raw.wasm`
- Binaryen output: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/16-slot19-precompute/binaryen.wasm`

Key saved compare-harness error:

- `error: command failed: wasm-opt .../16-slot19-precompute/starshine.raw.wasm --all-features --strip-debug -o .../16-slot19-precompute/starshine.wasm`
- `[parse exception: popping from empty stack (at 0:44547)]`

## Notes for later debugging

- This is the early `precompute` corruption slot. The later ordered `precompute` slot at Binaryen slot `43` completed with meaningful equality before the next `optimize-instructions` failure, so this looks state-specific rather than a blanket proof that every `precompute` replay is broken.
- Like the early `remove-unused-brs` issue, the direct pass command exits zero and the invalidity only becomes obvious when the emitted module is validated.

## Open questions

- Which exact `func 108` rewrite drops the required `i32` result?
- Is this the same shape class as the early RUB missing-result failure, or a separate `precompute`-specific carrier problem?
- Can the saved predecessor state be reduced without losing the invalid raw-output symptom?

