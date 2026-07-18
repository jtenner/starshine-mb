---
kind: entity
status: supported
starshine_status: upstream-only
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SafeHeap.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/safe-heap_no-shared.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/safe-heap-start-import.wast
  - ../../../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md
  - ../../../../../src/passes/optimize.mbt
related:
  - ../tracker.md
  - ../index.md
  - ../../release-horizon-and-oracles.md
  - ../../../wast/atomic-memory-instruction-authoring.md
---

# `safe-heap`

## Status

`safe-heap` is a public explicit Binaryen instrumentation pass. Binaryen registers the exact CLI spelling `safe-heap`, but does not schedule it in the default optimize or shrink pipeline.

Starshine has no registry spelling, implementation, or compare-pass admission for this pass. Treat it as **upstream-only**, not as an O4z blocker.

## What the pass does

The pass instruments ordinary linear-memory `Load` and `Store` nodes, including scalar and enabled `v128` forms, so invalid heap behavior is checked through generated helper functions. Its source-level intent covers:

- null-pointer access;
- access past the current `sbrk()`-managed heap top;
- pointer-plus-offset wraparound;
- declared alignment that the runtime address does not satisfy.

It imports or reuses Emscripten-facing helpers such as `emscripten_get_sbrk_ptr`, `segfault`, and `alignfault`, rewrites original loads/stores into calls, and synthesizes `SAFE_HEAP_LOAD_*` / `SAFE_HEAP_STORE_*` functions containing the checks plus the real memory operation.

This is behavior-changing instrumentation, not an optimization. The pass reports `addsEffects()` because rewritten accesses become calls and fault paths.

## Released v131 atomic correction

V131 removes an incorrect shared-memory prerequisite from atomic helper generation.

The released rule is:

- atomics must be enabled in the module feature set;
- the access type must be integer;
- declared alignment must equal access width;
- the memory itself does **not** need to be declared shared.

The dedicated `safe-heap_no-shared.wast` fixture enables threads, declares an ordinary non-shared memory, and proves that `i32.atomic.load` and `i32.atomic.store` are routed through sequentially-consistent SafeHeap helpers. This aligns helper generation with Binaryen's accepted atomic IR rather than using the memory declaration's `shared` bit as a second gate.

Relaxed Atomics expands helper generation from unordered plus sequential consistency to include acquire-release ordering. Signed atomic loads remain implemented by an unsigned atomic load followed by explicit sign extension.

## Pipeline and validity boundaries

- The module must have at least one memory; the implementation asserts that prerequisite.
- Address calculations use the first memory's address type, so memory64 changes helper signatures and pointer constants.
- The module start function's transitive direct-call reachability closure, plus the selected `getSbrkPtr` function, is excluded from instrumentation because startup code may initialize passive segments before the `sbrk` state is usable.
- The pass instruments ordinary `Load` and `Store` IR, including enabled `v128` loads/stores. It is not a generic sanitizer for bulk memory, specialized SIMD memory instructions represented outside those nodes, or GC heap accesses.
- Existing helper imports/exports may be reused; otherwise the pass adds imports and functions, so function/type/index repair and effect analysis matter.

## Test surface

The v131 lit family includes:

- `safe-heap-start-import.wast` for startup/import exclusion;
- `safe-heap_no-shared.wast` for the released non-shared atomic path;
- threads/SIMD and SIMD64 matrices;
- relaxed-atomics variants;
- a low-memory-unused variant.

The generated expected files are large because the pass synthesizes a helper matrix across scalar/v128 widths, signedness, alignments, memory orders, and address widths. A future Starshine port should test helper selection and runtime fault semantics directly rather than treating output size as optimization evidence.

## Future Starshine rule

Do not reserve or schedule this pass casually. A faithful first slice needs:

1. an explicit instrumentation-pass registry category and CLI policy;
2. import/function/type synthesis with deterministic names;
3. scalar memory32 helpers and execution tests for null, bounds, wraparound, and alignment faults;
4. memory64 signatures;
5. v131 atomic helper selection on both shared and non-shared memories;
6. start-reachability exclusion;
7. validation and effect-cache invalidation tests.

Ordinary compare-pass canonical-Wasm equality is not enough on its own: signoff must also execute representative valid and faulting accesses and verify the expected host callbacks.
