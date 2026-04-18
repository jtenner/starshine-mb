# 0098 - Generated `-O4z` slot 33 `vacuum` final-validate stack underflow after `simplify-locals`

## Status

- Date: 2026-04-18
- Type: One-off raw corruption capture
- Shared audit note: [0093 - Generated cmd.wasm ordered -O4z pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- Saved audit root: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/`

## Scope

- Binaryen slot: `33`
- Observed Binaryen pass: `vacuum`
- Starshine pass: `--vacuum`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm`
- Saved compare directory: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/23-slot33-vacuum/`

## Failure summary

The compare harness aborts because the Starshine `vacuum` command exits nonzero on the later ordered predecessor state that comes after the successful `simplify-locals` replay:

- compare command: `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/23-slot33-vacuum --vacuum`
- compare exit: nonzero
- failure site: direct Starshine invocation

Direct replay confirms a second final-validation failure family:

- `error: final module validate: stack underflow`
- offending function: `(Func 1818)`
- saved direct log: `.artifacts/tmp-direct-vacuum-after-sl.log`

## Direct Starshine replay

- command:
  - `_build/native/release/build/cmd/cmd.exe --vacuum --out .artifacts/tmp-direct-vacuum-after-sl.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm > .artifacts/tmp-direct-vacuum-after-sl.log 2>&1`
- current key lines:
  - `error: final module validate: stack underflow`
  - `Offending function idx=(Func 1818)`

## Saved compare evidence

- compare stderr: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/23-slot33-vacuum/compare.stderr.log`
- compare stdout: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/23-slot33-vacuum/compare.stdout.log`
- predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/22-slot32-simplify-locals/binaryen.wasm`

## Notes for later debugging

- This is distinct from the earlier `vacuum` / `Func 652` failure. The predecessor state is much later in the ordered chain, and the offending function is `Func 1818`.
- The same `Func 1818` failure then reappears in the later `optimize-instructions` slot, so this is another shared ordered-prefix state worth studying as a pair with [0100](./0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md).

## Open questions

- Is `Func 1818` already on the edge of invalidity after the successful `simplify-locals` replay, with `vacuum` only surfacing it?
- Or does the `vacuum` rewrite itself create the underflow on this later ordered-prefix shape?
- Can the later predecessor state be reduced to a smaller repro that still fails on `Func 1818`?

