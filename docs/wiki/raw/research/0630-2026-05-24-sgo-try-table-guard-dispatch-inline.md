# SGO try_table guard dispatch inline

Date: 2026-05-24

## Status

Refactor-only implementation slice for `[SGO]003`. No intended behavior broadening and no claim of full Binaryen `SimplifyGlobals.cpp` parity.

## Goal

Continue consolidating no-catch `try_table` read-only-to-write guard dispatch after adding the optional guard-index applier. The top-level no-catch `try_table` specific dispatcher still called six one-line family counters whose only job was to compute an optional guard `if` index and pass it to the shared applier.

## Implementation

Changed `src/passes/simplify_globals_optimizing.mbt` only.

Updated `sgo_count_no_catch_try_table_specific_condition_guards(...)` to call `sgo_count_try_table_guard_if_index_read(...)` directly with each existing matcher:

- `sgo_try_table_select_guard_if_index(...)`;
- `sgo_try_table_select_reverse_compare_guard_if_index(...)`;
- `sgo_try_table_ref_is_null_compare_guard_if_index(...)`;
- `sgo_try_table_ref_is_null_select_guard_if_index(...)`;
- `sgo_try_table_ref_is_null_select_reverse_compare_guard_if_index(...)`;
- `sgo_try_table_ref_is_null_guard_if_index(...)`.

Removed the now-redundant one-line family counter wrappers.

## Preserved boundaries

This is a structural refactor only. It preserves:

- every matcher-specific no-catch `try_table` prefix check;
- immediate, compare, select, and leading-constant reverse-compare family boundaries;
- optional supported pure-post-consumer scans where they already existed;
- direct `if global.set` handling;
- exact `if return; const; global.set` tail handling;
- caught `try_table` conservatism.

No tests were added because this slice intentionally does not broaden behavior. Existing tests cover the routed families.

## Validation

- `moon fmt && moon test src/passes`
  - `1590/1590` tests passed.
  - Existing unrelated warnings in DAE and pass-manager white-box tests remain.
- Direct SGO fuzz:
  - command: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-guard-dispatch-inline-10k`
  - compared: `9975/10000`
  - normalized matches: `9975`
  - mismatches: `0`
  - validation failures: `0`
  - generator failures: `0`
  - Binaryen/tool command failures: `25`

## Remaining work

`[SGO]003` remains active/partial. This refactor only removes redundant one-line counter wrappers for already-supported no-catch `try_table` families. Future behavior-bearing slices still need focused Binaryen oracle support, tests-first implementation, catch/control/trapping guardrails, and direct `--pass simplify-globals-optimizing` fuzz evidence.
