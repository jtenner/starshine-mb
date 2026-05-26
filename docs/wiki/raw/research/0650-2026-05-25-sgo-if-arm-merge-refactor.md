# SGO if-arm merge helper refactor

## Scope

Refactor-only `[SGO]003O` matcher-maintainability slice for `simplify-globals-optimizing`.

This slice centralizes the repeated value-producing `if` arm merge pattern used by FlowScanner read/taint analysis. It does not change accepted opcode families, candidate-read accounting, or any control/effect boundary.

## Change

- Added `sgo_flow_merge_value_if_arm_taint_and_reads(...)` in `src/passes/simplify_globals_optimizing.mbt`.
- Routed the repeated value-producing `if` arm-result cases through the helper in:
  - prefix flow scanning,
  - arm-result flow scanning,
  - nested `if` arm-flow read counting.

The helper only computes the existing conjunction of both arm scans, the sum of their candidate reads, and the OR of their taint bits. Existing callers still enforce their local read budget and stack effects.

## Behavior

No behavior change intended or admitted.

Preserved boundaries:

- candidate global reads are still counted by `sgo_flow_arm_result_taint_and_reads(...)`;
- each caller still applies the same `reads <= 1` or exact-one-read condition;
- condition stack popping and result-stack pushes remain in the caller;
- call, trapping-read, side-effect, void-if, block, loop, `try_table`, and unknown-instruction barriers are unchanged.

## Validation

- `moon test src/passes` — `1600/1600` passed.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-if-arm-merge-refactor-10k` — `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `25` Binaryen/tool command failures.

## Status

`[SGO]003O` remains open for additional small maintainability refactors. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
