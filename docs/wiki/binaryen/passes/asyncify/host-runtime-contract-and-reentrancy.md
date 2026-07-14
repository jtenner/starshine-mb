---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-asyncify-current-main-host-runtime-refresh.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./index.md
  - ./state-machine-memory-and-eh-boundaries.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../wasm-jspi-host-async-boundary.md
  - ../../../tooling/pass-fuzz-compare.md
---

# `asyncify` host-runtime contract and reentrancy boundary

## Why a compiler-only description is incomplete

WebAssembly code does not suspend an ordinary call stack by itself. Binaryen `asyncify` changes selected functions so that a cooperating host/runtime can:

1. begin an ordinary Wasm entry call;
2. request an **unwind** when an async-capable operation is reached;
3. let instrumented frames save the state needed to return to the host boundary; and later
4. start a **rewind** and re-enter the saved computation.

The generated helpers, globals, memory traffic, and call-site checks are the module half of that protocol. The host must drive the other half. A static WAT diff can prove that a pass emitted plumbing; it cannot prove that the plumbing resumes the right frame with the right local values.

This is distinct from [JavaScript Promise Integration](../../../wasm-jspi-host-async-boundary.md): Asyncify is a generated Core-Wasm state machine, while JSPI is a JavaScript embedding API. Neither implies support for the other.

## Conceptual lifecycle

The exact Binaryen output contains additional blocks, labels, and stack-pointer bookkeeping, but the observable protocol is easier to reason about in phases:

| Phase | Wasm-side responsibility | Host/runtime responsibility | Minimum proof |
| --- | --- | --- | --- |
| normal entry | execute ordinary calls; leave Asyncify state inactive | call an exported entry point | result/effects match the untransformed module when no async root unwinds |
| unwind request | recognize a relevant call, save live state, and return through instrumented callers | arrange that the async root signals an unwind and receives control at the module boundary | a direct async-root fixture reaches the host without executing post-call code too early |
| paused period | preserve saved data and do not corrupt the Asyncify stack area | complete or await the host operation | saved-memory data remains available and isolated from the host's own stack policy |
| rewind entry | reload state and skip already-replayed call sites until the target continuation is reached | start rewind and re-enter the appropriate Wasm entry path | a local live across the call has its original value after resumption |
| normal completion | stop treating the frame as rewinding and return normally | observe final result/side effects | one end-to-end result matches the synchronous reference behavior |

The runtime helper exports (`asyncify_start_unwind`, `asyncify_stop_unwind`, `asyncify_start_rewind`, `asyncify_stop_rewind`, and `asyncify_get_state`) are therefore protocol endpoints, not incidental implementation names. See [the state-machine guide](state-machine-memory-and-eh-boundaries.md) for their compiler-side representation.

## Configuration is part of semantics

Emscripten documents Asyncify configuration that selects or prunes the asynchronous closure, including import and add/remove/only-style controls. Those settings are not mere performance toggles:

- **too narrow** a set can leave a caller unprepared to unwind;
- **too broad** a set can add unnecessary save/restore and control-flow overhead;
- an **indirect-call ignore** policy transfers a proof obligation to the user: ignored table calls must not reach an async-capable target;
- the Asyncify stack-size setting is a runtime-capacity choice, not a license for the compiler to omit live-local correctness.

A future Starshine port should first name its own option model and prove its exact precedence. It must not claim Emscripten setting compatibility merely because it has a similarly named pass.

## Reentrancy and nested entry are explicit design work

“Async works” is not enough acceptance language. A host may try to enter Wasm again while an Asyncify frame is unwinding or paused, or may accidentally resume the wrong exported entry point. The transform's static shape does not by itself establish a safe policy for those cases.

Before claiming support, a Starshine implementation must choose and test one policy:

- **reject** nested/reentrant entry while Asyncify state is active, with a stable diagnostic or host-side guard; or
- **support** a documented nested-entry model, including independent stack/data ownership and a proof that resumed call-site identity cannot be confused.

Do not infer either policy from the presence of Asyncify helper exports. The first local execution harness should include a negative nested-entry/reentrancy case even if the first supported implementation deliberately rejects it.

## Starshine status and validation consequences

Starshine currently has no `asyncify` registry spelling, implementation owner, dispatcher case, or host harness in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt). It is also absent from the comparison harness allowlist in [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts).

Consequently:

- `bun fuzz compare-pass --pass asyncify ...` is a harness-parser rejection, **not** a parity lane;
- a future fuzz page must remain planned-only until harness admission, an active local transform, Binaryen flag mapping, and an Asyncify-capable generator/profile all exist;
- a future implementation needs both static fixtures and a runtime integration fixture. The latter should cover one direct unwind/rewind round trip, one saved scalar local, and the chosen nested-entry policy before broader EH, memory64, or indirect-call support is claimed.

The broader implementation sequence remains in [the Starshine readiness ladder](starshine-port-readiness-and-validation.md). This page adds the host-protocol and nested-entry proof obligation that ordinary normalized-WAT comparison cannot discharge.

## Sources

- [`../../../raw/binaryen/2026-07-11-asyncify-current-main-host-runtime-refresh.md`](../../../raw/binaryen/2026-07-11-asyncify-current-main-host-runtime-refresh.md)
- [Binaryen current `Asyncify.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp)
- [Binaryen current `asyncify.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast)
- [Emscripten Asyncify guide](https://emscripten.org/docs/porting/asyncify.html)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
- [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md)
