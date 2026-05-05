---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `code-pushing` Implementation Structure And Tests

## Why this page exists

This page is the source map future readers should use before editing `code-pushing` strategy or shape pages.

The 2026-05-05 recheck refreshes the same reviewed owner and scheduler surfaces and still supersedes the 2026-04-25 miscorrection: upstream Binaryen `CodePushing.cpp` does use `LocalAnalyzer`, `Pusher`, segment selection, and effect-checked movement.

## Upstream owner file

The pass is concentrated in:

- Binaryen current-main `src/passes/CodePushing.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
- Binaryen `version_129` `src/passes/CodePushing.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>

Important source regions by owner name:

| Source owner | What it owns | Teaching consequence |
| --- | --- | --- |
| `LocalAnalyzer` | Local set/get counts and single-first-assignment classification | The pass is about movable temporary locals, not arbitrary expression sinking |
| `Pusher` | Block-root segment scan and rewrite driver | Segment-selection language is correct when it means block-local `local.set` windows |
| `isPushable(...)` | Candidate `local.set` legality, SFA requirement, local-use accounting, and removable-effect gate | Most no-ops come from local-use or effect proof failure |
| `isPushPoint(...)` | Recognition of `if`, `switch`, conditional `br`, and dropped push-point wrappers | Shape catalogs should include more than plain `if` |
| `optimizeSegment(...)` | Ordered movement of one or more candidate sets toward a push point | Multi-set order preservation is part of the real contract |
| `optimizeIntoIf(...)` | Arm-specific sinking and post-if-read checks | One-arm consumption and unreachable-arm cases are the important `if` family |
| `doWalkFunction(...)` / pass declaration | Function-local analysis plus walker setup | Starshine parity needs function-local analysis before broader mutation |

## Supporting upstream files

- `src/passes/pass.cpp`
  - Registers and schedules the public pass name.
  - Source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Effect/property helper surfaces used from `CodePushing.cpp`
  - The concrete source path should start at the pass-local `EffectAnalyzer` / `Properties` calls rather than at generic helper descriptions.

## Official lit-test map

| Test file | What it proves |
| --- | --- |
| `code-pushing.wast` | Baseline local-set segment pushing and ordinary no-op boundaries |
| `code-pushing_into_if.wast` | One-arm `if` sinking plus post-if-read and unreachable-arm subtleties |
| `code-pushing_ignore-implicit-traps.wast` | Option-sensitive relaxation around implicit traps |
| `code-pushing_tnh.wast` | Traps-never-happen behavior |
| `code-pushing-gc.wast` | GC/reference-typed families under the same movement-safety rules |
| `code-pushing-eh.wast` | Exception-handling-sensitive no-op and movement boundaries |

Official test URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>

## Starshine implementation/test map

| Local file | What it proves |
| --- | --- |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) | Active HOT subset: const-like single-arm `local.set` sinking plus local dead-block flattening |
| [`src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt) | Then/else positives, both-arm and later-use negatives, nested-later-use negative, trap guard, dead-block flattening guards |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | Active registry entry and preset omission / tuple exact-slot gating |
| [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) | Registry classification for the direct pass |
| [`src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt) | Command-surface coverage for direct pass use |

## Explicit stale claims

Do not repeat these 2026-04-25 claims:

- “`Pusher` is not present in `CodePushing.cpp`.”
- “Segment selection is stale.”
- “The pass is only `visitBlock` + `tryPush`.”
- “Local profitability-style selection is absent.”

The correct caveat is narrower: Binaryen has a `Pusher` / segment algorithm, but it is constrained to SFA `local.set` candidates and does not justify arbitrary two-live-arm duplication.

## Sources

- [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- Binaryen current-main and `version_129` source/test links above.
