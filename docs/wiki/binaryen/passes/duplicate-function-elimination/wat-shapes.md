---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
related:
  - ./index.md
  - ./parity.md
  - ./type-compaction-and-metadata.md
---

# `duplicate-function-elimination` WAT And Module Shapes

## Main Idea

- This pass does not optimize one lifted control-flow shape.
- It optimizes whole-module duplication patterns: two or more defined functions end up equivalent after lowering, type canonicalization, and annotation comparison.

## Candidate Shapes

- Duplicate defined functions with the same effective function type, locals, and body.
- Duplicate functions hidden behind duplicate simple function type indices.
- Duplicate functions that only become visible after earlier callee merges or after a second explicit DFE run.
- Modules where `ref.func`, `call`, `return_call`, `start`, exports, globals, data initializers, or element segments still point at the soon-to-be-removed function.

## Current Test-Shaped Examples

- Direct duplicate-call rewrite shapes:
  two identical defined functions where one is removed and all callsites retarget to the survivor.
- Transitive unlock shapes:
  a first merge exposes a second pair of duplicates, but Starshine currently stops after one explicit iteration.
- Duplicate simple-type compaction shapes:
  equal function bodies survive under different simple type indices, then surviving type users are rewritten after merge.
- Metadata-sensitive non-merge shapes:
  identical bodies with different function annotations must stay distinct.
- Element canonicalization shapes:
  compactable `ref.func` element expressions should collapse back to compact `funcs` element form even when no duplicate function is removed.

## Non-Candidate Shapes

- Imports are never duplicate-function candidates.
- Complex type sections with rec groups, supertypes, `describes`, or `descriptor` metadata stay outside the current simple-type compaction path.
- Annotation differences are intentional blockers, not incidental misses.

## Practical Rule

- For DFE, "WAT shapes" really means "module layouts that create duplicate equivalence classes and section rewrites."
- When adding tests, prefer fixtures that show both the duplicate function pair and at least one rewritten user of the removed `FuncIdx`.
