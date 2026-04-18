# 0100 - Generated `-O4z` slot 44 later `optimize-instructions` final-validate stack underflow

## Status

- Date: 2026-04-18
- Type: One-off raw corruption capture
- Shared audit note: [0093 - Generated cmd.wasm ordered -O4z pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- Saved audit root: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/`

## Scope

- Binaryen slot: `44`
- Observed Binaryen pass: `optimize-instructions`
- Starshine pass: `--optimize-instructions`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm`
- Saved compare directory: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/30-slot44-optimize-instructions/`

## Failure summary

This later ordered `optimize-instructions` replay aborts in final module validation on the same later-function family that already breaks the preceding `vacuum` slot:

- compare command: `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/30-slot44-optimize-instructions --optimize-instructions`
- compare exit: nonzero
- failure site: direct Starshine invocation

Direct replay confirms:

- `error: final module validate: stack underflow`
- offending function: `(Func 1818)`
- saved direct log: `.artifacts/tmp-direct-optimize-instructions-after-precompute.log`

## Direct Starshine replay

- command:
  - `_build/native/release/build/cmd/cmd.exe --optimize-instructions --out .artifacts/tmp-direct-optimize-instructions-after-precompute.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm > .artifacts/tmp-direct-optimize-instructions-after-precompute.log 2>&1`
- current key lines:
  - `error: final module validate: stack underflow`
  - `Offending function idx=(Func 1818)`

## Saved compare evidence

- compare stderr: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/30-slot44-optimize-instructions/compare.stderr.log`
- compare stdout: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/30-slot44-optimize-instructions/compare.stdout.log`
- predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/29-slot43-precompute/binaryen.wasm`

The compare trace again shows the pass performing real mutations before the final abort.

## Notes for later debugging

- This is the later counterpart to [0095](./0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md): the pass family is the same, but the offending function and predecessor state are different.
- It pairs directly with [0098](./0098-2026-04-18-generated-o4z-vacuum-slot33-func1818-stack-underflow.md), because both later-slot failures die on `Func 1818`.
- That pairing suggests the later ordered-prefix state after successful `simplify-locals`, `reorder-locals`, `remove-unused-names`, and later `precompute` remains structurally fragile before the next cleanup pass boundary.

## Open questions

- Does the later `optimize-instructions` slot reproduce because `Func 1818` is already invalid in Starshine's in-memory state, or because the pass's own mutation pushes it over the edge?
- Which specific rewrite inside `Func 1818` is the first one that makes final validation fail?
- Can the later predecessor input be reduced to a small repro that still dies on `Func 1818`?

