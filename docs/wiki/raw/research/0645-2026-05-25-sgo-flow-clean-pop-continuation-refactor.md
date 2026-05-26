---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../../../.tmp/pass-fuzz-sgo-flow-clean-pop-continued-10k/result.json
---

# SGO FlowScanner clean-pop continuation refactor (`[SGO]003O`)

## Scope

This is a refactor-only maintainability slice for `simplify-globals-optimizing`. It continues the 0641 clean-pop helper work across the remaining nested-if arm-flow scanners without changing matcher behavior.

## Change

Reused the existing helpers:

- `sgo_flow_pop_clean(...)`
- `sgo_flow_pop_clean_then_push_clean(...)`

in additional FlowScanner variants, including arm-result, nested-if outer-index, and block-wrapped nested-if arm-flow paths. Repeated inline `match sgo_flow_pop(stack)` blocks for clean `global.set` / `local.set`, `drop`, `local.tee`, trapping-read operands, and clean `if` conditions now share the same helper predicates.

## Behavior

No behavior changed. The refactor preserves:

- stack-underflow failure behavior;
- tainted-value rejection;
- clean replacement pushes for `local.tee` and clean trapping-read operands;
- candidate-steered `if` detection in the outer-index scanner;
- existing boundaries for calls, control, caught `try_table`, trapping/effectful candidate consumers, and unsupported post-consumers.

## Validation

- `moon test src/passes`: `1600/1600` passed.
- Direct SGO fuzz at `.tmp/pass-fuzz-sgo-flow-clean-pop-continued-10k`: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Command-failure classes: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.
- `moon info`, `moon fmt`, `moon test`: completed; full test count was `3676/3676` passed, with only existing DAE unused warnings from `moon info`.

## Remaining risks

This does not close the refactor queue and does not resolve any remaining Binaryen `SimplifyGlobals.cpp` breadth gap. `[SGO]003` remains active/partial.
