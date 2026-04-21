---
kind: concept
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./type-compaction-and-metadata.md
  - ./parity.md
---

# Starshine “Hot IR” strategy for `duplicate-function-elimination`

## Current rule

- Despite the filename requested by the folder schema, this pass does not currently have a HOT-IR implementation.
- Starshine intentionally keeps `duplicate-function-elimination` as a module pass because the work crosses:
  - function identity
  - module-wide function-reference rewriting
  - optional type compaction
  - serialized metadata and section cleanup

## Why it stays outside HOT IR

Even the **official** Binaryen pass is module-wide.
It hashes and compares whole functions, then rewrites function references across the module.

The current local pass goes even further by also doing:

- duplicate simple-type compaction
- wide type-index rewriting
- element-kind canonicalization
- name-section stripping
- function-annotation-section bookkeeping

So there is no honest way to model the whole local behavior as a pure per-function HOT pass.

## Current in-tree strategy

- The pass is registered as an active module pass in `src/passes/optimize.mbt`.
- The dispatcher runs it through `run_hot_pipeline_apply_module_pass(...)` in `src/passes/pass_manager.mbt`.
- The current implementation does:
  - one local duplicate-detection iteration
  - local element-kind canonicalization
  - post-merge duplicate simple-type compaction when a merge happened
  - name stripping and annotation-map cleanup

## Current strengths

- Annotation-aware duplicate detection.
- Whole-module function-reference rewrite coverage.
- Local extra cleanup for duplicate simple types and related type users.
- Explicit performance timer hooks.

## Current boundaries

- The implementation is one explicit local module iteration today.
- That matches the low/default visible upstream DFE behavior, but it does not yet model Binaryen's larger option-dependent iteration budget used in stronger optimize contexts.
- The implementation is also **broader** than official Binaryen DFE because it performs local extra cleanup that the official DFE pass file does not.

So there are really two scheduler/parity questions here:

1. how to model upstream DFE's multi-round option-dependent behavior
2. which local extra cleanup should remain bundled with DFE versus being split or documented separately

## Practical rule

- Keep DFE design and testing module-centric.
- Do not force this pass into HOT IR just for namespace symmetry.
- When discussing parity, separate:
  - upstream DFE proper
  - from the broader local DFE-plus-extra-cleanup bundle
