---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../agent-todo.md
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../../../src/passes/simplify_globals_optimizing_test.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ./0661-2026-05-25-sgo-load-table-get-independence-audit.md
---

# SGO clean store/table/bulk independence audit (`[SGO]003D`)

## Scope

This docs/backlog slice resolves the `[SGO]003D` checklist branch for currently enumerated clean store/table/bulk side-effect families. It does not change optimizer behavior and does not claim full Binaryen `SimplifyGlobals.cpp` parity.

## Findings

No new behavior slice is warranted for the currently named clean store/table/bulk families:

- `sgo_is_flow_clean_pair_effect_instr(...)` already centralizes `table.set` plus scalar store opcodes (`i32.store`, `i64.store`, `i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, `i64.store32`, `f32.store`, and `f64.store`) behind the same two-clean-operand check.
- `sgo_is_flow_clean_triple_effect_instr(...)` already centralizes `memory.copy`, `memory.fill`, `memory.init`, `table.fill`, `table.init`, and `table.copy` behind the same three-clean-operand check.
- The FlowScanner callers reuse those predicates in the same direct, nested-arm, block/loop/`try_table`, and tail/wrapper scans that the 0661 load/table-get audit checked, so there is no separate whitelist gap for these named effect families.
- Focused tests already pin clean positive coverage and tainted-operand preservation for the scalar store families, `table.set`, `memory.fill`, `memory.copy`, `memory.init`, `table.fill`, `table.init`, and `table.copy`.
- `elem.drop` and `data.drop` are also already guarded as clean no-operand effects, with tests for clean nested-if arm flow and global-steered preservation.

## Backlog decision

The currently enumerated clean store/table/bulk checklist branch is closed as already covered by source and tests. `[SGO]003D` should not broaden the FlowScanner by analogy; any future side-effect independence work must name a specific uncovered opcode or wrapper grammar, prove Binaryen-positive behavior first, and add paired candidate-derived or global-steered negatives before implementation.

## Validation

No optimizer behavior, tests, public API, or pass docs changed in this slice. `git diff --check` is sufficient commit validation.

## Remaining risks

This audit does not prove every recursive wrapper/control composition around these effects. It only closes the currently named opcode-family question in the backlog. Atomics, SIMD memory operations, relaxed SIMD, memory/table grow beyond the already-pinned 0644 independent-prefix guardrails, calls with candidate-derived operands, and trapping/effectful operations fed by the candidate global remain non-goals without fresh oracle evidence.
