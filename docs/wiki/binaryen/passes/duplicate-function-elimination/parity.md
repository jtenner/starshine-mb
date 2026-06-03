---
kind: comparison
status: working
last_reviewed: 2026-06-03
sources:
  - ../../../raw/research/0524-2026-05-06-duplicate-function-elimination-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-13-duplicate-function-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-duplicate-function-elimination-validation-primary-sources.md
  - ../../../raw/research/0425-2026-04-27-duplicate-function-elimination-validation-bridge.md
  - ../../../raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md
  - ../../../raw/research/0242-2026-04-22-duplicate-function-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../../src/passes/duplicate_function_elimination_wbtest.mbt
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
  - ./scheduler-validation-and-parity.md
  - ./starshine-strategy.md
---

# `duplicate-function-elimination` Binaryen parity

For the actionable validation ladder and scheduler decision points, see [`scheduler-validation-and-parity.md`](./scheduler-validation-and-parity.md). This page remains the high-level parity framing; the scheduler bridge is the checklist for future preset work.

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
- The 2026-04-27 validation bridge records this as the remaining preset/scheduler signoff gap rather than a hidden failure of the explicit pass surface.
- The 2026-05-13 current-main recheck kept that framing unchanged.
- The 2026-05-06 direct revalidation reran the refreshed 10000-case compare lane and found no semantic mismatches.
- The 2026-06-03 O4z audit refreshed the direct lane after switching the Starshine hash prefilter from sparse instruction samples to whole-body instruction hashes; the final `10000`-requested keep-going lane compared `9975 / 10000` cases with `9975` normalized matches, `0` mismatches, and `25` Binaryen/tool command failures.

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

After the 2026-05-13 current-main recheck, the docs should no longer claim that official Binaryen DFE parity inherently requires:

- duplicate function-type compaction
- generic type-index rewrite parity
- name-section stripping
- element-kind canonicalization
- dedicated annotation-section normalization

Those may still matter for local output comparison, but they are not the official DFE algorithm.

## 2026-06-03 O4z audit refresh

The O4z audit improved the local explicit-pass surface without changing the remaining scheduler/iteration gap:

- Starshine now hashes the full function body before exact comparison. This is a performance and shape-fidelity improvement relative to the older sparse sample, not a semantic relaxation: exact equality still decides merging.
- New tests cover implemented but previously under-protected Binaryen rewrite surfaces: `return_call`, table initializer `ref.func`, and global initializer `ref.func`.
- Direct compare after the change: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-function-elimination --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dfe-audit-after-10000` reported `9975 / 10000` compared, `9975` normalized matches, `0` mismatches, and `25` Binaryen/tool command failures (`22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`).
- Performance after the change on `.tmp/dfe-collision-stress.wasm`: Starshine pass-local `0.812 ms`, Binaryen pass-local `0.957 ms`, canonical wasm equal, no raw skip. The same fixture before the change measured Starshine pass-local `20.315 ms` versus Binaryen `0.717 ms`.
- Performance after the change on `.tmp/dfe-duplicate-pairs-stress.wasm`: Starshine pass-local `3.022 ms`, Binaryen pass-local `1.672 ms`; this is within the repo target (`3.022 <= 2 * 1.672`) while still performing real duplicate removal.

## 2026-05-06 direct revalidation

The AUD002 refresh lane remains useful historical evidence for `duplicate-function-elimination`:

- `moon info`, `moon fmt`, and `moon test` passed.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-function-elimination --out-dir .tmp/pass-fuzz-duplicate-function-elimination`
  - `6759 / 10000` compared cases
  - `6759` normalized matches
  - `0` mismatches
  - `20` command failures, all in the already-known Binaryen empty-recursion-group parser/canonicalization family

This closes the post-fuzzer-change direct-pass revalidation item for DFE. The scheduler page remains the owner for later Binaryen two-slot / multi-iteration preset proof.

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

- [`../../../raw/research/0524-2026-05-06-duplicate-function-elimination-direct-revalidation.md`](../../../raw/research/0524-2026-05-06-duplicate-function-elimination-direct-revalidation.md)
- [`../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md`](../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md)
- [`../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`](../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md)
- [`../../../../../src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt)
- [`../../../../../src/passes/duplicate_function_elimination_test.mbt`](../../../../../src/passes/duplicate_function_elimination_test.mbt)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
