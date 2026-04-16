---
kind: comparison
status: working
last_reviewed: 2026-04-11
sources:
  - ../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
related:
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../scripts/self-optimize-compare.ts
  - ../../../../../scripts/test/self-optimize-compare-command.ts
---

# `duplicate-function-elimination` Binaryen Parity

## Durable Conclusions

- Binaryen `duplicate-function-elimination` is a module pass, not a lifted-function hot pass.
- The direct explicit pass at default options is one visible merge round, but Binaryen can iterate internally at higher optimize or shrink levels.
- For the no-DWARF `-O` / `-Os` pipeline, each DFE slot should be treated as an option-dependent iterative module pass, not a hardcoded single round.
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
- CLI coverage for explicit pass execution lives in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).
- Artifact replay tooling lives in [`../../../../../scripts/self-optimize-compare.ts`](../../../../../scripts/self-optimize-compare.ts) and [`../../../../../scripts/test/self-optimize-compare-command.ts`](../../../../../scripts/test/self-optimize-compare-command.ts).
- The raw element-section mismatch is closed: Starshine now re-canonicalizes compactable `funcref` element expressions back to compact function-index form.

## Active Gap

- Direct debug-artifact replay is still not normalized-WAT-equal to Binaryen.
- The current in-tree Starshine pass is still a one-iteration module strategy, so future no-DWARF pipeline parity work must decide how to model Binaryen's larger option-dependent iteration budget.
- The largest raw size delta is explained by Binaryen dropping the `name` section on direct DFE output.
- The remaining open drift is not element shape anymore:
  - Starshine compacts simple function types more aggressively
  - `code` bytes still differ after direct DFE
- Runtime parity is also still open on the MoonBit debug artifact.

## 2026-04-11 Health Rerun

- `bun scripts/pass-fuzz-compare.ts --pass duplicate-function-elimination --count 200 --seed 0x5eed --max-failures 30 --out-dir /tmp/health-dfe-200-2026-04-11-smoke`:
  - `199 / 199` compared, `199` normalized matches, `0` mismatches, `1` command failure (`binaryen-rec-group-zero`)
- `bun scripts/pass-fuzz-compare.ts --pass duplicate-function-elimination --generator gen-valid --count 200 --seed 0x5eed --out-dir /tmp/health-dfe-200-genvalid-2026-04-11-smoke`:
  - `200 / 200` compared, `200` normalized matches, `0` mismatches

## Practical Rule

- Keep DFE parity work module-wide and metadata-aware.
- Do not treat "same printed body" as enough evidence for a safe merge.
- Track exact direct-pass artifact parity separately from the already-closed element rewrite gap.

## Sources

- Archived research doc: [`../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md`](../../../raw/research/0067-2026-03-24-duplicate-function-elimination.md)
- Follow-up health rerun: [`../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`](../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md)
- Implementation: [`../../../../../src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt)
- Focused tests: [`../../../../../src/passes/duplicate_function_elimination_test.mbt`](../../../../../src/passes/duplicate_function_elimination_test.mbt)
