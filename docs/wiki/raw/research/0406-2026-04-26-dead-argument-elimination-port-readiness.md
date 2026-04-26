---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-dead-argument-elimination-primary-sources.md
  - ../../binaryen/passes/dead-argument-elimination/index.md
  - ../../binaryen/passes/dead-argument-elimination/starshine-strategy.md
  - ../../binaryen/passes/dae-optimizing/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/env.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/wast/lower_to_lib.mbt
---

# `dead-argument-elimination` port-readiness bridge

## Question

The plain `dead-argument-elimination` folder had a source-backed overview, Binaryen strategy, implementation/test map, transformed-shape catalog, and Starshine status page, but it still made future implementers infer the first safe Starshine slice and validation ladder from several pages.

This note asks: what is the smallest honest Starshine path from today's boundary-only registry entry to a future plain-`dae` port, while preserving the exact split from `dae-optimizing`?

## Answer

Add a dedicated implementation-readiness page for plain `dead-argument-elimination` that treats the pass as a whole-module boundary rewrite, not as a local peephole.

The bridge should make six facts explicit:

1. Starshine currently knows only the descriptive `dead-argument-elimination` name as boundary-only; upstream `dae` is not a local alias today.
2. The first implementation slice should be a no-rewrite analyzer that proves the closed direct-call boundary and bailout surfaces before mutating signatures.
3. The first mutating slice should delete unused scalar parameters for private, direct-only callees and repair all direct callers while preserving removed operand effects.
4. Constant actuals, GC param/result refinement, dropped-result removal, and operand localization are follow-up slices, not accidental first-slice scope creep.
5. Plain DAE must not run the nested cleanup replay that belongs to `dae-optimizing`.
6. Validation must compare against Binaryen `--dae`, then separately check that the optimizing sibling still has the extra cleanup behavior only when that pass is requested.

## Current source evidence

The 2026-04-26 current-main source check found no teaching-relevant drift from the earlier `version_129` dossier.
The relevant upstream contract remains:

- shared owner: `src/passes/DeadArgumentElimination.cpp`;
- pass registration split in `src/passes/pass.cpp`;
- helper surfaces in `param-utils.*`, `lubs.h`, `return-utils.h`, and `type-updating.h`;
- representative plain-pass lit proof in `dae_tnh.wast`, `dae-gc.wast`, `dae-gc-refine-params.wast`, and `dae-gc-refine-return.wast`.

See [`../binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md`](../binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md).

## Local implementation surfaces

Current Starshine surfaces that a future port would reuse:

- [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt): boundary-only registry entry and request rejection for `dead-argument-elimination`.
- [`src/lib/types.mbt`](../../../../src/lib/types.mbt): instruction constructors for direct calls, `call_ref`, `return_call`, and `return_call_ref`.
- [`src/validate/env.mbt`](../../../../src/validate/env.mbt): function-type lookup by `TypeIdx` and `FuncIdx`.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt): call and tail-call typechecking rules that future DAE tests must continue satisfying after signature repair.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt): binary decoding for call-reference opcodes needed by negative/escape coverage.
- [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt): WAT lowering for future direct-call and call-reference fixtures.

The missing major local surface is a whole-module call-boundary summary and signature-rewrite owner file.
No existing HOT pass should be stretched into pretending it owns this module-level transform.

## Durable wiki updates made

- Added [`../../binaryen/passes/dead-argument-elimination/starshine-port-readiness-and-validation.md`](../../binaryen/passes/dead-argument-elimination/starshine-port-readiness-and-validation.md).
- Refreshed the plain DAE overview and Starshine strategy to link the readiness bridge.
- Updated the main wiki index, pass index, tracker, and log so future threads do not treat plain DAE's first-slice / validation-ladder gap as still open.

## Remaining implementation questions

- Whether Starshine should add exact upstream alias `dae` immediately when the pass is implemented, or add it earlier as boundary-only alias coverage.
- Whether the first mutating implementation should rewrite type-section entries in place or allocate replacement function types and remap users.
- How much of the future `dae-optimizing` implementation should share an owner file with plain DAE versus dispatch through a scheduling flag.
- Which fixture layer should carry early call-reference escape tests if text WAT support proves less convenient than direct library fixtures.
