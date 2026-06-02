---
kind: entity
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/binaryen/2026-06-02-remove-unused-version-130-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-remove-unused-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md
  - ../../../raw/research/0494-2026-05-06-remove-unused-shape-catalog-and-current-main-recheck.md
  - ../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md
  - ../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md
  - ../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./historical-lineage-and-modern-supersession.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/index.md
  - ../remove-unused-non-function-elements/index.md
  - ../remove-unused-types/index.md
  - ../tracker.md
---

# `remove-unused`

## Role

- `remove-unused` is **not** a current public Binaryen `version_125` pass name.
- It is currently **unimplemented** in Starshine and still lives in the local boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is also still listed in the local Batch 4 map in [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md).
- The best source-backed explanation is that this local short name is a **legacy historical alias** for upstream Binaryen's old `remove-unused-functions` pass, which Binaryen later replaced with `remove-unused-module-elements`.
- The 2026-06-02 version_125 / current-main recheck and the older port-readiness recheck found no current Binaryen resurrection of the short spelling and keep the first local action a registry-hygiene decision: keep rejecting, remove/rename, implement the historical function-only pass literally, or intentionally alias to modern RUME.

## Why this page exists

The local registry name is easy to misunderstand.

Without a dedicated page, a future reader could wrongly assume `remove-unused` means:

- modern [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)
- a current upstream public pass name
- or some unspecified catch-all removal pass

The official Binaryen history says something more precise:

- old upstream Binaryen had `remove-unused-functions`
- that pass removed unreachable **functions only**
- Binaryen later replaced it with the broader `remove-unused-module-elements`
- current Binaryen no longer exposes `remove-unused` or `remove-unused-functions`

## Beginner summary

A safe beginner mental model is:

- `remove-unused` in this repo is a **historical alias problem**, not a current upstream pass name.
- The old upstream behavior was:
  - root start/export/table-segment functions
  - follow direct calls
  - delete unreachable functions
- The modern upstream replacement is broader:
  - `remove-unused-module-elements`
  - which works on many module declaration kinds, not only functions

## Most important durable takeaways

- Current Binaryen `version_125` does **not** register a pass named `remove-unused`.
- Current Binaryen `version_125` does **not** register `remove-unused-functions` either.
- Historical upstream Binaryen **did** register `remove-unused-functions`.
- That old pass was a small function-only reachability pass.
- Binaryen replaced it in 2016 with `remove-unused-module-elements`.
- So the local Starshine registry entry `remove-unused` should be read as a **legacy historical alias**, not as a current upstream name.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Explains the historical upstream implementation, the old roots-and-direct-call algorithm, and the modern absence / replacement story.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Maps the historical and modern upstream files that prove the lineage and supersession.
- [`./historical-lineage-and-modern-supersession.md`](./historical-lineage-and-modern-supersession.md)
  Focused guide to the easiest thing to misread: what the local alias likely points to, and why it should not be taught as a synonym for modern RUME.
- [`./module-shapes.md`](./module-shapes.md)
  Canonical historical shape catalog for the old function-only pass and the main differences from modern `remove-unused-module-elements`.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact local status and port-strategy map: boundary-only registry entry, request rejection, no dispatcher case, modern RUME implementation pointer, and future choices if the alias is removed, renamed, or implemented literally.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Decision and validation bridge for the ambiguous local alias: keep rejecting, remove/rename, implement the old function-only pass literally, or deliberately alias to modern RUME.

## Current maintenance rule

- Treat this folder as the canonical home for future `remove-unused` registry-lineage work in this repo.
- Keep the page honest that this is a **legacy alias dossier**, not a current public upstream pass dossier.
- When documenting modern Binaryen behavior, point readers to:
  - [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)
  - [`../remove-unused-non-function-elements/index.md`](../remove-unused-non-function-elements/index.md)
  - [`../remove-unused-types/index.md`](../remove-unused-types/index.md)
- Cite the 2026-04-25 raw manifest, the 2026-04-27 port-readiness source recheck, the 2026-05-06 current-main recheck, the 2026-06-02 version_125 release-horizon recheck, and the source-bridge notes when explaining provenance.
- Treat the `remove-unused` implementation question as a naming and migration decision before treating it as code work.
- Do not silently collapse the historical function-only pass into modern RUME.

## Sources

- [`../../../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md`](../../../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md)
- [`../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md`](../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md)
- [`../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md`](../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md)
- [`../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md`](../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md)
- [`../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md`](../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- Current upstream surfaces:
  - <https://github.com/WebAssembly/binaryen/blob/version_125/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_125/src/passes/passes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_125/test/lit/help/wasm-opt.test>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_125/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Historical upstream surfaces:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/help/wasm-opt.test>
  - <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
  - <https://github.com/WebAssembly/binaryen/commit/98e9e604c7e2e4f928abe8f05691df90cddf09e4>
  - <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/RemoveUnusedModuleElements.cpp>
