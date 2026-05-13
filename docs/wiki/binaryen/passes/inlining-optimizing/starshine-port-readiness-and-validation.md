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

Starshine's `inlining-optimizing` is an active partial module pass whose standard seed-`0x5eed` and broadened seed-`0x1eed` direct lanes are green over compared cases; remaining ignored failures are Binaryen/tool parse failures, not Starshine semantic failures.

## Latest evidence

Standard direct lane now green:

```text
Artifact: .tmp/pass-fuzz-inlining-seed-0x5eed-after-four-func-frontier
Pass: inlining-optimizing
Seed: 0x5eed
Compared: 9975 / 10000
Normalized matches: 9975
Normalized mismatches: 0
Validation failures: 0
Generator failures: 0
Ignored Binaryen/tool command failures: 25
```

Seed-`0x5eed` command-failure breakdown:

- `22` `binaryen-rec-group-zero`;
- `1` `binaryen-bad-section-size`;
- `1` `binaryen-table-index-out-of-range`;
- `1` `binaryen-invalid-tag-index`.

Broadened closure lane is green:

```text
Artifact: .tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2
Pass: inlining-optimizing
Seed: 0x1eed
Compared: 9978 / 10000
Normalized matches: 9978
Normalized mismatches: 0
Validation failures: 0
Generator failures: 0
Ignored Binaryen/tool command failures: 22
```

Seed-`0x1eed` command-failure breakdown:

- `22` ignored Binaryen/tool `binaryen-rec-group-zero` parse failures;
- `0` Starshine command failures; `case-008100-gen-valid` replays green in `.tmp/pass-fuzz-inlining-seed-0x1eed-replay-case008100-narrow-hotunsafe`.

Classification rule: Binaryen parse/canonicalization failures are ignored oracle/tool failures, not Starshine semantic failures. The former Starshine command failure and broadened normalized mismatch set are fixed.

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
- no-inlining unreachable value-block pruning and predicted exact-helper padding;
- narrow hot-unsafe polymorphic self-call suffix detector coverage;
- optimizing nested-cleanup trace marker.

## Active blockers

### Deferred direct-inliner breadth after accepted `[INL]001`

- `[INL]003` heuristic classes, action filtering, and size/iteration policy;
- `[INL]004` `no-inline*` flags and clone survival;
- `[INL]005` Pattern A / Pattern B partial splitting;
- `[INL]006` nested tail-call, multi-result, and name/annotation repair;
- `[INL]007` separate plain `--pass inlining` signoff.

### `[INL]002` scheduler blockers

- optimizing mode currently approximates nested cleanup;
- the former seed-`0x1eed` `case-008100-gen-valid` command failure is fixed by a narrow hot-unsafe helper guard;
- no exact touched-function-filtered scheduler;
- no real prepended `precompute-propagate` equivalent;
- no proof that only Binaryen's touched functions run the default pipeline;
- no ordered late-tail artifact parity.

## Validation ladder

1. Keep focused Moon tests for each reduced mismatch before implementation changes.
2. Retire or classify the broadened seed-`0x1eed` mismatches in `.tmp/pass-fuzz-inlining-seed-0x1eed-after-four-func-frontier2`, plus any still-useful older saved mismatch dirs.
3. Run direct `--pass inlining-optimizing` 10k compare with zero semantic mismatches on the standard lane and at least one broadened seed lane.
4. Run direct `--pass inlining` separately so plain stop-point behavior is not hidden by cleanup.
5. Add scheduler tests for touched-only nested cleanup.
6. Replay `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination` neighborhood after direct parity.
7. Only then consider public preset placement.

## Acceptance criteria

Treat `[INL]001` as complete only for the currently implemented direct-call surface already proven by the green seed lanes. New direct-inliner work should land under `[INL]003`-`[INL]007`, not by reopening the accepted direct slice without a new semantic mismatch.

Do not mark `[INL]002` complete until:

- the nested cleanup starts with the real `precompute-propagate` equivalent;
- the default function pipeline runs only on Binaryen's touched set;
- untouched functions are proven unchanged by the nested scheduler;
- focused trace/scheduler tests and direct compare evidence agree.

## Unresolved uncertainty

- The current exact-`unreachable` predictor is artifact-driven and may need refactoring after broader helper deletion and exact scheduler behavior land.
- The exact local representation for Binaryen no-inline flags is not yet settled.
- The best shared scheduler abstraction for DAE/INL/SGO remains open; avoid building three incompatible nested runners.
