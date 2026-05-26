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
  - ./0664-2026-05-25-sgo-named-side-effect-family-probe-gate.md
---

# SGO side-effect independence closeout audit (`[SGO]003D3`)

## Scope

This docs/backlog slice resolves `[SGO]003D3`, the closeout audit for `[SGO]003D` read-only-to-write safe side-effect independence. It does not change optimizer behavior and does not claim full Binaryen `SimplifyGlobals.cpp` parity.

## Closeout check

All currently tracked `[SGO]003D` side-effect-independence follow-ups are either covered, conservative, or separately represented:

- 0644 pinned independent `memory.grow` and `table.grow` prefixes as already covered while preserving candidate-derived grow negatives.
- 0661 closed scalar memory-load and `table.get` independence as already covered by the shared FlowScanner trapping-read predicate and focused clean/tainted tests.
- 0662 closed the named clean store/table/bulk branch as already covered by shared clean pair/triple effect predicates and focused clean/tainted tests.
- 0663 closed the generic wrapper/control-composition inventory: transparent result-block and no-catch `try_table` compositions are already source-aligned, and future wrapper work must name a precise grammar.
- 0664 closed the named-new-family discovery gate with no current behavior-ready candidates for atomics, SIMD memory operations, relaxed SIMD memory-shaped cases, new bulk forms, calls, or call-like effects.
- Direct-call read/write summary work is not hidden under `[SGO]003D`; it remains explicitly represented by `[SGO]003E2` as a deferred prerequisite for future call-shaped positives.

## Decision

Close `[SGO]003D` and `[SGO]003D3` as complete for the currently enumerated side-effect-independence scope. Future side-effect independence work must be filed as a new explicit child with named Binaryen-positive evidence, paired candidate-derived/global-steered/unknown-effect/aliasing negatives, and direct SGO validation for behavior changes.

Parent `[SGO]003` remains active/partial. This closeout only retires the current `[SGO]003D` side-effect-independence bucket; it is not a full `SimplifyGlobals.cpp` parity claim.

## Validation

No optimizer behavior, tests, public API, or pass docs changed in this slice. `git diff --check` is sufficient commit validation.

## Remaining risks

Binaryen may still contain uncovered side-effect independence positives outside the named evidence above. Those should reopen work only as exact child slices with fresh oracle evidence, not as a generic whitelist or hidden backlog bucket.
