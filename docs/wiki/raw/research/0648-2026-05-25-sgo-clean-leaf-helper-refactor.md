---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../../../.tmp/pass-fuzz-sgo-clean-leaf-helper-refactor-10k/result.json
---

# SGO FlowScanner clean-leaf helper refactor (`[SGO]003O`)

## Scope

This is a refactor-only maintainability slice for `simplify-globals-optimizing`. It centralizes repeated FlowScanner handling for trivially clean leaf values without changing matcher breadth.

## Change

Added `sgo_flow_push_clean_leaf_if_known(...)` and reused it in the primary FlowScanner prefix, clean-prefix scanner, and arm-result scanner.

The helper only recognizes the already-supported clean leaf set:

- constant instructions accepted by `sgo_const_instr(...)`;
- nullary pure FlowScanner instructions such as `memory.size` and `table.size`;
- `local.get` values.

Candidate `global.get` handling remains scanner-specific because the primary and arm-result scanners must count and taint candidate reads while the clean-prefix scanner treats all global reads as clean prefix values.

## Behavior

No optimizer behavior changed. The refactor preserves:

- candidate-global read counting and tainting;
- clean wrong-global reads;
- clean local leaf handling;
- clean `memory.size` / `table.size` handling;
- existing clean-prefix, arm-result, nested-control, call, trapping/effectful, and unsupported consumer boundaries.

## Validation

- `moon test src/passes`: `1600/1600` passed.
- Direct SGO fuzz at `.tmp/pass-fuzz-sgo-clean-leaf-helper-refactor-10k`: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Command-failure classes are the established mixed-generator Binaryen/tool failures: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.
- `moon info`, `moon fmt`, `moon test`: completed; full test count was `3676/3676` passed, with only existing DAE unused warnings from `moon info`.

## Remaining risks

This does not broaden SGO matcher behavior, close the refactor queue, or claim full Binaryen `SimplifyGlobals.cpp` parity. `[SGO]003` remains active/partial.
