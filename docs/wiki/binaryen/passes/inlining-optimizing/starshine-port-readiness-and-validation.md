---
kind: concept
status: working
last_reviewed: 2026-05-14
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
- the `[INL]003` heuristic subsets for repeated two-parameter binary, three-parameter `select`, and parameter-passthrough memory/table-store wrappers, including the latest `memory.copy` memory-copy sibling;
- unreachable private cycle cleanup/retention families;
- no-inlining unreachable value-block pruning and predicted exact-helper padding;
- narrow hot-unsafe polymorphic self-call suffix detector coverage;
- optimizing nested-cleanup trace marker.

## Active blockers

### Deferred direct-inliner breadth after accepted `[INL]001` / `[INL]007`

- `[INL]003` heuristic classes, action filtering, and size/iteration policy; narrow two-parameter binary, three-parameter `select`, and memory/table-store `Shrinks` subsets through `v128.store` are implemented, while remaining trivial/flexible/action-filtering breadth stays active;
- `[INL]004` accepted current `no-inline*` policy surface; initial name-section/WAT-identifier wildcard marking, full-inline suppression, inlining-compaction annotation/function-name remap, stale local-name dropping, and shared clone/copy policy helper are implemented;
- `[INL]005` Pattern A / Pattern B partial splitting;
- `[INL]006` nested tail-call, multi-result, and name/annotation repair.

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
4. Keep direct `--pass inlining` evidence separate when future plain work changes; `[INL]007` is accepted for the current surface.
5. Add scheduler tests for touched-only nested cleanup.
6. Replay `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination` neighborhood after direct parity.
7. Only then consider public preset placement.

## Acceptance criteria

Treat `[INL]001` and `[INL]007` as complete only for the currently implemented direct-call surfaces already proven by the green seed lanes. New direct-inliner work should land under `[INL]003`, `[INL]005`, and `[INL]006`, not by reopening accepted direct slices without a new semantic mismatch.

Do not mark `[INL]002` complete until:

- the nested cleanup starts with the real `precompute-propagate` equivalent;
- the default function pipeline runs only on Binaryen's touched set;
- untouched functions are proven unchanged by the nested scheduler;
- focused trace/scheduler tests and direct compare evidence agree.

## Unresolved uncertainty

- The current exact-`unreachable` predictor is artifact-driven and may need refactoring after broader helper deletion and exact scheduler behavior land.
- The current local representation for Binaryen no-inline flags uses internal function annotations and remaps them with function compaction; function names are also remapped for later policy matching, while local/label names are dropped after inlining rewrites until full repair exists. Future clone/copy transforms should call `no_inline_copy_policy_annotations(...)`; partial-inlining-specific official no-inline shapes move with `[INL]005`.
- The best shared scheduler abstraction for DAE/INL/SGO remains open; avoid building three incompatible nested runners.
