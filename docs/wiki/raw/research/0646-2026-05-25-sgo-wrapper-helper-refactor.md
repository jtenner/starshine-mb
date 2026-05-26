---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../../../.tmp/pass-fuzz-sgo-wrapper-helper-refactor-10k/result.json
---

# SGO block/no-catch wrapper helper refactor (`[SGO]003O`)

## Scope

This is a refactor-only maintainability slice for `simplify-globals-optimizing`. It centralizes repeated block / no-catch `try_table` wrapper extraction paired with external-pure condition index discovery.

## Change

Added `sgo_count_block_condition_external_pure_read_with_index(...)` and routed the four direct/reverse external-pure reader paths through it:

- direct external-pure condition with a same-global set body;
- direct external-pure condition with an `if return; set` tail;
- reverse external-pure condition with a same-global set body;
- reverse external-pure condition with an `if return; set` tail.

The helper only combines the duplicated `sgo_block_or_no_catch_try_table_body(...)` / `Some(if_index)` match and invokes the existing counter callback.

## Behavior

No optimizer behavior changed. The refactor preserves:

- the same block and no-catch `try_table` wrapper acceptance;
- the same direct versus reverse external-pure condition index helpers;
- the existing same-global set and `if return; set` tail counters;
- catch-bearing `try_table`, call/control, trapping/effectful, and unsupported value-flow boundaries.

## Validation

- `moon test src/passes`: `1600/1600` passed.
- Direct SGO fuzz at `.tmp/pass-fuzz-sgo-wrapper-helper-refactor-10k`: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Command-failure classes are the established mixed-generator Binaryen/tool failures: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.
- `moon info`, `moon fmt`, `moon test`: completed; full test count was `3676/3676` passed, with only existing DAE unused warnings from `moon info`.

## Remaining risks

This does not broaden SGO matcher behavior, close the refactor queue, or claim full Binaryen `SimplifyGlobals.cpp` parity. `[SGO]003` remains active/partial.
