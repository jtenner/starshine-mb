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
- the accepted `[INL]003` heuristic/action-filtering surface for repeated two-parameter binary, ordered direct-call, three-parameter `select`, parameter-passthrough memory/table/SIMD/GC operation wrappers, the first optimize-level-three/no-shrink flexible no-direct-call/no-loop policy, combined-size filtering, and repeated-work caps;
- unreachable private cycle cleanup/retention families;
- no-inlining unreachable value-block pruning and predicted exact-helper padding;
- narrow hot-unsafe polymorphic self-call suffix detector coverage;
- optimizing nested-cleanup trace marker and explicit first nested-pass trace for `precompute-propagate-prefix`;
- touched-caller/default-init local folding through the private prefix while an untouched sibling remains body-shape unchanged.

## Active blockers

### Deferred direct-inliner breadth after accepted `[INL]001` / `[INL]007`

- `[INL]003` accepted current-supported heuristic/action-filtering surface on 2026-05-14 after the repeated-work cap closeout; reopen only for a new Starshine-supported semantic mismatch in heuristic/action filtering;
- `[INL]004` accepted current `no-inline*` policy surface; initial name-section/WAT-identifier wildcard marking, full-inline suppression, inlining-compaction annotation/function-name remap, stale local-name dropping, and shared clone/copy policy helper are implemented;
- `[INL]005` Pattern A / Pattern B partial splitting;
- `[INL]006` nested tail-call, multi-result, and name/annotation repair.

### `[INL]002` scheduler blockers

- optimizing mode currently approximates nested cleanup;
- the former seed-`0x1eed` `case-008100-gen-valid` command failure is fixed by a narrow hot-unsafe helper guard;
- a private touched-only `precompute-propagate-prefix` now runs before the older cleanup lane, but the real public `precompute-propagate` sibling is still unavailable;
- no exact touched-function-filtered scheduler for the remaining default pipeline;
- no proof that only Binaryen's touched functions run the default pipeline after the prefix;
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

Treat `[INL]001` and `[INL]007` as complete only for the currently implemented direct-call surfaces already proven by the green seed lanes. New direct-inliner work should land under `[INL]005` or `[INL]006` unless a new Starshine-supported heuristic/action-filtering semantic mismatch justifies reopening `[INL]003`; do not reopen accepted direct slices without a new semantic mismatch.

Do not mark `[INL]002` complete until:

- the nested cleanup starts with the real `precompute-propagate` equivalent rather than only the current private prefix approximation;
- the default function pipeline runs only on Binaryen's touched set;
- untouched functions are proven unchanged by the full nested scheduler, not only by body restoration after a whole-module cleanup lane;
- focused trace/scheduler tests and direct compare evidence agree.

## Unresolved uncertainty

- The current exact-`unreachable` predictor is artifact-driven and may need refactoring after broader helper deletion and exact scheduler behavior land.
- The current local representation for Binaryen no-inline flags uses internal function annotations and remaps them with function compaction; function names are also remapped for later policy matching, while local/label names are dropped after inlining rewrites until full repair exists. Future clone/copy transforms should call `no_inline_copy_policy_annotations(...)`; partial-inlining-specific official no-inline shapes move with `[INL]005`.
- The best shared scheduler abstraction for DAE/INL/SGO remains open; avoid building three incompatible nested runners.
