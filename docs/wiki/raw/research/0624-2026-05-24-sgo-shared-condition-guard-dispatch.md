# SGO shared condition guard dispatch

Date: 2026-05-24

## Question

Can the direct, `i32.eqz`, compare, reverse-compare, and exact `if return; set` read-only-to-write guard dispatchers share block/no-catch-`try_table` body handling without changing behavior?

## Change

Refactor-only structural slice in `src/passes/simplify_globals_optimizing.mbt`:

- Added `sgo_count_direct_condition_body_read` to centralize the direct condition body proof used by block, loop, and no-catch `try_table` direct self guards while preserving loop-specific `allow_flow=false` behavior.
- Routed direct block/loop/no-catch-`try_table` guards through the shared helper.
- Routed adjacent `i32.eqz`, compare, and reverse-compare guards through shared block/no-catch-`try_table` extraction while preserving the existing loop pure-body-only subset.
- Consolidated exact direct/eqz/compare/reverse-compare `if return; set` and block-wrapped-set tails so block and no-catch `try_table` wrappers share the same body/tail dispatch.

No intentional behavior change: this preserves already-probed direct, eqz, compare, reverse-compare, pure-condition, block-tail, and no-catch `try_table` read-only-to-write behavior. Loop handling remains narrower than block/try_table handling, and caught `try_table` wrappers remain excluded.

## Validation

- `moon fmt && moon test src/passes`: 1590/1590 passed.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-shared-condition-guard-dispatch-10k`: 9975/10000 compared, 9975 normalized matches, 0 mismatches, 0 validation failures, 0 generator failures, 25 Binaryen/tool command failures.

## Remaining work

`[SGO]003` remains active/partial. This refactor does not claim full Binaryen `SimplifyGlobals.cpp` parity and does not broaden caught `try_table`, loop flow-scanner use, calls, trapping/effectful consumers, branch/control-transfer, or same-init expression equivalence.
