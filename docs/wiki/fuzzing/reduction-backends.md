---
kind: tooling-note
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/fuzzing/2026-06-04-reduction-backends-source-refresh.md
  - ../../../scripts/lib/fuzz-reducers.ts
  - ../../../scripts/test/fuzz-reducers.ts
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/test/pass-fuzz-compare-command.ts
  - ../../../src/cmd/fuzz_harness.mbt
  - ../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../../src/fuzz/invalid_repro.mbt
  - ../../../src/fuzz/invalid_repro_wbtest.mbt
  - ../../../agent-todo.md
related:
  - ./interestingness-hash-schema.md
  - ./recipe-schema.md
  - ./generator-coverage-ledger.md
  - ../tooling/pass-fuzz-compare.md
  - ../validate/diagnostics-and-invalid-repro.md
  - ../validate/fuzz-hardening.md
---

# Fuzz Reduction Backends

## Overview

Reduction is the step that turns a large failing fuzz artifact into a smaller artifact that still reproduces the same interesting condition. In Starshine, the reducer is intentionally boring: it repeatedly deletes chunks and asks a caller-supplied predicate whether the candidate still reproduces. If the predicate says yes, the smaller candidate becomes the new baseline; if no deletion keeps the predicate, the original artifact is preserved.

That split is the core invariant. Reducers do **not** validate wasm, decide whether a mismatch is semantic, classify diagnostics, or choose pass-oracle policy. The caller owns those checks. The 2026-06-04 source refresh in [`../raw/fuzzing/2026-06-04-reduction-backends-source-refresh.md`](../raw/fuzzing/2026-06-04-reduction-backends-source-refresh.md) ties this contract to delta debugging, C-Reduce-style interestingness tests, Binaryen `wasm-reduce` orientation, and the current Starshine implementation.

Use this page when reading or changing:

