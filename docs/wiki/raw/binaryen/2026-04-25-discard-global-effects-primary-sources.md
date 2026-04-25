---
kind: source-capture
status: supported
last_reviewed: 2026-04-25
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_129
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/wiki/Optimizer-Cookbook
related:
  - ./2026-04-24-global-effects-primary-sources.md
  - ../research/0168-2026-04-21-global-effects-binaryen-research.md
  - ../research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md
  - ../research/0353-2026-04-25-discard-global-effects-source-dossier.md
  - ../../binaryen/passes/discard-global-effects/index.md
  - ../../binaryen/passes/global-effects/index.md
---

# Binaryen `discard-global-effects` primary-source capture

Captured: 2026-04-25

## Source set

- Official Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Retained as the tagged release oracle for this dossier; neighboring source captures reviewed the page as released on **2026-04-01**.
- `src/passes/GlobalEffects.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp>
  - Key reviewed location: `DiscardGlobalEffects::run` loops over module functions and clears each function's stored global-effect summary. The same file owns the sibling producer pass `GenerateGlobalEffects`.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Key reviewed location: public pass registration for `discard-global-effects`, immediately beside `generate-global-effects`.
- `src/wasm.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - Key reviewed location: `Function` owns optional effect metadata, so the pass's transformed state is function metadata rather than instruction bodies.
- `src/ir/effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - Key reviewed location: effect analysis can use a callee's stored summary when present, which explains why clearing stale summaries is semantically important for later optimization decisions.
- Optimizer Cookbook: <https://github.com/WebAssembly/binaryen/wiki/Optimizer-Cookbook>
  - Key reviewed location: Binaryen's pass authoring guidance says passes that may add effects must report that, so previous global-effect analysis can be discarded before such passes run. This is maintainer-authored guidance for the same summary lifecycle modeled by the public cleanup pass.

## Durable facts captured

- `discard-global-effects` is a real public Binaryen pass, not just an internal helper.
- It is the lifecycle sibling of `generate-global-effects`.
- The pass does not optimize instructions, delete functions, or change printable Wasm semantics by itself.
- Its only reviewed transformation is clearing stored per-function global-effect summaries.
- That makes it a pass-state cleanup transformation: later effect-sensitive passes must not consume stale summaries after earlier transforms add calls, stores, traps, or other effects.
- The pass is intentionally useful even when a module's printed WAT would be byte-for-byte unchanged before and after the pass.

## Current-`main` drift note

A 2026-04-25 current-`main` spot check did not find teaching-relevant drift for the cleanup sibling itself: current `main` still registers `discard-global-effects` publicly and still clears the same function-level summary state in `GlobalEffects.cpp`.

The neighboring producer `generate-global-effects` has known current-main implementation drift recorded in [`./2026-04-24-global-effects-primary-sources.md`](./2026-04-24-global-effects-primary-sources.md), but that drift does not change the cleanup sibling's reader-facing contract.

## Uncertainty and contradiction notes

- No dedicated `discard-global-effects.wast` lit file was found in the reviewed source set. The pass's behavior is source-confirmed and lifecycle-confirmed by the producer/consumer tests, but not isolated by its own expected-output file in the reviewed `version_129` surfaces.
- The older `GlobalEffects.cpp` header wording that mentions `PassOptions` remains stale relative to the reviewed implementation/data model. This dossier teaches function-level summary clearing because `GlobalEffects.cpp` and `wasm.h` are the concrete implementation sources.
- Starshine does not currently expose a `discard-global-effects` pass name. The local `global-effects` registry entry is boundary-only and covers the producer-side compatibility name, not this cleanup sibling.
