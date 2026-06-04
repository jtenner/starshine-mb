# Binaryen `local-cse` `version_130` / current-main audit refresh

_Capture date:_ 2026-06-04  
_Status:_ immutable source bridge for the `docs/wiki/binaryen/passes/local-cse/` dossier and the `[O4Z-AUDIT-LCSE]` follow-up

## Scope

This file records the official Binaryen source surfaces rechecked while reconciling Starshine's active `local-cse` status with the 2026-06-04 O4z audit note.
It extends the earlier immutable captures in:

- [`2026-04-22-local-cse-primary-sources.md`](2026-04-22-local-cse-primary-sources.md)
- [`2026-04-25-local-cse-current-main-code-map.md`](2026-04-25-local-cse-current-main-code-map.md)
- [`2026-05-05-local-cse-current-main-recheck.md`](2026-05-05-local-cse-current-main-recheck.md)
- [`2026-05-06-local-cse-current-main-line-anchor-refresh.md`](2026-05-06-local-cse-current-main-line-anchor-refresh.md)

## Official sources consulted

### Latest public release anchor

- Binaryen release `version_130`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>
  - Observed on 2026-06-04 as the latest public release page; GitHub shows the release date as 2026-06-01 and commit `5d704ad`.

### Binaryen `version_130`

- `src/passes/LocalCSE.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/LocalCSE.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/LocalCSE.cpp>
- `src/ir/linear-execution.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/linear-execution.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/ir/linear-execution.h>
- `test/lit/passes/local-cse.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/local-cse.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/passes/local-cse.wast>

### Binaryen `main` drift check

- `src/passes/LocalCSE.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalCSE.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/LocalCSE.cpp>
- `src/ir/linear-execution.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/linear-execution.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/linear-execution.h>
- `test/lit/passes/local-cse.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-cse.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/local-cse.wast>

## Reviewed source surfaces

- `LocalCSE.cpp` still defines `Scanner`, `Checker`, and `Applier` as `LinearExecutionWalker` visitors.
- `LocalCSE.cpp` still sets `connectAdjacentBlocks = true` in the scanner/checker/applier stages.
- `linear-execution.h` still treats `if` specially: with `connectAdjacentBlocks` enabled, the condition can stay connected to the `then` arm, while explicit non-linear notes still separate the false/merge paths.
- `local-cse.wast` still covers the core local-CSE lit families: repeated arithmetic, recursive/parent-over-child cancellation, loads, ordinary call barriers, nested-call negatives, many-local-set cases, and `br_table` / switch child ordering.

## Durable observations

- No teaching-relevant drift was found between the 2026-05-06 local-CSE source bridge, `version_130`, and current `main` on the reviewed source surfaces.
- The source-backed before-`if` into `then` positive remains part of the Binaryen window model by inference from `LinearExecutionWalker` plus `LocalCSE.cpp`'s enabled adjacent-block connection. This is stronger than a generic “basic block only” summary, but weaker than a dedicated standalone upstream lit fixture for that exact before-`if`/then-arm shape.
- The 2026-06-04 Starshine audit found that current Starshine does **not** implement that before-`if`/then-arm reuse window. Treat this as a semantic-safe missed optimization and parity gap, not as a validation or runtime semantic mismatch.
- The local Starshine code evidence for the gap is the current region-local traversal in `src/passes/local_cse.mbt:761-805`, where each `then` / `else` / nested region receives a fresh local-CSE state instead of inheriting a safe subset of the parent region's active bindings.
- Current Starshine tests in `src/passes/local_cse_test.mbt:14-94` cover registry, same-window arithmetic, parent-over-child, load/store, and local-write barriers; they still lack the before-`if`/then-arm positive plus paired after-`if` and else-arm negatives.

## Consumability rule

Cite this file together with [`../research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md`](../research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md) when discussing the current LCSE audit gap. Use the living pages under `docs/wiki/binaryen/passes/local-cse/` as the human-readable destination.
