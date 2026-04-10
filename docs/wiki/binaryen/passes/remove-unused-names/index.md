---
kind: entity
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/remove_unused_names.mbt
  - ../../../../../src/passes/remove_unused_names_test.mbt
related:
  - ./invalid-tag-index-parser-gap.md
  - ../../no-dwarf-default-optimize-path.md
---

# `remove-unused-names`

- Active hot pass in the Starshine registry.
- Current summary: peel redundant same-typed block wrappers and demote loops whose labels have no remaining continue targets.
- Current durable page: [`./invalid-tag-index-parser-gap.md`](./invalid-tag-index-parser-gap.md).
- Expand this folder with strategy and shape pages as broader RUN research lands.
