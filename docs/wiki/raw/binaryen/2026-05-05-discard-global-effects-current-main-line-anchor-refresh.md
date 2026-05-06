# Binaryen `discard-global-effects` current-main line-anchor refresh

_Status:_ immutable current-main source-anchor refresh for the `docs/wiki/binaryen/passes/discard-global-effects/` dossier

This note records the official Binaryen `main` line anchors that support the existing `discard-global-effects` cleanup contract and keep the paired `generate-global-effects` lifecycle story explicit.

## Primary sources rechecked

- `GlobalEffects.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
- `pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen Optimizer Cookbook: <https://github.com/WebAssembly/binaryen/wiki/Optimizer-Cookbook>

## Current-main line anchors

- `GlobalEffects.cpp#L1520-L1530` - `copyEffectsToFunctions(...)` clears each function's stored summary before optionally writing a fresh one
- `GlobalEffects.cpp#L1555-L1562` - `DiscardGlobalEffects::run` loops over `module->functions` and resets each `effects` field
- `pass.cpp#L2475-L2479` - public registration for `discard-global-effects`
- `pass.cpp#L3692-L3698` - scheduler TODO that keeps `generate-global-effects` / `discard-global-effects` lifecycle placement explicit near function passes

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

## Source provenance

- [`../research/0493-2026-05-05-discard-global-effects-current-main-line-anchor-refresh.md`](../research/0493-2026-05-05-discard-global-effects-current-main-line-anchor-refresh.md)
