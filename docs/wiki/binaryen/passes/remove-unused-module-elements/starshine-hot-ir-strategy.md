---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./retention-and-index-rewrites.md
  - ./parity.md
---

# Starshine "Hot IR" Strategy For `remove-unused-module-elements`

## Current Rule

- This pass does not currently have a HOT-IR implementation.
- Starshine intentionally keeps `remove-unused-module-elements` as a module pass because the work crosses:
  - module-section ownership
  - imported versus defined item boundaries
  - element and data segment liveness
  - whole-module index remapping
  - name and annotation metadata

## Current In-Tree Strategy

- The pass is registered as an active module pass in `src/passes/optimize.mbt`.
- The dispatcher runs it through `run_hot_pipeline_apply_module_pass(...)` in `src/passes/pass_manager.mbt`.
- The implementation builds liveness sets for:
  - functions
  - globals
  - tables
  - memories
  - tags
  - element segments
  - data segments
- After liveness collection, it rebuilds the module and rewrites all surviving index carriers.

## Current Strengths

- Imported parent retention for active elem and data initialization.
- Explicit imported-element removal and survivor remapping.
- Broad in-code rewrite coverage for function, global, table, memory, tag, element, and data indices.
- Name-section and function-annotation remapping on surviving indices.

## Current Boundaries

- This is a direct module rewrite, not a lifted per-function cleanup.
- Any future HOT-IR-adjacent research still has to end in a module reconciliation phase; this pass cannot honestly become a pure function-local optimization.

## Practical Rule

- Keep RUME design and testing module-centric.
- When a mismatch appears, debug the liveness graph and remap surface before trying to invent HOT-IR explanations.