- script-side reducers in [`scripts/lib/fuzz-reducers.ts`](../../../scripts/lib/fuzz-reducers.ts);
- compare-pass mismatch artifacts in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts);
- Moon command-harness reducers in [`src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt);
- invalid-fuzz repro shrink metadata in [`src/fuzz/invalid_repro.mbt`](../../../src/fuzz/invalid_repro.mbt).

## Beginner Model

A reducer needs three things:

1. **An artifact** - bytes, text, lines, or parsed WAST module fields.
2. **A predicate** - a deterministic yes/no check such as “this candidate still produces the same validation-family failure” or “Starshine and Binaryen still differ after normalization.”
3. **A deletion unit** - the chunks the reducer is allowed to remove.

Example byte-level flow:

```text
input bytes:        noise TRIGGER tail
predicate:          candidate still contains TRIGGER and still mismatches
first kept result:  TRIGGER tail
next kept result:   TRIGGER
final artifact:     TRIGGER
```

The final artifact is only useful because the predicate was useful. A bad predicate can preserve the wrong condition, so reducers must keep predicate facts explicit in logs and metadata.

## Backend Matrix

| Backend | Owner | Deletion unit | Current users | Best fit | Main caveat |
| --- | --- | --- | --- | --- | --- |
| Module-field deletion | [`reduceModuleFieldsByDeletionWithReport(...)`](../../../scripts/lib/fuzz-reducers.ts), [`reduce_fuzz_module_fields_by_deletion(...)`](../../../src/cmd/fuzz_harness.mbt) | Contiguous WAST `ModuleField` ranges | Invalid-fuzz inline/spec-seed shrink paths; future WAST/module reducers | WAST modules where deleting whole declarations/functions is safer than token deletion | Needs parseable WAST and a predicate that can rebuild the assertion/module wrapper. |
| Byte-slice deletion | [`reduceBinaryByByteSlicesWithReport(...)`](../../../scripts/lib/fuzz-reducers.ts), [`reduce_fuzz_bytes_by_slice_deletion(...)`](../../../src/cmd/fuzz_harness.mbt) | Contiguous byte ranges | Fresh `gen-valid` compare-pass mismatch reductions; command/invalid repro bytes | Opaque wasm or binary blobs where structural parsing is not required | Can produce invalid wasm; caller must decide whether invalid candidates are acceptable for that predicate. |
| Text-token deletion | [`reduceTextByTokenDeletionWithReport(...)`](../../../scripts/lib/fuzz-reducers.ts), [`reduce_fuzz_text_tokens_by_deletion(...)`](../../../src/cmd/fuzz_harness.mbt) | Non-whitespace WAT/WAST-like tokens | Invalid-fuzz inline/spec-seed fallback after module-field reduction | Text artifacts where line boundaries are too coarse | Rejoins with single spaces and may destroy layout-sensitive diagnostics. |
| Text-line deletion | [`reduceTextByLineDeletionWithReport(...)`](../../../scripts/lib/fuzz-reducers.ts) | Contiguous lines | Script-side log, manifest, and text-artifact reducers | Logs/manifests or large script-like artifacts | Too coarse for dense WAT where the interesting part is within one line. |
| Pass-list deletion | [`minimize_fuzz_passes(...)`](../../../src/cmd/fuzz_harness.mbt) | Pass-name ranges | Command-harness pass-profile minimization | Finding a smaller ordered pass list that still reproduces | Does not prove individual pass blame; it only preserves the pass-list predicate. |

All backends are greedy chunk-deletion reducers. They are intentionally not a full Binaryen `wasm-reduce` replacement: Starshine does not yet interleave reducer passes, rewrite wasm instructions structurally, or guarantee every intermediate candidate remains valid wasm.

## Artifact And Log Contract

Reduction evidence should travel with the failure, but the original input remains the canonical replay artifact.

Script-side report variants return:

```text
result
originalSize
finalSize
predicateEvaluations
steps[] = { kind, start, length, beforeSize, afterSize }
```

The shared script log formatter writes the same facts as stable text:

```text
status=mismatch
original_size=16
final_size=4
predicate_evaluations=7
reduced_wasm_path=reduced-input.wasm
step=delete-byte-slice|start=4|len=8|before=16|after=8
```

[`parseReductionReportLog(...)`](../../../scripts/lib/fuzz-reducers.ts) roundtrips that schema, including custom artifact-path keys such as `reduced_wasm_path`. Tests in [`scripts/test/fuzz-reducers.ts`](../../../scripts/test/fuzz-reducers.ts) cover the formatter/parser pair and the byte/token/line/module report variants.

Moon-side invalid-fuzz reports use the same conceptual fields with Moon names: `reduction_original_size`, `reduction_final_size`, `reduction_predicate_evaluations`, `reduction_step=kind|start|len|before|after`, and `reduction_log=reduction.txt`. [`persist_invalid_fuzz_failure_report(...)`](../../../src/fuzz/invalid_repro.mbt) writes `reduction.txt` beside the original and reduced artifacts.

## Current Flows

### Compare-pass mismatches

For fresh `gen-valid` normalized mismatches, [`runPassFuzzCompare(...)`](../../../scripts/lib/pass-fuzz-compare-task.ts) first records the ordinary failure, then tries byte-slice reduction. If reduction succeeds, the failure directory gains:

- `input.wasm` - original replay input;
- `reduced-input.wasm` - minimized debugging aid;
- `reduction.txt` - shrink log;
- `failure-metadata.json.reduction` - machine-readable original/final sizes, predicate-evaluation count, deletion steps, reduced wasm path, and log path.

The compare-pass workflow page explains the surrounding oracle ladder and replay contract: [`../tooling/pass-fuzz-compare.md`](../tooling/pass-fuzz-compare.md). The important reduction-specific rule is that `input.wasm` stays the replay default; `reduced-input.wasm` is opt-in triage evidence.

### Invalid-fuzz repros

`shrink_invalid_fuzz_failure_report(...)` in [`src/fuzz/invalid_repro.mbt`](../../../src/fuzz/invalid_repro.mbt) preserves the original invalid artifact and attaches smaller artifacts when the replay predicate still matches the original stage/family/property. For inline text and spec-seed WAST, it tries parser-aware module-field deletion before token deletion; if neither works, it falls back to strategy-minimal repro artifacts. This keeps structural WAST reductions ahead of arbitrary lexical shrinkage while preserving a single metadata/log shape.

The diagnostics and invalid-repro page owns the surrounding stable-id and diagnostic-family contract: [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md).

### Command-harness reductions

[`src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt) exposes the shared Moon deletion loop and metadata structs so command-level fuzz reports can minimize pass lists, byte artifacts, text tokens, and parsed module fields without duplicating reducer logic. This is the path that lets pass-list minimization and future command-harness artifact reducers share deletion-step accounting.

