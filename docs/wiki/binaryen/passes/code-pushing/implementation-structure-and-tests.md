---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `code-pushing` Implementation Structure And Tests

## Why this page exists

The older dossier explained `code-pushing` with helper names and heuristics that are not present in the reviewed Binaryen `version_129` source.
This page is the source map future readers should use before editing strategy or shape pages.

## Upstream owner file

The pass is concentrated in:

- Binaryen `version_129` `src/passes/CodePushing.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>

Important source regions:

| Source region | What it owns | Teaching consequence |
| --- | --- | --- |
| `CodePushing` pass declaration, `isFunctionParallel()`, `requiresExpressionRefs()`, and `getPassOptions()` | Pass identity, per-function execution, expression-ref dependency, option capture | Ports need expression identity and option-sensitive trap behavior |
| `visitBlock(...)` | Main structured block scan | The pass is block-child-order local, not arbitrary CFG sinking |
| `optimizeIntoIf(...)` | One-unreachable-arm `if` movement | Do not teach this as generic two-reachable-arm duplication |
| `canPushThrough(...)` | Movement safety across a later expression | Most correctness constraints live here |
| `tryPush(...)` | Generic local sibling-root movement before a later use | The generic rewrite is one-expression local motion, not target-segment cloning |
| `ReFinalize` calls | Type repair after changes | Refinalization is part of the mutation contract |

## Supporting upstream files

- `src/passes/pass.cpp`
  - Registers and schedules the public pass name.
  - Source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - Scheduler helper context for optimization reruns; useful for understanding why `code-pushing` appears in repeated cleanup neighborhoods.
  - Source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>

Older docs also cited helper surfaces such as `effects.h`.
Those helpers still matter conceptually, but for this pass the concrete source-reading path should start from the pass-local `canPushThrough(...)` predicate in `CodePushing.cpp`.

## Official lit-test map

| Test file | What it proves |
| --- | --- |
| `code-pushing.wast` | Baseline local pushing examples and no-op boundaries for ordinary structured code |
| `code-pushing_into_if.wast` | The one-unreachable-arm `if` family and execution-preservation subtleties |
| `code-pushing_ignore-implicit-traps.wast` | Option-sensitive relaxation around implicit traps |
| `code-pushing_tnh.wast` | Traps-never-happen behavior |
| `code-pushing-gc.wast` | GC/reference-typed families that can participate only under the same movement-safety rules |
| `code-pushing-eh.wast` | Exception-handling-sensitive no-op and movement boundaries |

Official test URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>

## Explicit non-owners

Do not cite these as `CodePushing.cpp` implementation pieces for `version_129` unless future upstream source changes:

- `BranchSeeker`
- `Pusher`
- a local `benefit > cost` profitability score
- a pass-local target-segment planner

Those names belonged to the stale interpretation this page corrects.

## Current-main drift note

A focused 2026-04-25 current-`main` spot check of `CodePushing.cpp`, `pass.cpp`, `opt-utils.h`, and the dedicated `code-pushing*` lit files did not find teaching-relevant drift from the corrected `version_129` structure.
Keep the current-main check narrow: it confirms the corrected skeleton above, not every possible future behavior claim.

## Sources

- [`../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md)
- [`../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md)
- Binaryen `version_129` source and tests linked above.
