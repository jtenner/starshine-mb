# SGO optional try_table guard applier

Date: 2026-05-24

## Status

Refactor-only implementation slice for `[SGO]003`. No intended behavior broadening and no claim of full Binaryen `SimplifyGlobals.cpp` parity.

## Goal

Continue consolidating no-catch `try_table` read-only-to-write guard handling after the immediate `ref.is_null` applier refactor. The individual guard-family entry points still repeated the same `Int?` match before routing a discovered guard `if` index through the shared no-catch `try_table` direct/if-return body applier.

## Implementation

Changed `src/passes/simplify_globals_optimizing.mbt` only.

Added:

- `sgo_count_try_table_guard_if_index_read(...)`
  - accepts an optional guard `if` index;
  - applies `sgo_count_try_table_guard_read(...)` only when a matcher found a guard;
  - centralizes the `Some`/`None` dispatch used by no-catch `try_table` guard families.

Routed these existing guard-family counters through the helper:

- immediate `try_table; ref.is_null` guards;
- `try_table; ref.is_null` compare guards;
- `try_table` select guards;
- `try_table` select leading-constant reverse-compare guards;
- `try_table; ref.is_null` select guards;
- `try_table; ref.is_null` select leading-constant reverse-compare guards.

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
  - command: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-optional-guard-applier-10k`
  - compared: `9975/10000`
  - normalized matches: `9975`
  - mismatches: `0`
  - validation failures: `0`
  - generator failures: `0`
  - Binaryen/tool command failures: `25`

## Remaining work

`[SGO]003` remains active/partial. This refactor only centralizes optional guard-index dispatch for already-supported no-catch `try_table` families. Future behavior-bearing slices still need focused Binaryen oracle support, tests-first implementation, catch/control/trapping guardrails, and direct `--pass simplify-globals-optimizing` fuzz evidence.
