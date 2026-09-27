---
kind: workflow
status: supported
last_reviewed: 2026-09-27
sources:
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ../inlining/fuzzing.md
---

# `inline-main` fuzzing

## September 27 performance-campaign renewal

The [shared final campaign](../../../tooling/tracing-playbook.md#september-27-2026-precompute-cleanup-and-pass-allocation-campaign)
uses native CLI `5d009c4396b65d613acdc187e443f6c2cee843c7bfbc48ee726ba633de2aac54`,
verified Binaryen 133, seed `0x5eed`, `--jobs auto --max-subprocesses 8` and 10,000 cases
per lane. It supersedes earlier current-baseline wording; historical v131/v132
results retain their original scope. The shared report owns exact profiles,
normalizers, cache use, runtime limits, size deltas and baseline replays.

| Lane | Canonical / cleanup matches | Residuals | Canonically larger | Star/original matches / blocked |
| --- | ---: | ---: | ---: | ---: |
| `inline-main` | 10,000 / 0 | 0 | 0 | 10,000 / 0 |

All listed lanes report zero validation, generator, property, command and observed
Starshine/original semantic failures. Runtime-blocked cases remain unverified;
shape/size classifications and any scoped exceptions are agent judgments in
the shared report, not conclusions implied by validation or normalization.

The generic aggregate is chiefly protocol/no-op coverage. A separate 512-case
named-wrapper campaign changes every main body, retains every named helper
(with existing cleanup allowed), and matches baseline output bytes. It passes
1,920 original/Starshine/v133 call comparisons plus 640 original/Starshine checks
with fresh instances per case. Verified v133 rejects all 128 tail-call fixtures
with an invalid branch-target error; those are separate Binaryen/tool failures,
without a three-way runtime result. Numeric locals and ordinary/tail/block/if
placements are covered; this does not replace the broader exception/reference
matrix below.

Local reports: `.tmp/pass-perf-campaign-20260927/final-fuzz-inline-main/result.json`.

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## Admission

`inline-main` is an active module pass and admitted compare-pass name.

Generic random corpora are usually no-ops because meaningful transformation requires all of:

- a defined function named exactly `main`;
- a defined function named exactly `__original_main`;
- exactly one direct matching `call` or `return_call` inside `main`.

Therefore generic normalized matches prove protocol compatibility only.

## Required focused matrix

A meaningful fixture or generated profile must include:

- ordinary direct `call`;
- direct `return_call`;
- matching tail call nested inside `try_table`;
- nested placement in block/if/loop structures;
- `__original_main` containing nested direct/indirect/ref tail calls;
- scalar and multivalue results;
- nullable/nonnullable copied locals;
- missing/imported endpoints;
- zero and multiple matching calls;
- unrelated direct calls that remain unchanged;
- helper retention after success.

The current focused suite covers the chooser, ordinary/tail/EH-tail rewrite, no-op, and retention families through the shared `120/120` inlining tests.

## Generated-lane acceptance

Before a generated lane can count as closeout evidence, its manifest must record:

- exact function-name creation;
- selected call form and nesting shape;
- whether the pass changed `main`;
- whether `__original_main` remained declared;
- validation of both Starshine and Binaryen outputs.

Until then, direct focused tests plus the shared plain/optimizing `10000/10000` official-v131 closeouts are the durable evidence.
