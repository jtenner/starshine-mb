# SGO try_table select shared matcher

Date: 2026-05-24

## Question

Can the no-catch `try_table` select read-only-to-write family be structurally consolidated after the select reverse-compare pure-post-consumer slice?

## Change

Refactor-only structural slice in `src/passes/simplify_globals_optimizing.mbt`:

- Replaced separate immediate-select and pure-post-select `try_table` counters with `sgo_try_table_select_guard_if_index` and `sgo_count_try_table_select_guard_read`.
- Replaced separate immediate-select and pure-post-select `try_table` + `ref.is_null` counters with `sgo_try_table_ref_is_null_select_guard_if_index` and `sgo_count_try_table_ref_is_null_select_guard_read`.
- Reused the shared `sgo_scan_optional_external_pure_if_index` scanner plus shared direct `if set` and exact `if return; set` tail appliers.

No intentional behavior change: the slice preserves the already-probed immediate select, pure-post-select, and exact if-return select families while removing duplicated matcher and tail code.

## Validation

- `moon test src/passes`: 1590/1590 passed.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-select-shared-matcher-10k`: 9975/10000 compared, 9975 normalized matches, 0 mismatches, 0 validation failures, 0 generator failures, 25 Binaryen/tool command failures.
- `moon info && moon fmt && moon test`: 3666/3666 passed.

## Remaining work

`[SGO]003` remains active/partial. This does not claim full Binaryen `SimplifyGlobals.cpp` parity and does not broaden caught `try_table`, calls, trapping/effectful consumers, control-transfer, or same-init expression equivalence.
