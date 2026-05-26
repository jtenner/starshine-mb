# SGO block/loop guarded read refactor

Date: 2026-05-24

## Status

Refactor-only implementation slice for `[SGO]003`. No intended behavior broadening and no claim of full Binaryen `SimplifyGlobals.cpp` parity.

## Goal

Continue consolidating read-only-to-write guard handling. The direct self-guard path and the `i32.eqz` / compare guard paths each repeated block/no-catch-`try_table` wrapper extraction plus loop fallback logic with only one intentional difference: direct self-guards retain the broader direct-condition flow scanner, while `i32.eqz` and compare guards keep the narrower safe-body / pure-loop behavior.

## Implementation

Changed `src/passes/simplify_globals_optimizing.mbt` only.

Added shared helpers:

- `sgo_count_block_or_loop_condition_read(...)`
  - extracts block or no-catch `try_table` wrapper bodies;
  - routes direct self-guards through `sgo_count_direct_condition_body_read(..., count_flow_scanner=true)`;
  - routes `i32.eqz` / compare guard bodies through `sgo_count_block_condition_safe_body_read(...)`;
  - preserves loop fallback as direct-condition scanning only for direct self-guards, and pure-body matching only for `i32.eqz` / compare guards;
- `sgo_count_block_condition_guarded_read(...)`
  - shares the guarded `if global.set` target extraction for `i32.eqz` and compare guard families.

Routed the existing direct, `i32.eqz`, compare, and reverse-compare read-only-to-write guard counters through those helpers.

## Preserved boundaries

This is a structural refactor only. It preserves:

- direct self-guard block/no-catch `try_table` FlowScanner behavior;
- direct self-guard loop behavior with flow scanning disabled;
- `i32.eqz` and compare block/no-catch `try_table` safe-body matching;
- `i32.eqz` and compare loop behavior limited to pure-condition bodies;
- caught `try_table` conservatism;
- all existing target-global matching and no-else `if global.set` requirements.

No tests were added because this slice intentionally does not broaden behavior. Existing tests cover the routed direct, `i32.eqz`, compare, reverse-compare, loop, block, and no-catch `try_table` families.

## Validation

- `moon fmt && moon test src/passes`
  - `1590/1590` tests passed.
  - Existing unrelated warnings in DAE and pass-manager white-box tests remain.
- Direct SGO fuzz:
  - command: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-block-loop-guarded-read-refactor-10k`
  - compared: `9975/10000`
  - normalized matches: `9975`
  - mismatches: `0`
  - validation failures: `0`
  - generator failures: `0`
  - Binaryen/tool command failures: `25`

## Remaining work

`[SGO]003` remains active/partial. This refactor only centralizes already-supported direct and guarded condition read paths. Future behavior-bearing slices still need focused Binaryen oracle support, tests-first implementation, catch/control/trapping guardrails, and direct `--pass simplify-globals-optimizing` fuzz evidence.
