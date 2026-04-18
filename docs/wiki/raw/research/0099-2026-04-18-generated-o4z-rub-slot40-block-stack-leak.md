# 0099 - Generated `-O4z` slot 40 later `remove-unused-brs` invalid block stack state

## Status

- Date: 2026-04-18
- Type: One-off raw corruption capture
- Shared audit note: [0093 - Generated cmd.wasm ordered -O4z pass audit](./0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- Saved audit root: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/`

## Scope

- Binaryen slot: `40`
- Observed Binaryen pass: `remove-unused-brs`
- Starshine pass: `--remove-unused-brs`
- Saved predecessor input: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/26-slot37-vacuum/binaryen.wasm`
- Saved compare directory: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/27-slot40-remove-unused-brs/`

## Failure summary

This later ordered `remove-unused-brs` replay emits invalid raw wasm. Unlike the early slot `14` failure, the validators report a later block/if typing problem instead of a simple missing final result:

- compare command: `bun scripts/self-optimize-compare.ts .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/26-slot37-vacuum/binaryen.wasm --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/27-slot40-remove-unused-brs --remove-unused-brs`
- compare exit: nonzero
- failure site: `wasm-opt .../starshine.raw.wasm --all-features --strip-debug`

Binaryen-side canonicalization reports:

- `[wasm-validator error in function 1958] returning if-else's true must have right type`

Direct validation on the same raw output reports:

- `func 1979 failed to validate`
- cause: `type mismatch: values remaining on stack at end of block`
- saved raw path: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/27-slot40-remove-unused-brs/starshine.raw.wasm`

## Direct Starshine replay

The corruption reproduces with a direct Starshine command that exits zero but emits invalid wasm:

- command:
  - `_build/native/release/build/cmd/cmd.exe --remove-unused-brs --out .artifacts/tmp-direct-rub-slot40.raw.wasm .artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/26-slot37-vacuum/binaryen.wasm`
- validation:
  - `wasm-tools validate .artifacts/tmp-direct-rub-slot40.raw.wasm`
- current result:
  - `func 1979 failed to validate`
  - `type mismatch: values remaining on stack at end of block (at offset 0xca3ec)`

The direct command log is saved at:

- `.artifacts/tmp-direct-rub-slot40.log`

## Saved compare evidence

- compare stderr: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/27-slot40-remove-unused-brs/compare.stderr.log`
- compare stdout: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/27-slot40-remove-unused-brs/compare.stdout.log`
- Starshine raw output: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/27-slot40-remove-unused-brs/starshine.raw.wasm`
- Binaryen output: `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/27-slot40-remove-unused-brs/binaryen.wasm`

The saved compare stderr includes a long printed validator snippet around the failing `if` / block region in Binaryen's validator. Keep that snippet intact when reducing the bug; it is the best current clue about the structured result mismatch.

## Notes for later debugging

- This is the later of the two ordered `remove-unused-brs` corruption slots. It is not the same failure as the early slot `14` missing-result issue.
- The two validators surface different but related symptoms:
  - Binaryen complains about the typed `if-else` true arm
  - `wasm-tools validate` complains about leftover values at block end
- That combination points at a structured-control result mismatch or stack-balance leak rather than a single missing terminal result.

## Open questions

- Which rewrite in this later RUB slot leaves the if/block result shape imbalanced?
- Why do Binaryen and `wasm-tools` point at different failing function indices? Are they the same structural bug seen through different canonicalized function orderings, or two nearby invalid regions?
- Can the saved predecessor input be reduced while preserving both validator symptoms?

