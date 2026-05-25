---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../../../.tmp/pass-fuzz-sgo-effect-predicate-refactor-10k/result.json
---

# SGO FlowScanner effect predicate refactor (`[SGO]003O`)

## Scope

This is a refactor-only maintainability slice for `simplify-globals-optimizing`. It centralizes repeated FlowScanner predicate groups for clean two-operand and three-operand side-effect families without changing matcher breadth.

## Change

Added two opcode-family predicates:

- `sgo_is_flow_clean_pair_effect_instr(...)` for `table.set` and scalar store instructions that consume two clean operands;
- `sgo_is_flow_clean_triple_effect_instr(...)` for bulk memory/table operations that consume three clean operands.

The primary FlowScanner prefix, clean-prefix scanner, and arm-result scanner now use those predicates before applying the existing clean pair/triple stack checks.

## Behavior

No optimizer behavior changed. The refactor preserves:

- exactly the same clean side-effect opcode families;
- the same stack arity and taint checks via `sgo_flow_pop_clean_pair(...)` and `sgo_flow_pop_clean_triple(...)`;
- existing candidate-read counting and tainting;
- existing call/control/trapping/effectful-candidate and unsupported consumer boundaries.

## Validation

- `moon test src/passes`: `1600/1600` passed.
- Direct SGO fuzz at `.tmp/pass-fuzz-sgo-effect-predicate-refactor-10k`: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Command-failure classes are the established mixed-generator Binaryen/tool failures: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.
- `moon info`, `moon fmt`, `moon test`: completed; full test count was `3676/3676` passed, with only existing DAE unused warnings from `moon info`.

## Remaining risks

This does not broaden SGO matcher behavior, close the refactor queue, or claim full Binaryen `SimplifyGlobals.cpp` parity. `[SGO]003` remains active/partial.
