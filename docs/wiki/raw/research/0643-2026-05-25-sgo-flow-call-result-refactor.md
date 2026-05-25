---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ../../../../.tmp/pass-fuzz-sgo-flow-call-result-refactor-10k/result.json
---

# SGO FlowScanner call-result refactor (`[SGO]003O`)

## Scope

This is a refactor-only maintainability slice for the `simplify-globals-optimizing` read-only-to-write FlowScanner helpers. It follows the 0641 clean-pop helper slice and does not broaden matcher behavior.

## Change

Added `sgo_flow_apply_clean_call_result(...)` in `src/passes/simplify_globals_optimizing.mbt` to centralize the repeated call-handling pattern used by the FlowScanner variants:

1. reject if any value currently on the stack is tainted by the candidate global;
2. clear the stack to model a call boundary with clean operands;
3. optionally push a clean call result.

Most call paths push the clean result exactly as before. The one arm-result scanner path keeps its prior special case: when a call is immediately followed by a `global.get`, it clears the stack but does not synthesize an intervening clean call result.

## Behavior

No behavior changed. The refactor preserves:

- candidate-tainted call operand rejection;
- stack clearing across accepted ordinary/indirect/reference call boundaries;
- clean-result synthesis where the previous inline code synthesized it;
- the arm-result scanner's adjacent-`global.get` exception;
- existing call-read summary limitations: calls still do not become syntactic read-only-to-write events, and imported/indirect/reference/generated-effects breadth remains out of scope.

## Validation

- `moon test src/passes`: `1598/1598` passed.
- `moon info`, `moon fmt`, `moon test`: completed; full test count was `3674/3674` passed, with only existing DAE unused warnings from `moon info`.
- Direct SGO fuzz at `.tmp/pass-fuzz-sgo-flow-call-result-refactor-10k`: `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Command-failure classes: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.

## Remaining risks

This is not a direct-call read/write-summary implementation and does not resolve `[SGO]003E2`. `[SGO]003` remains active/partial.