## Correctness Constraints

- **Predicate determinism is required.** A flaky predicate can keep or reject candidates for the wrong reason. If the predicate depends on files or environment variables, make those inputs explicit and stable.
- **Original artifacts stay immutable.** A reduced artifact is a debugging/corpus aid, not a replacement for the first observed failure.
- **Validation belongs to the caller.** Byte reducers may generate malformed wasm; token reducers may generate malformed WAST; module-field reducers may break references. That is acceptable only when the predicate deliberately handles those outcomes.
- **Do not confuse reduction with classification.** A smaller mismatch still needs pass-owner semantic classification; a smaller invalid input still needs the expected stage/family policy.
- **Prefer structural units when available.** Use WAST module-field deletion before token deletion when the artifact is parseable and the predicate can rewrap it.
- **Preserve shrink evidence.** Keep original/final sizes, predicate-evaluation counts, and ordered steps in both metadata and logs so later tooling can audit whether a reduction actually happened.

## Maintenance Checklist

When adding a reducer or wiring a new failure path:

1. Reuse the existing deletion loop unless the new reducer needs a fundamentally different algorithm.
2. Add a `...WithReport` variant before adding a log-writing caller.
3. Choose a stable `step.kind` such as `delete-byte-slice`, `delete-text-token-range`, `delete-text-line-range`, or `delete-module-field-range`.
4. Keep the compatibility wrapper if older callers need only the reduced artifact.
5. Persist original and reduced artifacts side by side; do not mutate the original path.
6. Update parser/formatter tests for any new log key or step shape.
7. Cross-link the caller's workflow page, generator ledger row, or diagnostics page so future agents can find the reduction evidence.

## Sources

- Source refresh: [`../raw/fuzzing/2026-06-04-reduction-backends-source-refresh.md`](../raw/fuzzing/2026-06-04-reduction-backends-source-refresh.md)
- Script reducers and tests: [`../../../scripts/lib/fuzz-reducers.ts`](../../../scripts/lib/fuzz-reducers.ts), [`../../../scripts/test/fuzz-reducers.ts`](../../../scripts/test/fuzz-reducers.ts)
- Compare-pass reducer integration: [`../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts), [`../../../scripts/test/pass-fuzz-compare-command.ts`](../../../scripts/test/pass-fuzz-compare-command.ts), [`../tooling/pass-fuzz-compare.md`](../tooling/pass-fuzz-compare.md)
- Moon reducers and invalid-fuzz repros: [`../../../src/cmd/fuzz_harness.mbt`](../../../src/cmd/fuzz_harness.mbt), [`../../../src/cmd/fuzz_harness_wbtest.mbt`](../../../src/cmd/fuzz_harness_wbtest.mbt), [`../../../src/fuzz/invalid_repro.mbt`](../../../src/fuzz/invalid_repro.mbt), [`../../../src/fuzz/invalid_repro_wbtest.mbt`](../../../src/fuzz/invalid_repro_wbtest.mbt)
- Related workflow docs: [`interestingness-hash-schema.md`](interestingness-hash-schema.md), [`generator-coverage-ledger.md`](generator-coverage-ledger.md), [`../validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md), [`../validate/fuzz-hardening.md`](../validate/fuzz-hardening.md)
