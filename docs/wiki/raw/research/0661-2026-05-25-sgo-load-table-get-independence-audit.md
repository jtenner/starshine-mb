---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../agent-todo.md
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../../../src/passes/simplify_globals_optimizing_test.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ./0644-2026-05-25-sgo-grow-independence-guardrails.md
---

# SGO scalar-load and `table.get` independence audit (`[SGO]003D`)

## Scope

This docs/backlog slice resolves the `[SGO]003D` checklist question about whether scalar-load or `table.get` independence forms remain obviously uncovered after the existing side-effect guardrails. It does not change optimizer behavior and does not claim full Binaryen `SimplifyGlobals.cpp` parity.

## Findings

No new scalar-load or `table.get` behavior slice is warranted from the current evidence:

- `sgo_is_flowscanner_trapping_read_instr(...)` already centralizes `table.get` plus all scalar memory-load opcodes (`i32`, `i64`, `f32`, `f64`, and the integer narrow signed/unsigned load families) as trapping reads that may be accepted only after a clean operand is popped and a clean result is pushed.
- The FlowScanner callers reuse that predicate in the direct condition, nested-arm, block/loop/`try_table`, and tail/wrapper matchers rather than leaving a separate scalar-load or `table.get` whitelist gap.
- Focused tests already pin clean independent scalar-load / `table.get` positives and candidate-derived negatives, including direct side-effecting conditions, nested-if arm flow through clean `i64.load`, nested-if arm flow through clean `table.get`, and the paired global-derived load/table-get preservation test.
- The 0644 grow-independence guardrail slice separately pinned independent `memory.grow` / `table.grow` prefixes as already covered while preserving candidate-derived grow negatives, so the load/table-get audit should not reopen grow handling.

## Backlog decision

The scalar-load / `table.get` checklist item is closed as already covered by source and tests. `[SGO]003D` remains active only for exact future side-effect families that are backed by fresh Binaryen probes and paired candidate-derived negatives; do not add broad whitelist entries by analogy from the current load/table-get support.

## Validation

No optimizer behavior, tests, public API, or pass docs changed in this slice. `git diff --check` is sufficient commit validation.

## Remaining risks

This audit does not prove every possible wrapper/control composition around loads or `table.get`. Future discoveries should be filed as explicit child slices if they need new wrapper grammar, dominance reasoning, or behavior-bearing matcher changes. Atomics, SIMD memory ops, relaxed SIMD, broad unprobed bulk operations, calls with candidate-derived operands, and trapping reads fed by the candidate global remain non-goals without fresh oracle evidence.
