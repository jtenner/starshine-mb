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
  - ./0661-2026-05-25-sgo-load-table-get-independence-audit.md
  - ./0662-2026-05-25-sgo-store-bulk-independence-audit.md
  - ./0663-2026-05-25-sgo-effect-wrapper-composition-inventory.md
---

# SGO named side-effect family probe gate (`[SGO]003D2`)

## Scope

This docs/backlog slice resolves `[SGO]003D2`, the gate that was created to prevent newly discovered side-effect independence families from staying implicit. It does not change optimizer behavior and does not claim full Binaryen `SimplifyGlobals.cpp` parity.

## Gate audit

No behavior-ready new side-effect family is currently named by the active Starshine evidence:

- The current FlowScanner already has centralized, source-visible predicates for the families that recent SGO side-effect slices admitted: clean scalar/table stores, clean memory/table bulk effects, scalar memory loads, `table.get`, no-operand drops, size queries, independent grow prefixes, direct/indirect/call-ref clean-result calls, and supported pure/SIMD value consumers.
- Research notes 0644, 0661, 0662, and 0663 either closed named families as already covered or preserved them as explicit non-goals unless fresh Binaryen-positive evidence appears.
- The parity matrix still labels side-effecting value-flow as partial and names the covered families, but it does not name a remaining uncovered opcode family with enough oracle evidence to implement safely in this slice.
- The plausible examples listed in the backlog remain unsuitable as implicit work: atomics and SIMD memory operations have synchronization/trap/aliasing concerns, relaxed SIMD memory-shaped cases would need exact opcode and feature evidence, calls or call-like effects require read/write summaries or generated-effect facts, and any new bulk form must be named with paired tainted/global-steered negatives.

## Decision

Close `[SGO]003D2` as a research-only discovery gate with no current named candidates. Future side-effect independence discoveries must be filed as explicit child slices before behavior changes. Each new child must name the exact opcode or wrapper grammar, cite Binaryen source/lit/fuzz evidence, add candidate-derived/global-steered/unknown-effect/aliasing negatives, avoid broad whitelist additions, run `moon test src/passes`, and run direct SGO compare fuzz for behavior-bearing matcher or dataflow changes.

## Validation

No optimizer behavior, tests, public API, or pass docs changed in this slice. `git diff --check` is sufficient commit validation.

## Remaining risks

This audit is not proof that Binaryen lacks every possible side-effect independence positive. It only closes the generic hidden-work gate for the current evidence set. `[SGO]003D3` should now perform the closeout audit for `[SGO]003D`, while parent `[SGO]003` remains active/partial for broader Binaryen breadth work.
