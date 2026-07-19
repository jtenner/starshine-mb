---
kind: concept
status: supported
last_reviewed: 2026-07-19
sources:
  - ./index.md
  - ./starshine-strategy.md
  - ../inlining/starshine-port-readiness-and-validation.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
related:
  - ./fuzzing.md
  - ./implementation-structure-and-tests.md
---

# `inlining-optimizing`: readiness and validation

## Verdict

The represented Binaryen v131 direct engine and touched-function optimizing suffix are implemented and signed off. This page defines continuing validation and reopening criteria.

## Required checks

1. Direct behavior remains green with plain `inlining`.
2. `precompute-propagate` remains the first nested slot.
3. The default function pipeline order remains exact for current options.
4. Cleanup remains touched-only.
5. Imports do not shift touched indices.
6. Large modules and surviving tail calls do not trigger broad bypasses.
7. Nested invalid candidates fail closed.
8. Plain mode does not run the suffix.

## Current evidence

- focused inlining tests: `120/120`;
- white-box tests: `14/14`;
- full `moon test`: `9452/9452`;
- official v131 aggregate profile `inlining-optimizing-all`:

```text
.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000
10000/10000 compared
10000 normalized matches
0 mismatches
0 validation/property/generator/command failures
```

The plain sibling independently reports the same result in `.tmp/pass-fuzz-inlining-v131-closeout-10000`.

The pass-local helper-chain timing matrix remains accepted at or below Binaryen across its documented sizes; see [`fuzzing.md`](./fuzzing.md).

## Shared scheduler follow-up

`[O4Z-NESTED]001` may replace the hand-owned expansion with a shared DAE/inlining/SGO API. That work must preserve this page's exact-order, touched-only, validation, and performance evidence. It is infrastructure work, not an admission that current inlining behavior is partial.

## Reopening criteria

Reopen for:

- a minimized direct or nested semantic mismatch against explicit official v131;
- a validation failure;
- a touched-filter leak into unrelated functions;
- a nested-order regression;
- a source-backed missing v131 family;
- a size-losing divergence without a measured Starshine benefit;
- a repeated pass-local timing regression above Binaryen.

Do not reopen for branch-hint/source-map/debug-name substrate limitations or cosmetic raw output drift alone.
