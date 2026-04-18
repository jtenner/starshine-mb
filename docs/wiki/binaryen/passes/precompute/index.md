---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/precompute_test.mbt
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../raw/research/0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `precompute`

- Active hot pass in the Starshine registry.
- Current summary: Fold exact constant integer expressions that are trap-free and stable across the top-level precompute slots.
- Current Binaryen terminology check: upstream-facing sources still expose both `--precompute` and `--precompute-propagate`; this page keeps the repo's `precompute` umbrella label and records the ordered audit's Binaryen slot names explicitly when they differ.
- Current 2026-04-18 ordered generated-artifact follow-up: the early generated `cmd.wasm` slot at Binaryen slot `19` (`precompute-propagate`) emits invalid raw wasm (`func 108` missing its required `i32` result), while the later slot `43` still completes with meaningful equality.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster until dedicated strategy and parity pages land.
