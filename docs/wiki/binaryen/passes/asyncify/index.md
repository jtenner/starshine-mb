---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md
  - ../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../i64-to-i32-lowering/index.md
  - ../legalize-js-interface/index.md
  - ../memory64-lowering/index.md
---

# Binaryen pass: `asyncify`

## Purpose

`asyncify` is Binaryen's whole-module transformation for making a WebAssembly module pause and resume around asynchronous host work.
It is best known through Emscripten: source code can look synchronous, but the generated Wasm can unwind its stack when an async import is reached and later rewind back into the paused computation.

The beginner version:

- ordinary Wasm has no built-in "pause this stack frame and come back later" instruction;
- `asyncify` instruments calls and live locals so the module can save enough state to leave and later re-enter;
- the transformed module exports helper functions such as `asyncify_start_unwind`, `asyncify_stop_unwind`, `asyncify_start_rewind`, `asyncify_stop_rewind`, and `asyncify_get_state`;
- the host/runtime must still cooperate by calling those helpers correctly.

The advanced version:

- Binaryen analyzes imports, indirect calls, callgraph predecessors, and user add/remove/only lists to decide which functions may change Asyncify state;
- it flattens and cleans functions before flow instrumentation so inserted `if`/`break` checks can fit a predictable control shape;
- it inserts state checks around relevant calls and call-indirect sites;
- it saves and restores only locals that are live across relevant call sites;
- it creates or selects an Asyncify memory and chooses pointer width from that memory;
- it rejects unsupported tail-call surfaces in the reviewed source path.

## Inputs and outputs

### Input shape

The input is a normal module that may contain:

- imports that can start an unwind;
- direct calls to functions that transitively reach such imports;
- indirect calls that may target async-capable functions;
- locals live across those call sites;
- memories, or no memory at all;
- exports and ordinary call graph roots.

### Output shape

The output is still a WebAssembly module, but it has extra control/data plumbing:

- mutable globals for Asyncify state and data pointer tracking;
- an existing or newly created memory used as the save/restore stack area;
- runtime API functions exported under the Asyncify names;
- call-site checks that branch differently in normal, unwinding, and rewinding states;
- local save/restore traffic around relevant call sites;
- indirect-call helper logic when indirect calls are not explicitly ignored.

## Correctness constraints

- **Only instrument relevant functions:** over-instrumentation hurts size and speed; under-instrumentation breaks pause/resume.
- **Preserve live local values:** every local needed after a pausing call must be restored on rewind.
- **Preserve call effects and order:** instrumentation must wrap calls without changing ordinary execution when no unwind/rewind is active.
- **Match pointer width:** memory32 uses `i32` addresses and memory64 uses `i64` addresses for Asyncify data traffic.
- **Reject unsupported tail calls:** the reviewed Binaryen source treats tail calls as unsupported for Asyncify.
- **Coordinate with the runtime:** the transformed Wasm shape is only one half of the contract; host calls to the exported API drive the state machine.

## Notable edge cases

- Indirect calls are conservative unless the user config proves they can be ignored.
- User `add`, `remove`, `only`, and import lists can force or prune the analysis result.
- Functions with no async-reachable call sites should not gain the heavy save/restore scaffolding.
- Modules without a memory may receive one for Asyncify support.
- Modules with memory64 need address-width-aware helper code.
- Tail calls and return calls are not a small extension of the direct-call path; Binaryen's reviewed path rejects them.

## Validation strategy

For Binaryen parity research, start with the official lit file:

- `test/lit/passes/asyncify.wast`

For a future Starshine port, add tests in this order:

1. a simple direct async import instruments its caller and exports runtime helpers;
2. a transitive direct call chain instruments every required predecessor;
3. a function outside the async-reachable set remains unchanged;
4. an indirect call is conservatively instrumented;
5. `ASYNCIFY_IGNORE_INDIRECT`-equivalent behavior is tested separately if exposed;
6. live locals are saved and restored across a call;
7. modules with no memory get a valid Asyncify memory;
8. memory64 modules use `i64` pointer traffic;
9. tail-call input is rejected or explicitly unsupported;
10. an integration harness proves a real unwind/rewind round trip.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - source-backed Binaryen strategy.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files, helper classes, and official test surface.
- [`wat-shapes.md`](wat-shapes.md) - transformed module/function shape catalog.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.

## Sources

- [`../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md`](../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md)
- [`../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md`](../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md)
- Binaryen `Asyncify.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Asyncify.cpp>
- Binaryen lit file: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/asyncify.wast>
- Emscripten Asyncify docs: <https://emscripten.org/docs/porting/asyncify.html>
