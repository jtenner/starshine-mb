---
kind: raw-source
status: supported
last_reviewed: 2026-05-05
source_type: current-main-recheck
pass: code-pushing
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast
  - ../../../src/passes/code_pushing.mbt
  - ../../../src/passes/code_pushing_test.mbt
  - ../../../src/passes/optimize.mbt
---

# Binaryen `code-pushing` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/code-pushing/` dossier

## Scope

This file records the current-main recheck used to refresh the `code-pushing` dossier on 2026-05-05.
It extends, rather than replaces, the earlier port-readiness manifest in `docs/wiki/raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md` and the earlier research note in `docs/wiki/raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/code-pushing/index.md`
- `docs/wiki/binaryen/passes/code-pushing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-pushing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/code-pushing/segment-selection-and-barriers.md`
- `docs/wiki/binaryen/passes/code-pushing/wat-shapes.md`
- `docs/wiki/binaryen/passes/code-pushing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md`

## Official sources consulted

### Binaryen `main`

- `CodePushing.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/CodePushing.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>

### Tagged comparison anchor

- `CodePushing.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `code-pushing.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
- `code-pushing_into_if.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
- `code-pushing_ignore-implicit-traps.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
- `code-pushing_tnh.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
- `code-pushing-gc.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
- `code-pushing-eh.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>

## Reviewed source surfaces

The 2026-05-05 recheck focused on the same teaching-relevant surfaces already documented in the living dossier:

- the `LocalAnalyzer` / `Pusher` owner-file shape
- the `isPushable(...)` / `isPushPoint(...)` / `optimizeSegment(...)` / `optimizeIntoIf(...)` family
- the public `code-pushing` registration and no-DWARF placement in `pass.cpp`

## Durable observations

- Current `main` still teaches the same source-backed `LocalAnalyzer` + `Pusher` segment model already captured by the living dossier.
- The refreshed source check did not surface a teaching-relevant current-main drift on the reviewed owner and scheduler surfaces.
- The existing tagged test set remains the right permanent proof surface for the narrow movement-safety families in the pass.
- The local Starshine story is unchanged by this source refresh: `code-pushing` remains a broader HOT parity target, not a one-to-one AST port of the upstream owner file.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
