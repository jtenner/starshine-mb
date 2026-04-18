---
kind: entity
status: stub
last_reviewed: 2026-04-18
sources:
  - ../../../../../src/passes/dead_code_elimination.mbt
  - ../../../../../src/passes/dead_code_elimination_test.mbt
  - ../late-pipeline-dispatch.md
related:
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
---

# `dead-code-elimination`

- Active hot pass in the Starshine registry.
- Current summary: Prune unreachable tails, dead dropped values, and dead-result structured control in hot IR regions.
- Current Binaryen terminology check: upstream-facing sources still describe the corresponding Binaryen pass as `Dce` / dead-code elimination rather than showing a contradictory rename or removal.
- Use [`../late-pipeline-dispatch.md`](../late-pipeline-dispatch.md) for the current tail roster and the 2026-04-18 non-GitHub terminology check until dedicated strategy and parity pages land.
