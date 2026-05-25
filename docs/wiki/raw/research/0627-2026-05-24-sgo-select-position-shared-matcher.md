# SGO select position shared matcher

Date: 2026-05-24

## Status

Refactor-only implementation slice for `[SGO]003`. No intended behavior broadening and no claim of full Binaryen `SimplifyGlobals.cpp` parity.

## Goal

Continue consolidating no-catch `try_table` select-family matchers. The normal `try_table` select and `try_table` + `ref.is_null` select families had duplicated position logic for the three supported select operand placements, and the leading-constant reverse-compare variants duplicated the same shifted shapes.

## Implementation

Changed `src/passes/simplify_globals_optimizing.mbt` only.

Added shared operand-position helpers:

- `sgo_select_pos_around_value(...)`
  - recognizes the existing three pure-constant-sibling select placements around a matched value-producing expression;
- `sgo_select_reverse_compare_pos_around_value(...)`
  - recognizes the existing three leading-constant reverse-compare placements around the same select result.

Routed these matcher families through the shared helpers:

- no-catch `try_table` result feeding select condition / first selected value / second selected value;
- no-catch `try_table` result feeding those selected positions followed by leading-constant compare;
- no-catch `try_table` + `ref.is_null` result feeding the same select positions;
- no-catch `try_table` + `ref.is_null` result feeding those positions followed by leading-constant compare.

The helpers accept a value start position and first instruction after the value, so normal `try_table` uses `(pos, pos + 1)` while `try_table; ref.is_null` uses `(pos, pos + 2)`.

## Preserved boundaries

This is a structural refactor only. It preserves:

- exactly the three existing select operand placements;
- exactly the existing leading-constant reverse-compare select placements;
- no-catch `try_table` prefix checks;
- `ref.is_null` prefix checks for the reference-specific family;
- caught `try_table` conservatism;
- direct/if-return guard application from the prior refactor.

No tests were added because this slice intentionally does not broaden behavior. Existing tests cover the preserved select and `ref.is_null` select families.

## Validation

- `moon fmt && moon test src/passes`
  - `1590/1590` tests passed.
  - Existing unrelated warnings in DAE and pass-manager white-box tests remain.
- Direct SGO fuzz:
  - command: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-select-position-shared-matcher-10k`
  - compared: `9975/10000`
  - normalized matches: `9975`
  - mismatches: `0`
  - validation failures: `0`
  - generator failures: `0`
  - Binaryen/tool command failures: `25`

## Remaining work

`[SGO]003` remains active/partial. This refactor only unifies already-supported select-position matching. Future behavior-bearing slices still need focused Binaryen oracle support, tests-first implementation, catch/control/trapping guardrails, and direct `--pass simplify-globals-optimizing` fuzz evidence.
