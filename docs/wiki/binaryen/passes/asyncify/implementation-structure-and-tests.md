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
  - ./wat-shapes.md
  - ./state-machine-memory-and-eh-boundaries.md
  - ./starshine-strategy.md
---

# `asyncify` implementation structure and tests

## Upstream owner files

### `src/passes/Asyncify.cpp`

This is the real implementation owner for `version_129` `asyncify`.
It contains several teaching-relevant layers:

- file-level design comments for the state machine and stack-data layout;
- `ModuleAnalyzer`, which marks functions that may change Asyncify state;
- `AsyncifyFlow`, which instruments relevant direct and indirect call sites;
- local-use / save-restore logic inside the same owner file, which stores/restores locals live across pausing call sites;
- the top-level `Asyncify` pass, which wires memory/global/runtime helper creation, exception/catch option behavior, and nested pass execution;
- `ModAsyncify`, the related helper-pass family that simplifies state checks under known assumptions.

The important source-navigation warning is that `Asyncify.cpp` is not one simple visitor.
It is a mini pipeline.
Future readers should start with the top-level `Asyncify::run(...)` flow, then read the analysis and instrumentation classes in dependency order.

### `src/passes/pass.cpp`

`pass.cpp` gives `asyncify` its public CLI/pass identity.
The same registration table also places nearby JS/ABI passes such as `jspi` and `legalize-js-interface`, which is useful context: `asyncify` is part of the broad host-integration / async-boundary family, not the no-DWARF local-optimizer queue.

### `src/passes/passes.h`

`passes.h` declares `createAsyncifyPass()`.
Use it only to confirm public constructor presence; the behavior lives in `Asyncify.cpp`.

## Helper concepts to recognize

### `ModuleAnalyzer`

Reads the module-level call graph and configuration lists.
Its job is to avoid instrumenting functions that provably cannot unwind or rewind while still staying conservative around imports and indirect calls.

### `AsyncifyFlow`

Rewrites function bodies around relevant calls.
It inserts state checks and control-flow branches that distinguish normal execution, unwinding, and rewinding.
It also handles call-index bookkeeping for indirect calls.

### Local save/restore logic inside `Asyncify.cpp`

Determines which locals must survive across a relevant call and emits memory traffic to save and restore them.
The 2026-04-25 source bridge corrected the older page wording: treat this as part of the `Asyncify.cpp` mini-pipeline rather than a separately named `AsyncifyLocals` owner.
This logic is where Asyncify becomes more than a call wrapper: live local state is part of the continuation.

### Runtime API synthesis

The pass adds exported functions for starting/stopping unwind and rewind plus state querying.
Those functions are the boundary the host runtime uses.

## Official test surface

### `test/lit/passes/asyncify.wast`

This is the central Binaryen lit file for the main pass.
It is the best first fixture for a future Starshine compare lane because it shows:

- runtime helper exports;
- state/data globals;
- direct-call instrumentation;
- representative local save/restore traffic;
- indirect-call behavior;
- option/list-sensitive instrumentation differences;
- exception/catch behavior and option-sensitive EH output families.

The file is broad enough to teach the transform but should not be treated as one-test-per-source-branch coverage for every helper class.
For exact branch coverage, pair it with source review.

## What the tests prove well

The official lit surface is good evidence that:

- `asyncify` is observable as a public pass;
- transformed output gains the runtime API surface;
- calls on async-reachable paths gain state checks;
- live locals can be stored and loaded through the Asyncify data area;
- configuration can shrink or widen the instrumented function set.

The 2026-05-05 current-main recheck did not change any of these source-navigation takeaways.

## What requires source review

Use `Asyncify.cpp` rather than the lit output alone for:

- the exact analysis roots and user-list precedence;
- the nested pass ordering;
- tail-call rejection;
- exception/catch unwind behavior and options;
- memory creation/selection and pointer-width choice;
- the distinction between main `asyncify` and `mod-asyncify-*` helpers;
- current helper API details such as `asyncify_get_state`.

## Suggested Starshine test map

A future local port should not start by trying to match the full generated `asyncify.wast` output exactly.
A safer sequence is:

1. registry/request tests for the chosen local pass status;
2. a tiny imported async root that instruments only one caller;
3. a transitive direct-call chain;
4. a negative function outside the async closure;
5. an indirect-call conservative positive;
6. local save/restore around an `i32` local;
7. multi-value and reference locals only after scalar proof is stable;
8. no-memory input that receives a memory;
9. memory64 input with `i64` Asyncify pointers;
10. EH/catch behavior or deliberate subset rejection;
11. tail-call rejection fixture;
12. host integration fixture that proves real pause/resume.

## Sources

- [`../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md`](../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md)
- [`../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md`](../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md)
- [`../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md`](../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md)
- [`../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md`](../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md)
- Binaryen `Asyncify.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Asyncify.cpp>
- Binaryen current `Asyncify.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Asyncify.cpp>
- Binaryen `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Binaryen `asyncify.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/asyncify.wast>
- Binaryen current `asyncify.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/asyncify.wast>
