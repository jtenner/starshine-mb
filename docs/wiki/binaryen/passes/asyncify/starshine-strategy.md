---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-26-asyncify-port-readiness-primary-sources.md
  - ../../../raw/research/0401-2026-04-26-asyncify-port-readiness.md
  - ../../../raw/binaryen/2026-05-05-asyncify-current-main-recheck.md
  - ../../../raw/research/0445-2026-05-05-asyncify-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md
  - ../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md
  - ../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md
  - ../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./state-machine-memory-and-eh-boundaries.md
  - ./starshine-port-readiness-and-validation.md
  - ../i64-to-i32-lowering/index.md
  - ../legalize-js-interface/index.md
  - ../memory64-lowering/index.md
---

# Starshine strategy for `asyncify`

## Current status

Starshine does **not** currently implement Binaryen's `asyncify` pass.

The local status is stronger than ordinary “not ported”:

- `src/passes/optimize.mbt` contains no registry entry for `asyncify`;
- the pass is therefore not `HotPass`, `ModulePass`, `Removed`, or `BoundaryOnly` in the current registry vocabulary;
- explicit requests hit the generic unknown-pass path today;
- no owner file, dispatch case, preset slot, parity page, or active backlog slice was found in this run.

So today's correct user-facing description is:

> Starshine can represent the Wasm primitives a future Asyncify port would need, but it has no Asyncify analysis, instrumentation, runtime API synthesis, or host-integration test harness today.

## Existing local prerequisite surfaces

### Registry and request behavior

- `src/passes/optimize.mbt:128-154`
  - boundary-only and removed-name lists do not include `asyncify`.
- `src/passes/optimize.mbt:158-252`
  - active `HotPass`, `ModulePass`, and preset entries do not include `asyncify`.
- `src/passes/optimize.mbt:455-459`
  - an unregistered explicit `--pass asyncify` request follows the generic `unknown pass flag asyncify` path.

### Module model

- `src/lib/types.mbt:351` defines the core `Module` structure.
- `src/lib/types.mbt:224` defines `Global` and `src/lib/types.mbt:442` defines `GlobalSec`, which a future port would need for `__asyncify_state` / `__asyncify_data`-style globals.
- `src/lib/types.mbt:515` starts the central `Instruction` enum.
- `src/lib/types.mbt:516` includes `Unreachable`.
- `src/lib/types.mbt:527` / `528` include `Call` and `CallIndirect`.
- `src/lib/types.mbt:529` / `530` include `ReturnCall` and `ReturnCallIndirect`, which matter because Binaryen's reviewed Asyncify path rejects tail calls.
- `src/lib/types.mbt:540` includes `GlobalSet`.
- `src/lib/types.mbt:567` includes `MemoryGrow`.

These are prerequisites, not an implementation.
Asyncify needs a whole-module rewrite that can add globals, exports, memory traffic, helper functions, and call-site control flow coherently.

### WAT syntax and lowering

- `src/wast/types.mbt` includes opcode-level variants for `Unreachable`, calls, globals, and memory operations.
- `src/wast/keywords.mbt` maps text instructions such as `unreachable`, `call_indirect`, `global.set`, `memory.size`, and `memory.grow`.
- `src/wast/parser.mbt` parses module-level memory/global/function fields and relevant instructions.
- `src/wast/lower_to_lib.mbt` lowers parsed WAT into `@lib.Module` / `@lib.Instruction` surfaces.

A future port can build fixtures in WAT, but it will need module-level output comparison rather than only HOT-region snippets.

### Binary encode/decode

- `src/binary/encode.mbt:1500` and nearby data/memory section encoders are relevant if Asyncify creates or rewrites memory/data surfaces.
- `src/binary/encode.mbt:1933` encodes `Unreachable`.
- `src/binary/encode.mbt:2002` / `2008` encode direct and indirect calls.
- `src/binary/encode.mbt:2088` encodes `GlobalSet`.
- `src/binary/encode.mbt:2250` encodes `MemoryGrow`.
- `src/binary/decode.mbt:2432` decodes `Unreachable`.
- `src/binary/decode.mbt:2541` / `2548` decode direct and indirect calls.
- `src/binary/decode.mbt:2753` / `2758` decode memory size/grow.

