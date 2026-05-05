---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-asyncify-current-main-recheck.md
  - ../../../raw/research/0445-2026-05-05-asyncify-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md
  - ../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md
  - ../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md
  - ../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../memory64-lowering/index.md
---

# `asyncify` state machine, memory, and EH boundaries

## Why this page exists

The overview and WAT-shape catalog show what `asyncify` does at a high level.
This page isolates the hard half that future Starshine work must not flatten into “wrap calls with checks”:

- Asyncify state is a runtime protocol with explicit helper functions;
- saved locals live in memory and use the selected memory's pointer width;
- indirect calls need conservative call-index bookkeeping unless the user proves they are safe to ignore;
- exception/catch paths have an explicit unwind option boundary;
- tail calls are unsupported by the reviewed Binaryen path;
- `mod-asyncify-*` helpers are follow-up simplifiers, not the main transformation.

## Runtime state values

Binaryen's emitted module communicates with the host runtime through a small state machine.
The exact helper-body WAT is verbose, but the conceptual states are stable:

| State | Meaning | Compiler consequence |
| --- | --- | --- |
| normal | ordinary execution; no active unwind or rewind | instrumented calls execute and continue normally |
| unwinding | an async operation has asked Wasm to leave the current stack | instrumented frames save live state and break outward |
| rewinding | the host asks Wasm to reconstruct the saved stack | instrumented frames reload state and skip already-replayed calls until the target frame is reached |

The runtime-facing API exports remain the stable external contract:

- `asyncify_start_unwind`
- `asyncify_stop_unwind`
- `asyncify_start_rewind`
- `asyncify_stop_rewind`
- `asyncify_get_state`

A future Starshine port must verify both sides:

1. static shape: helpers, globals, memory traffic, and call-site checks are emitted correctly;
2. dynamic behavior: a host harness can actually unwind and rewind through one or more frames.

## Memory and pointer width are correctness, not formatting

Asyncify stores saved locals and frame metadata in linear memory.
That makes memory selection part of correctness:

- if a usable memory exists, Binaryen can use it;
- if configured for a secondary Asyncify memory, or if no memory exists, Binaryen may add a memory;
- memory32 traffic uses `i32` pointers;
- memory64 traffic uses `i64` pointers.

This is adjacent to [`../memory64-lowering/index.md`](../memory64-lowering/index.md), but the responsibility is different:

- `memory64-lowering` changes address-width feature usage;
- `asyncify` must respect the selected memory's current address width when emitting its own stack/data traffic.

A local port that hard-codes `i32` pointers would be correct for many old examples and still wrong for memory64 input.

## Direct calls, indirect calls, and call-index bookkeeping

Direct calls are the easy case: the callgraph can mark functions that transitively reach async-capable imports or forced async roots.

Indirect calls are conservative by default:

- if ignored by user configuration, the user takes responsibility for proving those calls cannot unwind;
- otherwise, Binaryen instruments them as possible state changers;
- the transform must preserve enough call-site identity to know which frame/call is being replayed during rewind.

That is why the WAT output includes more than a simple `if (state) break` wrapper around `call_indirect`.
A Starshine compare fixture should include at least one indirect-call positive and one configured-ignore negative if the future local option surface exposes the same behavior.

## Exception / catch unwind boundary

The 2026-04-25 source bridge found that the existing dossier under-taught a real source/test family: Binaryen exposes an explicit option boundary for unwind behavior from catch-like paths.

Beginner takeaway:

- Asyncify is not only about ordinary direct-call returns;
- exception handling can interact with unwind/rewind state;
- Binaryen does not leave that interaction implicit.

Advanced takeaway:

- future Starshine parity tests should include an EH/catch fixture after the scalar direct-call and local-save cases are stable;
- this should be tested separately from ordinary typechecking of `try` / `catch` / `try_table` syntax;
- if a first local port rejects EH input, it should reject it deliberately and document the subset instead of accidentally producing a half-instrumented module.

## Tail-call boundary

The reviewed Binaryen path rejects tail calls for Asyncify.
This is not a tiny missing rewrite: tail calls remove the ordinary “return to this call site and continue” shape that the rewind path depends on.

A future local implementation should choose one explicit behavior:

- reject `return_call` / `return_call_indirect` inputs under `asyncify`; or
- implement a source-backed tail-call strategy after re-auditing upstream.

Silently treating tail calls like ordinary calls is the dangerous option.

## `mod-asyncify-*` helpers are siblings, not the main pass

`Asyncify.cpp` also contains helper passes that simplify known Asyncify-state checks under configured assumptions.
Those helpers matter for reading upstream source, but they should not confuse the pass map:

- `asyncify` creates the state machine and instrumentation;
- `mod-asyncify-*` helpers can simplify after the state behavior is known;
- Starshine currently implements neither family.

If Starshine ever ports the main pass, helper-pass support can be a separate follow-up unless parity requires exact helper scheduling.

## Starshine implementation implications

A faithful local port needs module-level infrastructure, not a HOT-only visitor:

- registry and option surface for Asyncify-specific lists and memory choices;
- module callgraph and import/export analysis;
- indirect-call policy and call-site identity bookkeeping;
- memory/global/export/function synthesis;
- liveness or equivalent proof for locals saved across pausing calls;
- validation after adding helpers and rewritten bodies;
- execution test harness for host-driven unwind/rewind.

Until those pieces exist, the correct Starshine status remains unknown-pass with reusable prerequisites, not a partially implemented local pass.

## Sources

- [`../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md`](../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md)
- [`../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md`](../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md)
- [`../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md`](../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md)
- Binaryen current `Asyncify.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp>
- Binaryen current `asyncify.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast>
- Emscripten Asyncify docs: <https://emscripten.org/docs/porting/asyncify.html>
