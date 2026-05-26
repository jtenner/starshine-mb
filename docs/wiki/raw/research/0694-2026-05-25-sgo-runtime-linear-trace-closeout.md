---
kind: research
status: accepted
date: 2026-05-25
slice: SGO003E
pass: simplify-globals-optimizing
sources:
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-strategy.md
  - ../../../../agent-todo.md
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../../../src/passes/simplify_globals_optimizing_test.mbt
  - ./0598-2026-05-24-sgo-direct-function-effects-runtime-facts.md
  - ./0599-2026-05-24-sgo-block-carried-function-effects.md
  - ./0600-2026-05-24-sgo-else-local-runtime-facts.md
  - ./0601-2026-05-24-sgo-loop-local-runtime-facts.md
  - ./0602-2026-05-24-sgo-try-table-local-runtime-facts.md
  - ./0693-2026-05-25-sgo-call-effect-parity-closeout.md
---

# SGO runtime linear-trace closeout

## Question

Should `[SGO]003E` remain an active implementation queue after the currently landed runtime `ConstantGlobalApplier` / linear-trace slices, or should it be closed as evidence-gated until a fresh Binaryen-positive fixture identifies a specific remaining runtime-propagation shape?

## Findings

The current Starshine implementation already covers the runtime linear-trace surface that has focused source/probe evidence:

- `sgo_rewrite_runtime_trace_expr_with_facts(...)` tracks exact constant write facts through straight-line function bodies, top-level no-op/drop/pure noise, carryable plain blocks, no-else `then` bodies, `then` bodies with `else`, else-local fresh facts, loop-local fresh facts, and `try_table` body-local facts.
- Direct calls are not a blanket barrier: `sgo_runtime_trace_clear_call_effects(...)` uses the fixed-point direct-call mutation summary from the `[SGO]003D` work and clears only globals the known callee may mutate. Unknown/imported/indirect/reference/return-call shapes remain conservative barriers.
- Joins and control transfers remain conservative: facts are cleared after `if`, `loop`, and `try_table` joins; pre-if facts do not enter else arms; loop facts do not escape loops; branch/return/throw/control-transfer shapes clear facts.
- Focused tests cover private/imported/exported scalar facts, `ref.func` and `ref.null` facts, direct-call and nested plain-block carry, block/call/branch barriers, no-else and then-with-else propagation, else-local propagation, loop-local propagation, `try_table`-local propagation, top-level noise, and non-constant writes.

No new optimizer code was needed for this closeout. The remaining items in the old `[SGO]003E` task list are broader adjacency ideas, not an active exact child backed by a currently known Binaryen-positive reduced fixture.

## Decision

Close `[SGO]003E` as **accepted / evidence-gated** for v0.1.0.

Future runtime linear-trace work should reopen under a fresh child slice only when it supplies:

1. an exact Binaryen-positive fixture for a specific runtime propagation shape not already covered;
2. paired negatives for joins/backedges, candidate-derived operands, unknown calls, branches, returns, throws, non-constant writes, and type/refinalization-sensitive replacements as relevant;
3. focused tests plus direct `simplify-globals-optimizing` fuzz evidence for any behavior change.

## Validation

No Moon or fuzz validation was run for this docs/backlog-only closeout because optimizer behavior, tests, registry entries, public APIs, and generated artifacts did not change. The latest behavior-bearing evidence remains the focused tests and fuzz lanes from the cited 0598 through 0602 runtime slices plus the 0693 call/effect closeout.
