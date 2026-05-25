# SGO try_table guard applier unification

Date: 2026-05-24

## Status

Refactor-only implementation slice for `[SGO]003`. No intended behavior broadening and no claim of full Binaryen `SimplifyGlobals.cpp` parity.

## Goal

Continue consolidating the no-catch `try_table` read-only-to-write condition families after the dispatcher split in [`0625`](./0625-2026-05-24-sgo-read-only-to-write-dispatch-split.md). The prior code repeated the same direct `if global.set` applier and exact `if return; set` tail applier across normal select, reverse-compare select, `ref.is_null` compare, `ref.is_null` select, and `ref.is_null` select reverse-compare paths.

## Implementation

Changed `src/passes/simplify_globals_optimizing.mbt` only.

Added `sgo_count_try_table_guard_read(...)` as the shared no-catch `try_table` guard applier. It extracts the `try_table` body at the already-matched position and applies both existing body-level proofs:

- `sgo_count_body_direct_if_set_read(...)`
- `sgo_count_body_if_return_tail_read(...)`

Routed these existing matcher families through the shared applier:

- `try_table` + select immediate/pure guard;
- `try_table` + select + leading-constant reverse-compare guard;
- `try_table` + `ref.is_null` + compare/pure guard;
- `try_table` + `ref.is_null` + select immediate/pure guard;
- `try_table` + `ref.is_null` + select + leading-constant reverse-compare guard.

The two reverse-compare families previously had separate direct-set and if-return functions. They are now single combined guard functions because the dispatcher already invoked both paths at the same position.

## Preserved boundaries

This is a structural refactor only. It preserves:

- all existing no-catch `try_table` select and `ref.is_null` condition families;
- direct `if global.set` and exact `if return; set` tail behavior;
- matcher-specific no-catch/catch-bearing checks;
- caught `try_table` conservatism;
- loop and non-`try_table` dispatch behavior.

No tests were added because this slice intentionally does not broaden behavior. Existing tests cover the preserved families.

## Validation

- `moon fmt && moon test src/passes`
  - `1590/1590` tests passed.
  - Existing unrelated warnings in DAE and pass-manager white-box tests remain.
- Direct SGO fuzz:
  - command: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-guard-applier-unify-10k`
  - compared: `9975/10000`
  - normalized matches: `9975`
  - mismatches: `0`
  - validation failures: `0`
  - generator failures: `0`
  - Binaryen/tool command failures: `25`

## Remaining work

`[SGO]003` remains active/partial. This refactor only removes duplicated guard application. Future behavior-bearing slices still need focused Binaryen oracle support, tests-first implementation, catch/control/trapping guardrails, and direct `--pass simplify-globals-optimizing` fuzz evidence.
