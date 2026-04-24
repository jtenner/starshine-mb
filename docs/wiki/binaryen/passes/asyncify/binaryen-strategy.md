---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md
  - ../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Binaryen strategy for `asyncify`

## What Binaryen is transforming

`asyncify` is not a shrink pass or a peephole optimizer.
It is a whole-module continuation-like transformation that makes selected Wasm call paths able to unwind out to the host and later rewind into the saved computation.

Emscripten's public docs frame the user-visible motivation: code can be written as if it blocks, while the compiled Wasm cooperates with asynchronous JavaScript or host APIs.
Binaryen implements the Wasm rewrite that makes that possible.

## Registration and public identity

`version_129` registers a public pass named `asyncify` in `src/passes/pass.cpp`.
The same tag declares `createAsyncifyPass()` in `src/passes/passes.h` and implements the pass in `src/passes/Asyncify.cpp`.

The important split is:

- `asyncify` is the main public module transformation;
- `mod-asyncify-*` helpers in the same source file are related cleanup/simplification helpers, not the primary user-facing pass covered by this dossier;
- Emscripten driver settings configure which imports and functions are considered async roots, but the Binaryen pass is the Wasm transformer.

## Core algorithm

Binaryen's source-backed pipeline has four major layers.

### 1. Analyze async reachability

`ModuleAnalyzer` decides which functions can change Asyncify state.
The roots include:

- imports listed as async-capable;
- calls to Asyncify runtime hooks;
- indirect calls unless ignored by configuration;
- user-forced additions;
- callgraph predecessors of those roots.

The analysis also honors user lists that remove functions or restrict instrumentation to an `only` set.
That matters because Asyncify overhead can be large: Binaryen needs a conservative but tunable analysis boundary.

### 2. Prepare function bodies

The top-level pass runs nested preparation/cleanup passes before inserting the main flow instrumentation.
The reviewed source routes functions through flattening and dead-code cleanup so later state-check insertion operates on predictable control flow.

This is one reason `asyncify` should not be taught as a single local rewrite.
It owns a staged module pipeline.

### 3. Instrument control flow around calls

`AsyncifyFlow` instruments relevant calls and indirect calls.
The key state-machine idea is:

- normal execution performs the call and continues;
- unwinding execution breaks out after an async call starts unwinding;
- rewinding execution skips already-replayed call sites until the target call frame is reached.

Binaryen uses helper intrinsics and the runtime state global to make those branches explicit in Wasm.

### 4. Save and restore locals

`AsyncifyLocals` tracks locals live across relevant call sites and emits stack traffic around unwind/rewind points.
Only locals needed after a pausing call must be stored and loaded.
This is the central correctness and size boundary: saving too little is wrong, saving everything is usually too expensive.

## Runtime API shape

The transformed module exports functions with the Asyncify API names, including:

- `asyncify_start_unwind`
- `asyncify_stop_unwind`
- `asyncify_start_rewind`
- `asyncify_stop_rewind`
- `asyncify_get_state`

The reviewed source also creates mutable state/data globals and uses a memory-backed data area to save local values.
The host/runtime is responsible for calling the exported API at the right times.

## Memory and pointer width

Binaryen must know where to save locals.
The pass either uses an existing memory or creates an Asyncify memory when configured to do so.
Then it chooses the pointer type from the selected memory:

- memory32 traffic uses `i32` addresses;
- memory64 traffic uses `i64` addresses.

That makes `asyncify` adjacent to feature-lowering pages such as [`../memory64-lowering/index.md`](../memory64-lowering/index.md), but it is not itself a memory64 lowering pass.

## Tail-call boundary

The reviewed `version_129` source explicitly rejects tail calls in the Asyncify path.
This is a correctness boundary, not a missing small case: tail calls remove the ordinary "return here after the call" shape that Asyncify instrumentation relies on.

## Non-goals

`asyncify` is not:

- a general optimizer;
- a replacement for JavaScript Promise integration by itself;
- a local-only HOT peephole pass;
- a way to make every host call asynchronous automatically;
- the same pass as `jspi` or JS-interface legalization.

It creates the Wasm-side state machine.
A runtime and configuration still decide which host operations actually suspend.

## Current-main check

The current-`main` files reviewed on 2026-04-24 still present the same teaching-level contract as `version_129`:

- the main owner remains `Asyncify.cpp`;
- the public pass spelling remains `asyncify`;
- the central lit file remains `asyncify.wast`;
- the source still frames Asyncify as whole-module state-machine instrumentation.

Treat this as a narrow no-drift check, not as an implementation signoff for a future Starshine port.

## Sources

- [`../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md`](../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md)
- [`../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md`](../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md)
- Binaryen `Asyncify.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Asyncify.cpp>
- Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Emscripten Asyncify docs: <https://emscripten.org/docs/porting/asyncify.html>
