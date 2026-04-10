---
kind: entity
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
related:
  - ./wat-shapes.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./retention-and-index-rewrites.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `remove-unused-module-elements`

## Role

- `remove-unused-module-elements` is an active module pass in Starshine's Binaryen namespace.
- It is the module-wide dead-element cleanup pass for functions, globals, tables, memories, tags, element segments, and data segments.

## Current Summary

- Remove unreachable module elements.
- Keep imported parents alive when active segments still need them.
- Rewrite every surviving module index surface after compaction.

## Page Map

- [`./wat-shapes.md`](./wat-shapes.md) - Module and instruction shapes that make RUME meaningful, including imported parents, active segments, and explicit index carriers.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - Upstream `version_129` strategy and its three-state model of no-reference, reference-only, and used elements.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) - Current in-tree Starshine strategy and why this pass stays module-scoped.
- [`./retention-and-index-rewrites.md`](./retention-and-index-rewrites.md) - The concrete rewrite surface for func, global, table, memory, tag, elem, data, name, and annotation indices.
- [`./parity.md`](./parity.md) - Current signoff state, focused test coverage, and remaining non-semantic compare gaps.

## Current Maintenance Rule

- Treat this folder as the canonical home for future RUME work.
- New research about dead imported parents, active segment retention, or module-index rewrite drift should land here instead of in generic optimizer docs.
