---
kind: research
status: strong
created: 2026-06-25
sources:
  - ./0892-2026-06-25-code-pushing-final-closeout.md
  - ./0901-2026-06-25-code-pushing-binrep-followup-closeout.md
  - ./0902-2026-06-25-code-pushing-ignore-implicit-traps-implementation.md
  - ./0905-2026-06-25-code-pushing-intrinsic-no-effects-implementation.md
  - ./0906-2026-06-25-code-pushing-ref-into-if-refinalization.md
  - ./0907-2026-06-25-code-pushing-preset-neighborhood-closeout.md
  - ../../../../agent-todo.md
  - ../../../binaryen/passes/code-pushing/index.md
  - ../../../binaryen/passes/code-pushing/starshine-strategy.md
  - ../../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
---

# Explicit `code-pushing` closeout marker

## Decision

`[O4Z-AUDIT-CP]` is closed as of 2026-06-25.

This explicit marker exists because the original final closeout (`0892`) was followed by user-directed reopening of prerequisite blockers. Those reopened blockers are now also closed:

- `0901`: replacement-oriented binrep follow-up closeout;
- `0902`: distinct Binaryen `--ignore-implicit-traps` / `-iit` implementation;
- `0905`: exact imported `binaryen-intrinsics` / `call.without.effects` movement with pure/nontrapping arguments;
- `0906`: lit-derived `ref-into-if` local refinalization / nullable weakening;
- `0907`: public `optimize` / `shrink` preset-neighborhood proof for `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure`.

No active useful user-directed `code-pushing` gap remains known.

## Reopening criteria

Reopen `code-pushing` only for one of these concrete signals:

1. a new source-backed Binaryen-positive `code-pushing` behavior that Starshine does not implement;
2. a generated compare mismatch classified as a real CP behavior/validity issue rather than cleanup/representation drift;
3. a Starshine validation failure after CP;
4. shared-GC fixture support becoming required for an actual CP behavior surface;
5. public preset/neighborhood drift around the proven CP slot.

## Caveats that do not keep CP open

- Starshine still lacks a validator definite-assignment mode for non-defaultable non-null body locals. The `0906` focused fixture bypasses input validation for that Binaryen-style source shape and requires the optimized output to validate.
- Broader shared-GC WAT fixture support remains separate until a source-backed CP surface needs it.
- Full `moon test --target native src/passes` was blocked during recent CP slices by missing local `tests/node/dist/starshine-debug-wasi.wasm`; this is unrelated to CP behavior.

## Validation basis

This marker is docs/status only. It does not change executable behavior. The behavior validation is the accumulated evidence from `0892`, `0902`, `0905`, `0906`, and `0907`.
