---
kind: entity
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
related:
  - ./wat-shapes.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./scheduler-and-gates.md
  - ./reduced-repros-and-evidence.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `tuple-optimization`

## Role

- `tuple-optimization` is an active hot pass on Starshine's explicit pass surface.
- Its Binaryen-facing job is narrow and specific: lower tuple-like traffic early enough that later local-cleanup passes can delete dead lanes, dead copies, and redundant tuple scratch state.
- Its Starshine implementation is intentionally not a literal tuple-AST clone of Binaryen's pass. HOT lift already expresses most real candidates as multi-result producers plus scalar local bridges, so Starshine rewrites those HOT-native bridge shapes directly.

## Current Summary

- The pass is registered and can be invoked directly through the pass manager and CLI.
- The public `optimize` and `shrink` presets still intentionally omit it because the exact Binaryen slot requires `code-pushing` before it and `simplify-locals-nostructure` after it, and that full slot is not representable in-tree yet.
- Current direct native Binaryen-compare coverage is green on the committed reduced families, but exact-shape white-box coverage and one black-box typed-carrier expectation are still red.
- Full artifact parity is still not signed off. The current standing backlog still treats the debug-artifact compare and tuple-only runtime budget as open work.

## Page Map

- [`./wat-shapes.md`](./wat-shapes.md) - The concrete raw-WAT and reduced test shapes that are supposed to rewrite, the ones that are deliberately rejected, and why each family matters.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - The confirmed upstream Binaryen strategy from `version_129`: use counting, valid-use filtering, copy-graph badness propagation, and the final tuple-local-to-scalar-local rewrite.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) - The current in-tree HOT-native algorithm: candidate discovery, copy-group linking, rewrite suppression, carrier construction, and post-rewrite cleanup.
- [`./scheduler-and-gates.md`](./scheduler-and-gates.md) - The precise Binaryen slot, multivalue gate, and the current reason Starshine keeps tuple-opt off presets even though the explicit pass exists.
- [`./reduced-repros-and-evidence.md`](./reduced-repros-and-evidence.md) - The reduced repro families that have driven the implementation, including retired bug families, still-open exact-shape families, and where each one is locked in tests.
- [`./parity.md`](./parity.md) - The current signoff state: what is green today, what still fails on this branch, and which evidence is current versus historical.

## Practical Rule

- Treat this folder as the canonical living documentation home for tuple optimization.
- Keep the archived `0076` note as provenance and historical implementation context, but file ongoing conclusions here.
- When a new tuple bug appears, document it first as one of:
  - a new transformable WAT/HOT family
  - a new bailout or safety invariant
  - a new parity or lowering drift family
  - a new scheduler or feature-gate constraint

