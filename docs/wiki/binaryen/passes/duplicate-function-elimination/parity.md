---
kind: comparison
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md
related:
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../../src/cmd/cmd_test.mbt
  - ../../../../../scripts/self-optimize-compare.ts
  - ../../../../../scripts/test/self-optimize-compare-command.ts
---

# `duplicate-function-elimination` Binaryen Parity

## Durable Conclusions

- Binaryen `duplicate-function-elimination` is a module pass, not a lifted-function hot pass.
- The direct pass is single-pass: it merges currently visible duplicates, rewrites references once, and stops.
- Defined functions are the only merge candidates. Imports are not candidates.
- Parity depends on a three-part equality contract:
  - canonical simple function type index
  - normalized locals plus body
  - function annotations
- Matching bodies alone are not enough. Annotation differences must block merges.
- Binaryen-style parity also needs duplicate simple function-type compaction after merge selection settles.

## Rewrite Contract

- After survivor selection, every affected `FuncIdx` user must be rewritten:
  - `call`
  - `return_call`
  - `ref.func`
  - exports
  - `start`
  - element function lists and function-bearing element expressions
  - global, table, and data initializer expressions that can contain function references
- Name and annotation metadata must also be rewritten:
  - keep the canonical survivor metadata
  - preserve sorted index order
  - drop duplicate rewritten entries

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt).
- The focused suite lives in [`../../../../../src/passes/duplicate_function_elimination_test.mbt`](../../../../../src/passes/duplicate_function_elimination_test.mbt).
- CLI coverage for explicit pass execution lives in [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt).
- Artifact replay tooling lives in [`../../../../../scripts/self-optimize-compare.ts`](../../../../../scripts/self-optimize-compare.ts) and [`../../../../../scripts/test/self-optimize-compare-command.ts`](../../../../../scripts/test/self-optimize-compare-command.ts).
- The raw element-section mismatch is closed: Starshine now re-canonicalizes compactable `funcref` element expressions back to compact function-index form.

## Active Gap

- Direct debug-artifact replay is still not normalized-WAT-equal to Binaryen.
- The largest raw size delta is explained by Binaryen dropping the `name` section on direct DFE output.
- The remaining open drift is not element shape anymore:
  - Starshine compacts simple function types more aggressively
  - `code` bytes still differ after direct DFE
- Runtime parity is also still open on the MoonBit debug artifact.

## Practical Rule

- Keep DFE parity work module-wide and metadata-aware.
- Do not treat "same printed body" as enough evidence for a safe merge.
- Track exact direct-pass artifact parity separately from the already-closed element rewrite gap.

## Sources

- Archived research doc: [`../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md`](../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md)
- Implementation: [`../../../../../src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt)
- Focused tests: [`../../../../../src/passes/duplicate_function_elimination_test.mbt`](../../../../../src/passes/duplicate_function_elimination_test.mbt)
