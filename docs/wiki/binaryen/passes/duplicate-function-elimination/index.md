---
kind: entity
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
related:
  - ./wat-shapes.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./type-compaction-and-metadata.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `duplicate-function-elimination`

## Role

- `duplicate-function-elimination` is an active module pass in Starshine's Binaryen namespace.
- It is not a lifted-function hot pass. Merge choice, function-index rewrites, type compaction, and metadata cleanup all require whole-module state.

## Current Summary

- Merge duplicate defined functions.
- Rewrite surviving function references across the module.
- Compact duplicate simple function type indices when the post-merge type surface allows it.

## Page Map

- [`./wat-shapes.md`](./wat-shapes.md) - Module or WAT shapes that produce merge candidates, rewrite work, or deliberate non-merges.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - Upstream `version_129` strategy, including hash-first grouping and option-dependent iteration budget.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) - Current in-tree Starshine strategy and the explicit reason this pass stays outside HOT IR.
- [`./type-compaction-and-metadata.md`](./type-compaction-and-metadata.md) - Simple-type compaction, name handling, annotation-map rewrites, and element canonicalization.
- [`./parity.md`](./parity.md) - Current artifact parity status and remaining direct-pass gaps.

## Current Maintenance Rule

- Treat this folder as the canonical home for future DFE work.
- New research about duplicate functions, module-wide function-reference rewrites, or type-compaction side effects should land here instead of in generic optimizer docs.
