# SGO try_table shared ref.is_null compare matcher

Date: 2026-05-24

## Question

Can the no-catch `try_table (result funcref) -> ref.is_null -> compare` read-only-to-write family be made less one-off before adding more breadth?

## Change

Refactor-only structural slice in `src/passes/simplify_globals_optimizing.mbt`:

- centralizes the no-catch `try_table` plus adjacent `ref.is_null` prefix check in `sgo_try_table_ref_is_null_prefix_matches`;
- centralizes immediate-or-supported-pure-post-consumer scanning in `sgo_scan_optional_external_pure_if_index`;
- replaces the separate normal compare, reverse compare, pure normal compare, pure reverse compare, and exact `if return; set` counters with one `sgo_try_table_ref_is_null_compare_guard_if_index` plus one `sgo_count_try_table_ref_is_null_compare_guard_read` dispatcher;
- centralizes direct `if set` and exact `if return; set` tail application in small try-table body helpers.

No intentional behavior change: this only preserves the already-probed 0616-0619 family while removing duplicate matchers and tail code.

## Validation

- `moon test src/passes`: 1580/1580 passed.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-ref-is-null-shared-matcher-10k`: 9975/10000 compared, 9975 normalized matches, 0 mismatches, 0 validation failures, 0 generator failures, 25 Binaryen/tool command failures.
- `moon info && moon fmt && moon test`: 3656/3656 passed.
- `git diff --check`: passed.

## Remaining work

`[SGO]003` stays active/partial. This does not claim full Binaryen `SimplifyGlobals.cpp` parity and does not broaden caught `try_table`, calls, branchy/control-transfer shapes, trapping/effectful operands, or same-init expression equivalence.
