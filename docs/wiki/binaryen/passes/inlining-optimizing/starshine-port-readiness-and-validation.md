---
kind: concept
status: working
last_reviewed: 2026-05-12
sources:
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ../inlining/starshine-port-readiness-and-validation.md
---

# Starshine Port Readiness And Validation For `inlining-optimizing`

## Current status in one sentence

Starshine's `inlining-optimizing` is an active partial module pass with validation-clean latest fuzz evidence, but 15 normalized mismatches and an incomplete nested scheduler keep it unsigned.

## Latest evidence

```text
Artifact: .tmp/pass-fuzz-inlining-shadow-void-cycle-final
Pass: inlining-optimizing
Compared: 9975 / 10000
Normalized matches: 9960
Normalized mismatches: 15
Validation failures: 0
Generator failures: 0
Ignored Binaryen/tool command failures: 25
```

Command-failure breakdown:

- `22` `binaryen-rec-group-zero`;
- `1` `binaryen-bad-section-size`;
- `1` `binaryen-table-index-out-of-range`;
- `1` `binaryen-invalid-tag-index`.

Classification rule: these are ignored oracle/tool parse/canonicalization failures, not Starshine semantic failures.

## What is already validated locally

Focused tests validate the current subset:

- registry activation for both public names;
- direct tiny helper inlining/removal;
- parameter remapping;
- exported-helper survival;
- narrow direct `return_call` inlining;
- self-recursion skip;
- iterative wave behavior;
- unreachable private cycle cleanup/retention families;
- optimizing nested-cleanup trace marker.

## Active blockers

### `[INL]001` core blockers

- remaining exact-`unreachable` representative/retention mismatches;
- incomplete Binaryen heuristic model;
- incomplete callsite repair model;
- missing partial splitting;
- missing no-inline flags;
- incomplete module/name/annotation repair.

### `[INL]002` scheduler blockers

- optimizing mode currently approximates nested cleanup;
- no exact touched-function-filtered scheduler;
- no real prepended `precompute-propagate` equivalent;
- no proof that only Binaryen's touched functions run the default pipeline;
- no ordered late-tail artifact parity.

## Validation ladder

1. Keep focused Moon tests for each reduced mismatch before implementation changes.
2. Retire all saved mismatches from `.tmp/pass-fuzz-inlining-shadow-void-cycle-final` or document approved divergences.
3. Run direct `--pass inlining-optimizing` 10k compare with zero semantic mismatches.
4. Run direct `--pass inlining` separately so plain stop-point behavior is not hidden by cleanup.
5. Add scheduler tests for touched-only nested cleanup.
6. Replay `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination` neighborhood after direct parity.
7. Only then consider public preset placement.

## Acceptance criteria

Do not mark `[INL]001` complete until:

- core direct pass compare has zero semantic mismatches;
- validation failures are zero;
- remaining command failures are classified separately;
- no unimplemented Binaryen core family is silently accepted as parity.

Do not mark `[INL]002` complete until:

- the nested cleanup starts with the real `precompute-propagate` equivalent;
- the default function pipeline runs only on Binaryen's touched set;
- untouched functions are proven unchanged by the nested scheduler;
- focused trace/scheduler tests and direct compare evidence agree.

## Unresolved uncertainty

- The current exact-`unreachable` predictor is artifact-driven and may need refactoring after broader helper deletion and exact scheduler behavior land.
- The exact local representation for Binaryen no-inline flags is not yet settled.
- The best shared scheduler abstraction for DAE/INL/SGO remains open; avoid building three incompatible nested runners.
