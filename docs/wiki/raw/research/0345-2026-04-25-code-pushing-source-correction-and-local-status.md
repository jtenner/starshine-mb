---
kind: research
status: superseded
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-code-pushing-current-main-port-readiness.md
  - ./0413-2026-04-26-code-pushing-current-main-port-readiness.md
  - ../binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../binaryen/2026-04-22-code-pushing-primary-sources.md
  - ./0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/code-pushing/index.md
  - ../../binaryen/passes/code-pushing/binaryen-strategy.md
  - ../../binaryen/passes/code-pushing/implementation-structure-and-tests.md
  - ../../binaryen/passes/code-pushing/segment-selection-and-barriers.md
  - ../../binaryen/passes/code-pushing/wat-shapes.md
  - ../../binaryen/passes/code-pushing/starshine-strategy.md
  - ../../../../src/passes/code_pushing.mbt
  - ../../../../src/passes/code_pushing_test.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../agent-todo.md
supersedes:
  - ./0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
---

# `code-pushing` source correction and local-status follow-up

> Supersession note (2026-04-26): this note's local Starshine status remains historically useful, but its upstream correction overcorrected the Binaryen strategy. Use [`0413-2026-04-26-code-pushing-current-main-port-readiness.md`](./0413-2026-04-26-code-pushing-current-main-port-readiness.md) and the living [`code-pushing` dossier](../../binaryen/passes/code-pushing/index.md) for current upstream behavior. In particular, `Pusher`, segment windows, `isPushable`, `isPushPoint`, and `optimizeSegment` are real owner-file concepts in the official sources checked on 2026-04-26.

## Why this follow-up exists

The `code-pushing` dossier had become internally inconsistent after the pass was implemented locally and after a closer source read of Binaryen `version_129`.

Two kinds of stale knowledge were present:

1. **Upstream strategy overread**
   - The living pages and the 2026-04-22 follow-up taught `BranchSeeker`, `Pusher`, generic target segments, a local `benefit > cost` profitability gate, and two-live-arm `if` duplication as if they were visible in `CodePushing.cpp`.
   - The official `version_129` source instead centers on `visitBlock`, `optimizeIntoIf`, `canPushThrough`, and `tryPush`.
2. **Local Starshine status drift**
   - The Starshine page had been partially refreshed to mention the active HOT pass but still ended with “no transform yet” and described the pass as absent.
   - Current code has `src/passes/code_pushing.mbt`, focused tests, registry coverage, and command/native-adapter coverage.

This follow-up corrects those contradictions and records the supersession explicitly rather than silently rewriting the past.

## Primary source ingested

Added:

- `docs/wiki/raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md`

It captures the official Binaryen `version_129` and current-`main` `CodePushing.cpp`, `pass.cpp`, `opt-utils.h`, and the dedicated `code-pushing*` lit files, plus exact source-location anchors for the corrected algorithm reading.

## Corrected Binaryen contract

The corrected source-backed teaching contract is:

- `CodePushing` is function-parallel and requires expression refs.
- `visitBlock(...)` walks block children and first tries the `if`-specific path.
- `optimizeIntoIf(...)` is about the one-unreachable-arm case, preserving execution by moving the bounded prefix between a previous fallthrough boundary and the `if` into the reachable arm.
- `canPushThrough(...)` is the important movement-safety predicate.
- `tryPush(...)` is the generic local sibling-root move before a later use.
- The reviewed source does not expose `BranchSeeker`, `Pusher`, or a local profitability score in this pass.
- The official tests should still be taught as broad coverage for ordinary positives, `into_if`, option-sensitive trap behavior, GC, and EH, but the pages should not invent unobserved helpers to explain them.

## Local Starshine status after correction

Current Starshine is not “no transform yet.”

The active local truth is:

- `src/passes/optimize.mbt` registers `code-pushing` as an active `HotPass`.
- `src/passes/code_pushing.mbt` implements two conservative HOT families:
  - const-like `local.set` sinking into the single consuming `if` arm
  - typed/dead block flattening near an `unreachable` parent context
- `src/passes/code_pushing_test.mbt` covers the positive single-arm sinks plus important no-op guards.
- `src/passes/registry_test.mbt` covers active registry classification and descriptor shape.
- `src/cmd/cmd_wbtest.mbt` contains native/command-surface coverage for the broader direct pass lane.
- `agent-todo.md` still keeps `CP` as an active broader parity slice because the local pass is narrower than Binaryen.
- Public optimize/shrink presets still omit the exact Binaryen `code-pushing` slot pending `simplify-locals-nostructure` and stronger parity evidence.

## Pages updated

- `docs/wiki/binaryen/passes/code-pushing/index.md`
- `docs/wiki/binaryen/passes/code-pushing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-pushing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/code-pushing/segment-selection-and-barriers.md`
- `docs/wiki/binaryen/passes/code-pushing/wat-shapes.md`
- `docs/wiki/binaryen/passes/code-pushing/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Remaining uncertainty

- This run did not re-derive every individual assertion in the large upstream lit files. It corrected the implementation skeleton and the high-level shape catalog against the official source.
- A future implementation-signoff run should still compare Starshine directly against Binaryen for `code-pushing`, especially around GC, EH, and option-sensitive trap cases.
- The local typed/dead-block flattening family is Starshine-local and should not be taught as an upstream Binaryen `code-pushing` behavior unless a future upstream source pass is found that matches it directly.
