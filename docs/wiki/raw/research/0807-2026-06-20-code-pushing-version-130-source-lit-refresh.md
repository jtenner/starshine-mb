# 0807 - Code Pushing Version 130 Source/Lit Refresh

## Question

What changed in the official Binaryen `code-pushing` source and lit proof surface for the local `wasm-opt version 130 (version_130)` oracle, and how should the active `[O4Z-AUDIT-CP]` track update its remaining work?

## Method

- Confirmed the local oracle with `wasm-opt --version`.
- Downloaded official `version_130` `src/passes/CodePushing.cpp`, `src/passes/pass.cpp`, and all `test/lit/passes/*code-pushing*.wast` files from `WebAssembly/binaryen`.
- Compared `version_130` `CodePushing.cpp` and matching lit files against the previously documented `version_129` anchor.
- Updated the living dossier to make the `version_130` bridge the current audit source.

## Finding

The owner structure remains stable: `LocalAnalyzer`, `class Pusher`, `isPushable(...)`, `isPushPoint(...)`, `optimizeSegment(...)`, `optimizeIntoIf(...)`, and `doWalkFunction(...)` are still the relevant source surfaces. Public `pass.cpp` registration and no-DWARF scheduling remain visible for `code-pushing`.

The important source drift is in effect-ordering checks. `version_130` uses `effects.orderedBefore(cumulativeEffects)` where the older `version_129` source used `cumulativeEffects.invalidates(effects)` in both segment movement and `if`-arm sinking. Future Starshine widening should therefore treat ordered-before constraints as first-class source evidence, not merely a coarse effect invalidation boundary.

The official `version_130` lit proof surface is the named family set:

- `code-pushing-atomics.wast`
- `code-pushing-eh-legacy.wast`
- `code-pushing-eh.wast`
- `code-pushing-gc.wast`
- `code-pushing_ignore-implicit-traps.wast`
- `code-pushing_into_if.wast`
- `code-pushing_tnh.wast`

No generic `code-pushing.wast` file exists in the `version_130` lit directory. The newly relevant file for the current audit is `code-pushing-atomics.wast`, which proves that Binaryen allows a GC `struct.get` to move past a shared atomic load, but not past a shared atomic store, for both into-`if` and segment push cases.

## Durable updates made

- Added `docs/wiki/raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md` as the current source bridge.
- Updated `docs/wiki/binaryen/passes/code-pushing/implementation-structure-and-tests.md` to replace the stale generic `code-pushing.wast` map with the `version_130` named lit family set.
- Updated the strategy, segment/barrier, index, and readiness pages to reference the `version_130` bridge and call out the `orderedBefore` / atomics audit implications.
- Updated `agent-todo.md` so `[O4Z-AUDIT-CP]` records this as `[O4Z-AUDIT-CP-B]` and narrows remaining work to source-backed families.
- Appended the source-refresh entry to `docs/wiki/log.md`.

## Remaining uncertainty

This slice did not implement atomics/GC ordered-before behavior or general segment movement. Starshine's current strict movable-value gate and lack of general segment windows mean the atomics lit family remains an explicit audit gap, not a discovered correctness bug in an implemented Starshine transform.

No direct pass-fuzz compare was run in this slice. The source/lit refresh is inventory work, not final closeout evidence.

## Recommended next slice

Add analyzer/segment-window discovery tests that do not rewrite yet, or choose a single mutating push-point family with the smallest HOT representation. The new `version_130` evidence makes `orderedBefore` / atomics a good negative-boundary target before admitting broader GC/reference movement.

## Sources

- `docs/wiki/raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`
- Binaryen `version_130` `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodePushing.cpp>
- Binaryen `version_130` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- Binaryen `version_130` `code-pushing-atomics.wast`: <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/code-pushing-atomics.wast>
