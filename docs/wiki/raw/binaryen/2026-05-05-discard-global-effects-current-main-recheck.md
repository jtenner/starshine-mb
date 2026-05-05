---
kind: source-capture
status: supported
last_reviewed: 2026-05-05
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_129
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/wiki/Optimizer-Cookbook
related:
  - ./2026-04-25-discard-global-effects-primary-sources.md
  - ../research/0353-2026-04-25-discard-global-effects-source-dossier.md
  - ../../binaryen/passes/discard-global-effects/index.md
  - ../../binaryen/passes/global-effects/index.md
---

# Binaryen `discard-global-effects` current-main recheck

Captured: 2026-05-05

## Source set

- `src/passes/GlobalEffects.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp>
  - Reviewed current-main lines: `DiscardGlobalEffects::run` still iterates `module->functions` and clears each function's stored summary; the implementation shape remains the same cleanup loop already documented for `version_129`.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed current-main lines: `discard-global-effects` remains publicly registered beside `generate-global-effects`, and the pass-runner lifecycle notes around global-effect invalidation remain in place.
- Binaryen Optimizer Cookbook: <https://github.com/WebAssembly/binaryen/wiki/Optimizer-Cookbook>
  - Reviewed current-main lines: the maintainer guidance still says effect-adding passes must report that capability so earlier global-effect summaries can be discarded before they run.
- Baseline sources retained from the 2026-04-25 capture:
  - `src/wasm.h` (`Function.effects` storage)
  - `src/ir/effects.h` (consumer lookup)

## Durable facts captured

- `discard-global-effects` is still a real public Binaryen pass, not an internal helper.
- It still behaves as the lifecycle sibling of `generate-global-effects`.
- The pass still does not rewrite instructions or change printable Wasm by itself.
- Its reviewed transformation remains clearing stored per-function global-effect summaries.
- That keeps the pass a metadata cleanup transformation: later effect-sensitive passes must not consume stale summaries after earlier transforms add calls, stores, traps, or other effects.
- A standalone run can still leave the printed WAT byte-for-byte unchanged.

## Current-main drift note

A 2026-05-05 current-main recheck did not find teaching-relevant drift for the cleanup sibling itself. Current `main` still registers `discard-global-effects` publicly and still clears the same function-level summary state in `GlobalEffects.cpp`.

The neighboring producer `generate-global-effects` still has the current-main SCC-shaped propagation refactor documented in [`./2026-05-04-global-effects-current-main-recheck.md`](./2026-05-04-global-effects-current-main-recheck.md), but that does not change the cleanup sibling's contract.

## Uncertainty and contradiction notes

- No dedicated `discard-global-effects.wast` lit file was found in the reviewed source set. The pass remains source-confirmed and lifecycle-confirmed by the producer/consumer tests, but not isolated by its own expected-output file in the reviewed `version_129` and current-main surfaces.
- The older `GlobalEffects.cpp` header wording that mentions `PassOptions` remains stale relative to the reviewed implementation/data model. This dossier teaches function-level summary clearing because `GlobalEffects.cpp` and `wasm.h` are the concrete implementation sources.
- Starshine does not currently expose a `discard-global-effects` pass name. The local `global-effects` registry entry is boundary-only and covers the producer-side compatibility name, not this cleanup sibling.
