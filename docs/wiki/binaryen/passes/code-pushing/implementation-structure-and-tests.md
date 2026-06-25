---
kind: concept
status: supported
last_reviewed: 2026-06-25
sources:
  - ../../../raw/research/0896-2026-06-25-code-pushing-independent-into-if-order.md
  - ../../../raw/research/0895-2026-06-25-code-pushing-tnh-movement.md
  - ../../../raw/research/0829-2026-06-24-code-pushing-br-on-cast-fail-movement.md
  - ../../../raw/research/0828-2026-06-24-code-pushing-br-on-cast-movement.md
  - ../../../raw/research/0826-2026-06-24-code-pushing-br-on-null-movement.md
  - ../../../raw/research/0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md
  - ../../../raw/research/0824-2026-06-24-code-pushing-branch-value-br-if.md
  - ../../../raw/research/0823-2026-06-21-code-pushing-atomics-gc-boundary.md
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md
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

The 2026-06-20 `version_130` refresh is the current local-oracle source bridge. It keeps the same reviewed owner and scheduler surfaces and still supersedes the 2026-04-25 miscorrection: upstream Binaryen `CodePushing.cpp` does use `LocalAnalyzer`, `Pusher`, segment selection, and effect-checked movement. It also records audit-relevant drift from `version_129`: movement checks now use `effects.orderedBefore(cumulativeEffects)`, and the official lit proof surface includes a new atomics/GC ordering file.

## Upstream owner file

The pass is concentrated in:

- Binaryen `version_130` `src/passes/CodePushing.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodePushing.cpp>
- Binaryen current-main `src/passes/CodePushing.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>

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
  - Source: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- Effect/property helper surfaces used from `CodePushing.cpp`
  - The concrete source path should start at the pass-local `EffectAnalyzer` / `Properties` calls rather than at generic helper descriptions.

## Official lit-test map

| Test file | What it proves |
| --- | --- |
| `code-pushing-atomics.wast` | `version_130` atomics/GC ordering: non-null GC `struct.get` reads may move past shared atomic loads but not shared atomic stores, both into `if` arms and across segment push points; Starshine mirrors this narrow family with HOT tests until shared-GC WAT parsing is available |
| `code-pushing_into_if.wast` | One-arm `if` sinking plus post-if-read and unreachable-arm subtleties |
| `code-pushing_ignore-implicit-traps.wast` | Option-sensitive relaxation around implicit traps |
| `code-pushing_tnh.wast` | Traps-never-happen behavior; Starshine now covers the reduced exact integer div/rem into-if family from `0895` |
| `code-pushing-gc.wast` | GC/reference-typed families under the same movement-safety rules |
| `code-pushing-eh.wast` | Exception-handling-sensitive no-op and movement boundaries |
| `code-pushing-eh-legacy.wast` | Legacy EH-sensitive coverage retained in the `version_130` lit surface |

There is no generic `code-pushing.wast` file in the `version_130` lit directory; use the named family files above as the current proof surface.

Official `version_130` test URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-atomics.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing_into_if.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing_tnh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-eh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-eh-legacy.wast>

## Starshine implementation/test map

| Local file | What it proves |
| --- | --- |
| [`src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt) | Accepted direct HOT subset: safe single-arm `local.set` sinking, bounded segment movement after ordinary/dropped `if`, no-branch-value and branch-value `br_if`, dropped void-label `br_on_null`, one-result-block `br_on_non_null`, dropped one-result-block `br_on_cast`, dropped one-result-block `br_on_cast_fail`, guarded `global.get` / local-copy / non-null `struct.get` movement, and local dead-block flattening |
| [`src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt) | Then/else positives, pure-value/global/local-copy movement positives, into-if dependency-chain and independent source-order positives, `br_if` branch-value single-/multi-set positives and payload-read boundary, dropped `br_on_null`, one-result-block `br_on_non_null`, dropped `br_on_cast`, and dropped `br_on_cast_fail` single-/multi-set positives plus guard-read boundaries, both-arm and later-use negatives, nested-later-use negative, default trap guard, TNH exact-div into-if positive, dead-block flattening guards |
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

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0829-2026-06-24-code-pushing-br-on-cast-fail-movement.md`](../../../raw/research/0829-2026-06-24-code-pushing-br-on-cast-fail-movement.md)
- [`../../../raw/research/0828-2026-06-24-code-pushing-br-on-cast-movement.md`](../../../raw/research/0828-2026-06-24-code-pushing-br-on-cast-movement.md)
- [`../../../raw/research/0826-2026-06-24-code-pushing-br-on-null-movement.md`](../../../raw/research/0826-2026-06-24-code-pushing-br-on-null-movement.md)
- [`../../../raw/research/0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md`](../../../raw/research/0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md)
- [`../../../raw/research/0824-2026-06-24-code-pushing-branch-value-br-if.md`](../../../raw/research/0824-2026-06-24-code-pushing-branch-value-br-if.md)
- [`../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- Binaryen `version_130` and current-main source/test links above.
