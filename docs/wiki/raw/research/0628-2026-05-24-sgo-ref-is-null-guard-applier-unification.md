# SGO ref.is_null guard applier unification

Date: 2026-05-24

## Status

Refactor-only implementation slice for `[SGO]003`. No intended behavior broadening and no claim of full Binaryen `SimplifyGlobals.cpp` parity.

## Goal

Continue consolidating no-catch `try_table` read-only-to-write guard handling. The immediate `try_table; ref.is_null; if global.set` path and exact `try_table; ref.is_null; if return; const; global.set` tail still used bespoke appliers even though the select/compare families now route through the shared no-catch `try_table` direct/if-return body applier.

## Implementation

Changed `src/passes/simplify_globals_optimizing.mbt` only.

Added shared immediate `ref.is_null` guard helpers:

- `sgo_try_table_ref_is_null_guard_if_index(...)`
  - recognizes the existing no-catch `try_table; ref.is_null; if` prefix and returns the existing guard `if` index;
- `sgo_count_try_table_ref_is_null_guard_read(...)`
  - routes that guard index through `sgo_count_try_table_guard_read(...)`, the same direct/if-return no-catch `try_table` applier used by the compare/select families.

Removed the bespoke immediate direct-set and exact if-return-set helpers:

- `sgo_count_try_table_ref_is_null_read_only_to_write_read(...)`
- `sgo_count_try_table_ref_is_null_if_return_set_read(...)`

Updated `sgo_count_no_catch_try_table_specific_condition_guards(...)` to dispatch the immediate `ref.is_null` family through the shared helper.

## Preserved boundaries

This is a structural refactor only. It preserves:

- no-catch `try_table` prefix checks;
- immediate `ref.is_null` only, with no new pure-chain or compare placement;
- direct `if global.set` handling;
- exact `if return; const; global.set` tail handling;
- caught `try_table` conservatism;
- existing compare/select/ref.is_null-select handling through their matcher-specific helpers.

No tests were added because this slice intentionally does not broaden behavior. Existing tests cover the immediate `ref.is_null` direct and exact if-return families plus caught `try_table` negatives.

## Validation

- `moon fmt && moon test src/passes`
  - `1590/1590` tests passed.
  - Existing unrelated warnings in DAE and pass-manager white-box tests remain.
- Direct SGO fuzz:
  - command: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-ref-is-null-direct-guard-unify-10k`
  - compared: `9975/10000`
  - normalized matches: `9975`
  - mismatches: `0`
  - validation failures: `0`
  - generator failures: `0`
  - Binaryen/tool command failures: `25`

## Remaining work

`[SGO]003` remains active/partial. This refactor only unifies already-supported immediate `ref.is_null` guard application. Future behavior-bearing slices still need focused Binaryen oracle support, tests-first implementation, catch/control/trapping guardrails, and direct `--pass simplify-globals-optimizing` fuzz evidence.