### Validation

- `src/validate/env.mbt:715` collects module globals into the validation environment.
- `src/validate/typecheck.mbt:572` checks `global.set` mutability.
- `src/validate/typecheck.mbt:2408` and `2417` typecheck memory size/grow.
- `src/validate/typecheck.mbt:3070` handles `Unreachable`.
- `src/validate/typecheck.mbt:3216` and `3219` typecheck indirect call and return-call-indirect.

Asyncify's output must validate after adding helper functions, globals, memory traffic, and exports.
A port should treat validation as a first-class implementation constraint, not a late cleanup step.

## Future implementation shape

A faithful Starshine port should be a module pass, not a HOT peephole pass.
It needs to:

1. reserve or register the pass name if/when implementation begins;
2. model Asyncify pass options and user lists;
3. build a module callgraph that includes direct calls, indirect-call conservatism, imports, exports, and forced add/remove/only decisions;
4. reject or explicitly handle tail-call inputs;
5. support or deliberately reject exception/catch unwind behavior;
6. choose or create Asyncify memory and pointer width;
7. add state/data globals and exported runtime API functions;
8. instrument relevant call sites with normal/unwind/rewind state checks;
9. save and restore live locals across relevant calls;
10. run validation and targeted cleanup;
11. add a host-level integration test for real pause/resume behavior.

## Why this should not be squeezed into existing passes

Several Starshine passes already touch adjacent surfaces:

- [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md) rewrites ABI and integer-width surfaces;
- [`../legalize-js-interface/index.md`](../legalize-js-interface/index.md) covers JS-boundary legalization;
- [`../memory64-lowering/index.md`](../memory64-lowering/index.md) covers memory/table address-width lowering;
- active local passes know how to inspect calls and globals.

None of those passes owns continuation-like pause/resume semantics.
Asyncify needs a dedicated owner because the correctness story spans callgraph analysis, live locals, memory-backed state, runtime exports, and host cooperation.

## Candidate tests for a Starshine port

Use [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) as the fuller validation ladder. The short checklist is:

- `--pass asyncify` is accepted only after the pass exists, or remains explicitly unknown/boundary-only.
- A direct async import creates the runtime API exports.
- A transitive caller is instrumented.
- A function outside the async closure remains unchanged.
- A conservative indirect call is instrumented.
- User-list options can prune and force instrumentation.
- A live scalar local is saved/restored.
- Reference and multivalue local cases are added after scalar proof.
- No-memory input receives a valid memory when configured that way.
- Memory64 input uses `i64` pointers.
- EH/catch input either matches Binaryen's source-backed option behavior or is rejected as an explicit first-port subset.
- Tail calls are rejected with a clear diagnostic.
- A host integration fixture proves one unwind/rewind round trip.

## Current uncertainty

- No local backlog slice currently decides whether `asyncify` should be tracked as `BoundaryOnly`, `Removed`, or remain unknown until an implementation is planned.
- The Binaryen helper-pass family `mod-asyncify-*` is intentionally not mapped to Starshine registry decisions here.
- Host integration will require more than ordinary normalized-WAT compare; a future implementation needs an execution harness.

## Sources

- [`../../../raw/binaryen/2026-04-26-asyncify-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-asyncify-port-readiness-primary-sources.md)
- [`../../../raw/research/0401-2026-04-26-asyncify-port-readiness.md`](../../../raw/research/0401-2026-04-26-asyncify-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md`](../../../raw/binaryen/2026-04-25-asyncify-current-main-and-eh-options.md)
- [`../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md`](../../../raw/binaryen/2026-04-24-asyncify-primary-sources.md)
- [`../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md`](../../../raw/research/0371-2026-04-25-asyncify-current-main-and-eh-options.md)
- [`../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md`](../../../raw/research/0323-2026-04-24-asyncify-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- [`../../../../../src/wast/types.mbt`](../../../../../src/wast/types.mbt)
- [`../../../../../src/wast/parser.mbt`](../../../../../src/wast/parser.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
