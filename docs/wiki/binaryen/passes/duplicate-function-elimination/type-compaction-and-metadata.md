---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
related:
  - ./index.md
  - ./parity.md
---

# `duplicate-function-elimination` Type Compaction And Metadata

## Why This Is Its Own Topic

- DFE parity is not only about merging duplicate functions.
- The pass also changes serialization-facing state:
  - simple function type indices
  - name metadata
  - function-annotation maps
  - compactable function-bearing element forms

## Simple-Type Compaction Rule

- The current Starshine compaction path is intentionally narrow.
- It only runs for simple function types:
  - single-rec entries only
  - plain function comp types only
  - no rec groups
  - no supertypes
  - no `describes` metadata
  - no `descriptor` metadata
- After merge selection settles, surviving type users are rewritten to canonical simple type indices.

## Current Rewrite Surfaces

- Function annotation section:
  keep canonical survivor entries, rewrite surviving function indices, and drop duplicate rewritten entries.
- Type users in code and signatures:
  rewrite block-type and typed value carriers that still point at duplicate simple type indices.
- Element segments:
  canonicalize compactable `ref.func` expression forms back to compact `funcs` element kinds.
- Name section:
  current Starshine DFE strips the `name` section as part of direct pass output.

## Why This Matters For Parity

- Two implementations can agree on which functions are duplicates and still disagree on final raw output because of:
  - different type-compaction policy
  - different name handling
  - different annotation-map rewrite policy
  - different element-kind canonicalization
- The current direct artifact gap is already narrower than earlier research:
  element-shape drift is closed, while type and code drift remain open.

## Practical Rule

- Keep metadata and type-compaction regressions beside the main pass tests.
- Do not classify raw output drift as "body mismatch" until type and metadata rewrite surfaces are ruled out first.
