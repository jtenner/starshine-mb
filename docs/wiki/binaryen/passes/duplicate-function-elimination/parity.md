---
kind: comparison
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../scripts/self-optimize-compare.ts
  - ../../../../../scripts/test/self-optimize-compare-command.ts
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./type-compaction-and-metadata.md
  - ./starshine-hot-ir-strategy.md
---

# `duplicate-function-elimination` Binaryen parity

## Durable conclusions

- Official Binaryen `version_129` DFE is a narrow module pass:
  - hash defined functions
  - exact-compare candidates
  - remove duplicates
  - rewrite function references
  - repeat according to optimize/shrink settings
- The current Starshine pass is **broader** than that official contract.
- The most important parity correction from the 2026-04-20 source refresh is:
  - duplicate simple-type compaction, wide type-index rewriting, name stripping, and related metadata cleanup are local extras, not official DFE proper.
- For the no-DWARF optimizer, Binaryen runs DFE twice at top level:
  - once in global pre-passes
  - once again in global post-passes
- For stronger optimize contexts, Binaryen also gives DFE a larger visible iteration budget than the current local one-round implementation.

## Current in-tree status

- The implementation lives in [`../../../../../src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt).
- The focused suite lives in [`../../../../../src/passes/duplicate_function_elimination_test.mbt`](../../../../../src/passes/duplicate_function_elimination_test.mbt).
- CLI coverage for explicit pass execution lives in [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt).
- Artifact replay tooling lives in [`../../../../../scripts/self-optimize-compare.ts`](../../../../../scripts/self-optimize-compare.ts) and [`../../../../../scripts/test/self-optimize-compare-command.ts`](../../../../../scripts/test/self-optimize-compare-command.ts).

## Reframed parity gap

The old parity story mixed two different questions together.

## 1. Core upstream DFE parity

This is the honest source-backed question:

- does Starshine match Binaryen's duplicate detection, survivor choice, function-reference rewriting, and option-dependent iteration behavior?

## 2. Local extra cleanup parity

This is a different question:

- should Starshine's current type compaction, name stripping, element canonicalization, and annotation-map rewrite behavior remain bundled with DFE, and if so how should those extra transforms compare to Binaryen output?

Those are not the same problem.

## What is clearly still open

- The local implementation is still a one-iteration module strategy today.
  - that is narrower than Binaryen's stronger optimize-level and shrink-level behavior
- The local no-DWARF preset does not yet model Binaryen's second late DFE slot in the full upstream schedule
- The local implementation still performs extra cleanup that upstream DFE proper does not

So future parity work must decide separately:

- how much upstream iteration/scheduler behavior to add
- and which local extra cleanup should remain coupled to this pass

## What is no longer okay to claim

After the 2026-04-20 source review, the docs should no longer claim that official Binaryen DFE parity inherently requires:

- duplicate function-type compaction
- generic type-index rewrite parity
- name-section stripping
- element-kind canonicalization
- dedicated annotation-section normalization

Those may still matter for local output comparison, but they are not the official DFE algorithm.

## 2026-04-11 health rerun

The saved focused fuzz evidence remains useful and was not invalidated by the source refresh.

- `bun scripts/pass-fuzz-compare.ts --pass duplicate-function-elimination --count 200 --seed 0x5eed --max-failures 30 --out-dir /tmp/health-dfe-200-2026-04-11-smoke`
  - `199 / 199` compared
  - `199` normalized matches
  - `0` mismatches
  - `1` command failure (`binaryen-rec-group-zero`)
- `bun scripts/pass-fuzz-compare.ts --pass duplicate-function-elimination --generator gen-valid --count 200 --seed 0x5eed --out-dir /tmp/health-dfe-200-genvalid-2026-04-11-smoke`
  - `200 / 200` compared
  - `200` normalized matches
  - `0` mismatches

Those lanes suggest the core merge-and-rewrite behavior is in decent shape on the compared corpus.
But they do not answer the newly-clarified questions about:

- upstream multi-round scheduling
- or the broader local-extra cleanup surface

## Practical rule

- Keep DFE parity work module-wide and source-scoped.
- Do not treat “current local DFE bundle” as synonymous with “official Binaryen DFE contract.”
- When a diff appears, classify it first:
  - core DFE behavior
  - or local extra cleanup
- Treat older direct-artifact size and raw-output notes as historical until rerun under this clearer upstream-vs-local split.

## Sources

- [`../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md`](../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md)
- [`../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`](../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md)
- [`../../../../../src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt)
- [`../../../../../src/passes/duplicate_function_elimination_test.mbt`](../../../../../src/passes/duplicate_function_elimination_test.mbt)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
