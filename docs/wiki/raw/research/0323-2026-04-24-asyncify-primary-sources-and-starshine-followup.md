---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-asyncify-primary-sources.md
  - ../../binaryen/passes/asyncify/index.md
  - ../../binaryen/passes/asyncify/binaryen-strategy.md
  - ../../binaryen/passes/asyncify/wat-shapes.md
  - ../../binaryen/passes/asyncify/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/binary/decode.mbt
related:
  - ../../binaryen/passes/inlining/index.md
  - ../../binaryen/passes/i64-to-i32-lowering/index.md
  - ../../binaryen/passes/memory64-lowering/index.md
---

# `asyncify` primary sources and Starshine follow-up

## Question

The widened pass wiki had no living page for Binaryen's public `asyncify` transformation even though it is a major upstream whole-module rewrite with official Emscripten documentation and many Starshine prerequisite surfaces: function bodies, call sites, globals, memories, validation, and binary encode/decode. This run asked whether `asyncify` deserves a dossier and what exact local status should be recorded.

## Sources reviewed

- Official Binaryen `version_129` release page.
- Binaryen `version_129` and current-`main` `Asyncify.cpp`.
- Binaryen `version_129` `pass.cpp` and `passes.h`.
- Binaryen `version_129` and current-`main` `test/lit/passes/asyncify.wast`.
- Emscripten Asyncify documentation.
- Local Starshine registry and module surfaces in `src/passes/optimize.mbt`, `src/lib/types.mbt`, `src/validate/typecheck.mbt`, `src/binary/encode.mbt`, `src/binary/decode.mbt`, and `src/wast/`.

## Findings

- `asyncify` is a real public Binaryen pass in `version_129` and remains a substantial current upstream transformation.
- Binaryen's pass rewrites whole functions and module metadata to support pause/resume. It inserts state checks, saves and restores live locals, creates or selects memory, adds state/data globals, and exports runtime API functions.
- The transformation is driven by `ModuleAnalyzer` and user lists so only functions that may unwind/rewind are instrumented. Imports, indirect calls, and callgraph predecessors are the main analysis roots.
- Tail calls are explicitly not supported in the reviewed source path.
- The pass runs nested cleanup and preparation passes around the instrumentation: flatten/DCE before call-site instrumentation and local save/restore work, plus optional default optimization.
- Emscripten's official docs explain the motivation and operational tuning surface: Asyncify lets synchronous-looking C/C++ pause around asynchronous JavaScript work but can add code-size/runtime overhead, especially when indirect-call analysis must be conservative.
- Starshine has no `asyncify` registry entry. Explicit requests are unknown today, not boundary-only or removed.
- Starshine already has much of the low-level representation needed for a future port: functions, globals, memories, imports/exports, calls/indirect calls, `unreachable`, memory operations, validation, WAT parsing/printing, and binary encoding/decoding. It does not have an integrated callgraph-driven Asyncify analysis/instrumentation pipeline, runtime API synthesis, or host integration tests.

## Durable wiki updates made

- Added a raw Binaryen/Emscripten primary-source manifest at `docs/wiki/raw/binaryen/2026-04-24-asyncify-primary-sources.md`.
- Added a new living dossier under `docs/wiki/binaryen/passes/asyncify/` with:
  - landing overview;
  - Binaryen strategy;
  - implementation/test map;
  - transformed-shape catalog;
  - Starshine status and port map.
- Updated the pass folder catalog, tracker, top-level wiki index, changelog, and log so `asyncify` has a stable home.

## Uncertainty

- A faithful Starshine port would need an external runtime test strategy. The Wasm transformation alone is not enough to prove host-level pause/resume correctness.
- The helper `mod-asyncify-*` passes and Emscripten driver settings are related but not covered as separate dossiers here.
- Current-main source was checked only for the teaching-level contract; future ports should re-audit the exact generated helper names and options before implementation.

## Follow-up questions

- Should Starshine reserve `asyncify` as `BoundaryOnly` to make explicit requests fail with a more specific message, or should it remain unknown until a concrete implementation plan exists?
- Should a future port target the existing module pass infrastructure first, or wait for a stronger whole-module rewrite framework that can also support JS interface legalization and memory64/table64 lowering?
- Should a separate dossier cover `mod-asyncify-*` once the main `asyncify` shape is stable in the wiki?
