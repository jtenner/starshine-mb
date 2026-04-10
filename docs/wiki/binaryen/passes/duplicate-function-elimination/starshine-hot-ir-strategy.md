---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./parity.md
  - ./type-compaction-and-metadata.md
---

# Starshine "Hot IR" Strategy For `duplicate-function-elimination`

## Current Rule

- Despite the filename requested by the folder schema, this pass does not currently have a HOT-IR implementation.
- Starshine intentionally keeps `duplicate-function-elimination` as a module pass because the work crosses:
  - function-index ownership
  - section rewrites
  - type compaction
  - name and annotation metadata

## Current In-Tree Strategy

- The pass is registered as an active module pass in `src/passes/optimize.mbt`.
- The dispatcher runs it through `run_hot_pipeline_apply_module_pass(...)` in `src/passes/pass_manager.mbt`.
- The current implementation does:
  - one `dfe_iteration(...)` over the module
  - element-kind canonicalization
  - duplicate simple-type compaction when a merge happened
- If no merge happens, Starshine still canonicalizes compactable element segments and strips the `name` section.

## Current Strengths

- Annotation-aware equality and non-merge behavior.
- Whole-module `FuncIdx` rewrite coverage.
- Post-merge simple-type compaction across surviving type users.
- Explicit performance timer hooks through `dfe_run_module_pass_with_perf(...)`.

## Current Boundaries

- The implementation is one explicit module iteration today.
- That matches the direct explicit pass surface at default Binaryen options, but it does not yet model Binaryen's larger option-dependent iteration budget used inside `-O` / `-Os`.
- Any future HOT-IR-adjacent work here should still end in a module-level reconciliation phase; duplicate elimination cannot become a pure per-function pass honestly.

## Practical Rule

- Keep DFE design and testing module-centric.
- Do not force this pass into HOT IR just for namespace symmetry.
- If future optimize-preset parity needs multi-round DFE behavior, extend the module-pass scheduler or pass options rather than inventing a lifted approximation.
