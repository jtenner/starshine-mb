---
kind: raw-source
status: supported
last_reviewed: 2026-05-04
source_type: primary-source-manifest
pass: gufa-cast-all
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp#L2592-L2596
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp#L2592-L2596
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp#L1778-L1805
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp#L1778-L1805
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa-cast-all.wast#L1049-L1073
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast#L1049-L1073
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/cmd/cmd.mbt
  - ../../../../src/passes/pass_manager.mbt
---

# `gufa-cast-all` Current-Main Recheck And Primary-Source Manifest

## What was checked

On 2026-05-04, official Binaryen `main` and tagged `version_129` were rechecked on the `gufa-cast-all` registration, the shared `GUFA.cpp` engine, and the dedicated `gufa-cast-all.wast` proof surface.

## Findings

- `pass.cpp` still registers `gufa-cast-all` with the public description “GUFA plus add casts for all inferences”.
- `GUFA.cpp` still exposes `createGUFACastAllPass()`, which constructs `GUFAPass(false, true)`.
- `visitFunction(...)` still performs the shared GUFA refinalize, then `addNewCasts(func)` when `castAll`, then EH nested-pop repair, and still skips the `gufa-optimizing` cleanup rerun when `optimizing` is false.
- `addNewCasts(...)` still GC-gates cast insertion, skips uncastable or non-reference values, downgrades exactness when custom descriptors are unavailable, and inserts `ref.cast` only when the improved type is a real subtype improvement.
- `gufa-cast-all.wast` still proves the sibling’s dedicated public contract: new cast insertion, exact struct/function-reference cases, preserved no-op families, and conservative tag / EH boundaries.
- No teaching-relevant drift was found on the reviewed surfaces.

## Why this manifest matters

This recheck refreshes the `gufa-cast-all` dossier from 2026-04-24 to 2026-05-04 without changing the teaching contract. It also gives the wiki a fresher upstream anchor for the shared-engine / cast-materialization split and the current local status map.

## Local surfaces to read with this manifest

- [`../../../../src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)
- [`../../../../src/cmd/cmd.mbt`](../../../../src/cmd/cmd.mbt)
- [`../../../../src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt)
