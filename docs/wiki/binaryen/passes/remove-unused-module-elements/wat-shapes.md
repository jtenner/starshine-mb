---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
related:
  - ./index.md
  - ./retention-and-index-rewrites.md
  - ./parity.md
---

# `remove-unused-module-elements` WAT And Module Shapes

## Main Idea

- This pass is not about one local control-flow idiom.
- It is about whole-module liveness and rewrite shapes: which module items remain reachable, which imported parents must stay alive, and which surviving indices need remapping.

## Important Shapes

- Unused defined functions, globals, tables, memories, or tags that have no remaining live path from exports, start, code, segments, or other live module items.
- Imported tables or memories that would otherwise look dead, but must stay because active elem or data segments still initialize them.
- Active element segments that are semantically no-ops:
  null-only initializers on imported parents can become droppable.
- Active data segments that are semantically no-ops:
  zero-byte active data on live memories should be droppable.
- Surviving code that carries explicit module indices:
  calls, `ref.func`, globals, tables, memories, tags, `elem`, and `data` operations must all be rewritten after compaction.

## Current Test-Shaped Examples

- Explicit memarg rewrite shapes:
  surviving loads, stores, atomics, and SIMD memory ops must rewrite their memory indices.
- Imported-parent retention shapes:
  live active segments can force an otherwise-unused imported table or memory to survive.
- Imported-element drop shapes:
  unused imported memories, tables, globals, and tags should be dropped and survivors remapped.
- No-op active-segment cleanup shapes:
  empty active data and effect-free nullref active elem segments should disappear.
- Live defined-table retention shapes:
  non-noop active `nullfuncref` elem segments on a live defined table still matter and must stay.

## Practical Rule

- For RUME, "WAT shapes" usually means "module layouts plus section content that change what counts as live."
- When adding tests, prefer fixtures that demonstrate both the retention decision and at least one rewritten surviving index.
