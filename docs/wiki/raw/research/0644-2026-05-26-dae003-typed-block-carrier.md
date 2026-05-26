# DAE003 typed block local carrier

Date: 2026-05-26

## Scope

Recovery slice for `[DAE003-F]` structured constant/unread carriers. The safe behavior widened only the non-adjacent `local.set` constant-carrier recognizer when the value producer is a single-result `block` containing exactly one materializable constant instruction.

## Test-first evidence

Added focused coverage in `src/passes/dae_optimizing_test.mbt`:

- `dae-optimizing materializes non-adjacent typed block constant carrier` first failed under `moon test src/passes` because `$target` still had one parameter.
- `dae-optimizing rejects non-adjacent loop constant carrier` preserves the conservative boundary for loop carriers.

The failing command was captured in `.tmp/dae003f-test-before.log`.

## Implementation

`src/passes/dead_argument_elimination.mbt` now resolves `block` constants through `dae_materializable_block_const(...)` before accepting a prior producer for `local.set; local.get; call` forwarding.

The helper intentionally accepts only `Block(_, Expr(body))` with `body.length() == 1` and the same materializable-constant policy already used by adjacent constants, including the existing immutable-global allowance when that lane is enabled. It does not accept loops, ifs, try/try_table, branchy blocks, or multi-instruction wrappers.

## Validation

- `moon test src/passes` passed after the implementation (`1402` tests), with only pre-existing unused helper warnings in `pass_manager_wbtest.mbt`.
- `git diff --check`, `moon info`, `moon fmt`, and full `moon test` passed (`3474` tests), again with only the existing unused helper warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003f-typed-block-20260526-1000` stopped after `45/1000` compared cases at the known mismatch threshold: `26` normalized matches, `19` normalized mismatches, `0` validation failures, `0` generator failures, and `1` Binaryen/tool command failure (`binaryen-rec-group-zero` in `case-000029-wasm-smith`). Agent classification keeps the mismatch set in the existing accepted DAE010 gen-valid raw-cleanup/size-winning family; this slice introduced no validation failure.

## Remaining DAE003-F work

This closes the typed single-instruction block subcase only. Remaining structured-carrier work still includes loop, if, try/try_table, typed wrappers beyond one-instruction blocks, and additional trap/effect/control negative tests before `[DAE003-F]` can be marked complete.
