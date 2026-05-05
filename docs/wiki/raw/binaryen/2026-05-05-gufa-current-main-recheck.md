---
kind: raw-source
status: supported
last_reviewed: 2026-05-05
source_type: primary-source-manifest
pass: gufa
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp#L2582-L2602
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp#L2582-L2602
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp#L1549-L1803
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp#L1549-L1803
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/possible-contents.h#L2888-L2995
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h#L2888-L2995
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa.wast#L1-L8
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast#L1-L8
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa-optimizing.wast#L1-L3
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast#L1-L3
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa-cast-all.wast#L1-L8
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast#L1-L8
  - ../../../src/passes/optimize.mbt
  - ../../../src/cmd/cmd.mbt
  - ../../../src/passes/pass_manager.mbt
---

# `gufa` Current-Main Recheck And Primary-Source Manifest

## What was checked

On 2026-05-05, official Binaryen `main` and tagged `version_129` were rechecked on the plain `gufa` registration, the shared `GUFA.cpp` engine, the contents-oracle helper, and the dedicated lit surfaces for plain, optimizing, and cast-all behavior.

## Findings

- `pass.cpp` still registers `gufa`, `gufa-optimizing`, and `gufa-cast-all` as separate public pass names, alongside the sibling `type-refining-gufa` entry.
- `GUFA.cpp` still keeps the family in one engine: plain `gufa` is `GUFAPass(false, false)`, `gufa-optimizing` is `GUFAPass(true, false)`, and `gufa-cast-all` is `GUFAPass(false, true)`.
- `visitRefEq`, `visitRefTest`, `visitRefCast`, and `addNewCasts` still separate the plain rewrite surface from the sibling-only cleanup and cast-materialization surfaces.
- `possible-contents.h` still documents the closed-world contents oracle model and the `None` / `Literal` / `GlobalInfo` / `ConeType` / `Many` result families.
- The dedicated lit files still divide the public contract the same way: plain `gufa` covers reachability, constants, and reference checks; `gufa-optimizing` covers nested cleanup; `gufa-cast-all` covers explicit cast insertion.
- No teaching-relevant drift was found on the reviewed surfaces.

## Why this manifest matters

This recheck refreshes the plain `gufa` dossier with a 2026-05-05 upstream anchor while keeping the older `version_129` contract intact. It also gives the wiki a fresh source base for the plain-oracle / optimizing-cleanup / cast-materialization split.

## Local surfaces to read with this manifest

- [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- [`../../../src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt)
- [`../../../src/passes/pass_manager.mbt`](../../../src/passes/pass_manager.mbt)
