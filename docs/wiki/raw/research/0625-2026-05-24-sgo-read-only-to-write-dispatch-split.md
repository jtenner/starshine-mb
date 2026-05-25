# SGO read-only-to-write dispatch split

Date: 2026-05-24

## Status

Refactor-only implementation slice for `[SGO]003`. No intended behavior broadening and no claim of full Binaryen `SimplifyGlobals.cpp` parity.

## Goal

Continue source-alignment by making the large `sgo_count_read_only_to_write_instrs` dispatcher describe the current block/no-catch-`try_table` families explicitly, instead of duplicating long guard sequences in both match arms.

The accepted direction remains larger unifying/probed families, not broad unknown behavior. This slice keeps the existing probed family boundaries while reducing dispatch duplication.

## Implementation

Changed `src/passes/simplify_globals_optimizing.mbt` only.

Added shared dispatch helpers:

- `sgo_count_block_or_no_catch_try_table_external_pure_guards(...)`
  - centralizes normal and reverse external pure-condition handling plus exact pure-chain `if return; set` tail handling for block/no-catch-`try_table` wrappers;
- `sgo_count_block_or_no_catch_try_table_tail_guards(...)`
  - centralizes direct, `i32.eqz`, compare, reverse-compare, exact `if return; set`, and block-wrapped-set tail guard dispatch;
  - keeps the block-only nested-if-arm-flow probe as an explicit boolean so no-catch `try_table` does not inherit unprobed block-only behavior;
- `sgo_count_no_catch_try_table_specific_condition_guards(...)`
  - groups no-catch `try_table`-specific select and `ref.is_null` condition families separately from the shared block/tail dispatch.

The `@lib.Block` read-only-to-write dispatcher now calls the shared external-pure helper, shared tail helper with nested-if-arm-flow enabled, and then recurses into the body.

The `@lib.TryTable` dispatcher now calls the shared external-pure helper, the grouped no-catch `try_table`-specific helper, the shared tail helper with nested-if-arm-flow disabled, and then recurses into the body.

## Preserved boundaries

This is a structural refactor only. It preserves:

- direct / `i32.eqz` / compare / reverse-compare read-only-to-write behavior;
- exact direct/`i32.eqz`/compare/reverse-compare `if return; set` and block-wrapped-set tails;
- block-only wrapped nested-if-arm-flow handling;
- existing no-catch `try_table` select and `ref.is_null` families;
- caught `try_table` conservatism through existing no-catch body/prefix checks;
- loop-specific narrower handling, which remains outside the shared block/no-catch-`try_table` tail dispatcher.

No tests were added because this slice intentionally does not broaden behavior. Existing tests cover the preserved families.

## Validation

- `moon fmt && moon test src/passes`
  - `1590/1590` tests passed.
  - Existing unrelated warnings in DAE and pass-manager white-box tests remain.
- Direct SGO fuzz:
  - command: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-read-only-to-write-dispatch-split-10k`
  - compared: `9975/10000`
  - normalized matches: `9975`
  - mismatches: `0`
  - validation failures: `0`
  - generator failures: `0`
  - Binaryen/tool command failures: `25`

## Remaining work

`[SGO]003` remains active/partial. This refactor only reduces dispatcher duplication; it does not add new Binaryen-positive shapes. Future behavior-bearing slices still need focused Binaryen oracle support, tests-first implementation, catch/control/trapping guardrails, and direct `--pass simplify-globals-optimizing` fuzz evidence.
