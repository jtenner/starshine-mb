# 0094 - Generated `-O4z` slot 14 early `remove-unused-brs` invalid raw output

## Status

- Date: 2026-04-18
- Type: One-off raw corruption capture
- Shared audit note: [0093 - Generated cmd.wasm ordered -O4z pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- Saved audit root: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/`

## Scope

- Binaryen slot: `14`
- Observed Binaryen pass: `remove-unused-brs`
- Starshine pass: `--remove-unused-brs`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm`
- Saved compare directory: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/11-slot14-remove-unused-brs/`

## Failure summary

The compare harness reaches Starshine raw output emission, but the emitted module is invalid before any meaningful compare can finish. The harness fails while trying to canonicalize the raw Starshine output with Binaryen:

- compare command: `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/11-slot14-remove-unused-brs --remove-unused-brs`
- compare exit: nonzero
- failure site: `wasm-opt .../starshine.raw.wasm --all-features --strip-debug`
- Binaryen symptom: `[parse exception: popping from empty stack]`

The saved raw output also fails `wasm-tools validate` directly:

- `func 1354 failed to validate`
- cause: `type mismatch: expected i32 but nothing on stack`
- saved raw path: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/11-slot14-remove-unused-brs/starshine.raw.wasm`

## Direct Starshine replay

The corruption reproduces without the compare harness if Starshine is run directly on the saved Binaryen predecessor input. The command exits zero but emits invalid wasm:

- command:
  - `_build/native/release/build/cmd/cmd.exe --remove-unused-brs --out .artifacts/tmp-direct-rub-slot14.raw.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/10-slot13-remove-unused-names/binaryen.wasm`
- direct validation:
  - `wasm-tools validate .artifacts/tmp-direct-rub-slot14.raw.wasm`
- current result:
  - `func 1354 failed to validate`
  - `type mismatch: expected i32 but nothing on stack (at offset 0xa7d5d)`

The direct command log is saved at:

- `.artifacts/tmp-direct-rub-slot14.log`

## Saved compare evidence

- compare stderr: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/11-slot14-remove-unused-brs/compare.stderr.log`
- compare stdout: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/11-slot14-remove-unused-brs/compare.stdout.log`
- Starshine raw output: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/11-slot14-remove-unused-brs/starshine.raw.wasm`
- Binaryen output still validates: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/11-slot14-remove-unused-brs/binaryen.wasm`

The key saved compare-harness error is:

- `error: command failed: wasm-opt .../11-slot14-remove-unused-brs/starshine.raw.wasm --all-features --strip-debug -o .../11-slot14-remove-unused-brs/starshine.wasm`
- `[parse exception: popping from empty stack (at 0:687455)]`

## Notes for later debugging

- This is the earlier of the two ordered `remove-unused-brs` corruption slots. It is not the same failure family as the later slot `40` issue.
- The direct Starshine command exits zero, so the bug is currently an invalid emitted module rather than a pass-manager abort.
- Because the saved predecessor input is already a Binaryen-produced module from slot `13`, this issue sits squarely in the ordered-prefix replay path rather than only on the original generated baseline.

## Open questions

- Which exact lowered function rewrite in `func 1354` drops the required result value?
- Does the bad state originate in the RUB rewrite itself, or in a later lower/writeback step that only this predecessor shape triggers?
- Can the saved predecessor input be reduced to a smaller extracted-function or module-level repro without losing the missing-`i32` symptom?

