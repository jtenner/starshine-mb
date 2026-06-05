# WebAssembly Active Proposal Routing Current Refresh (2026-06-04)

- Source family: official WebAssembly Core 3.0 spec, official proposals tracker, finished-proposals table, proposal process document, focused proposal repositories, and Starshine generator feature vocabulary.
- Capture date: 2026-06-04 (local project date).
- Reason for capture: add a durable routing snapshot for active proposals beyond the earlier relaxed-atomics-only correction, so living wiki pages can distinguish stable Core 3.0 features, finished proposals, active proposal rows, and Starshine-local generator gates without treating the proposals tracker as a local implementation map.
- Status: immutable primary-source bridge. This supplements [`2026-06-04-webassembly-proposal-status-current-recheck.md`](2026-06-04-webassembly-proposal-status-current-recheck.md) and [`2026-06-04-webassembly-proposal-status-refresh.md`](2026-06-04-webassembly-proposal-status-refresh.md); focused feature pages remain canonical for implementation details.

## Primary sources checked

1. WebAssembly Core Specification, Release 3.0 (`2026-06-04`): <https://webassembly.github.io/spec/core/intro/introduction.html>.
2. WebAssembly proposals repository README, active proposals table, checked 2026-06-04: <https://github.com/WebAssembly/proposals>.
3. WebAssembly finished proposals table, checked 2026-06-04: <https://github.com/WebAssembly/proposals/blob/main/finished-proposals.md>.
4. WebAssembly proposal process document, checked 2026-06-04: <https://github.com/WebAssembly/meetings/blob/main/process/phases.md>.
5. Relaxed Atomics proposal repository README, checked 2026-06-04: <https://github.com/WebAssembly/relaxed-atomics>.
6. Custom Descriptors proposal repository README, checked 2026-06-04: <https://github.com/WebAssembly/custom-descriptors>.
7. Local Starshine generator-feature vocabulary in [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt).

## Current source facts

- The official Core introduction identifies the live Core 3.0 document as version `3.0 (2026-06-04)` and says future incremental releases may supersede it. Treat this as the current stable Core citation when a focused page only needs the shared release date.
- The finished-proposals table says finished proposals have reached Phase 4 and are included in the latest draft spec. Current Core 3.0 rows relevant to Starshine include tail calls, extended constant expressions, typed function references, garbage collection, multiple memories, relaxed SIMD, custom annotation syntax in the text format, branch hinting, exception handling, JS string builtins, and memory64.
- The active proposals README currently has empty Phase 5 rows and non-empty Phase 4, 3, 2, and 1 buckets. Phase 4 contains Threads, JS Promise Integration, and Web Content Security Policy. Phase 3 contains ESM Integration, Wide Arithmetic, Stack Switching, Compact Import Section, Custom Page Sizes, and Custom Descriptors and JS Interop. Phase 2 contains Relaxed dead code validation, Numeric Values in WAT Data Segments, Extended Name Section, Rounding Variants, Compilation Hints, JS Primitive Builtins, and Relaxed Atomics. Phase 1 contains Type Imports, Component Model, WebAssembly C and C++ API, Flexible Vectors, Memory control, Reference-Typed Strings, Profiles, Shared-Everything Threads, Frozen Values, Half Precision, More Array Constructors, JIT Interface, Multibyte Array Access, Type Reflection for the WebAssembly JavaScript API, and JS Text Encoding Builtins.
- The process document describes Phase 1 as feature proposal, Phase 2 as feature description available, Phase 3 as implementation phase, Phase 4 as standardize the feature, and Phase 5 as standardized. The proposals README heading for Phase 2 uses a stronger shorthand (`Proposed Spec Text Available`) than the process page. For wiki wording, use the tracker for current row placement and the process document for phase meaning.
- The Relaxed Atomics repository is a fork/proposal for relaxed atomics support. It is separate from finished/Core relaxed SIMD and separate from Starshine's current ordinary `AtomicsFeature` gate.
- The Custom Descriptors repository describes the proposal as custom descriptors and JS interop for Wasm GC structs. This supports the existing wiki rule that proposal evidence is struct-oriented; Starshine-local array descriptor metadata parsing/lowering must remain labeled local unless future primary sources broaden the proposal.
- Starshine's `GenValidProposalFeature` enum currently contains gates for feature families such as GC, function references, tail calls, exceptions, SIMD, relaxed SIMD, ordinary atomics, bulk memory, multi-memory, memory64, extended const, and reference types. It does not contain feature rows for active proposals such as relaxed atomics, custom page sizes, wide arithmetic, stack switching, component model, reference-typed strings as a full proposal, shared-everything threads, or custom descriptors.

## Starshine interpretation rules

1. Do not treat active proposal rows as local implementation evidence. Every local claim still needs code, tests, generator facts, Binaryen/source-oracle evidence, or a focused wiki page.
2. Use the proposals tracker as the current status authority for active proposal phase placement, but use the focused proposal repository for proposal-specific semantics and use the Core 3.0 pages or finished-proposals table for stable Core claims.
3. Keep `GenValidProposalFeature` labels scoped as local fuzz/generator vocabulary. Existing gates can refer to stable/finished feature families (`gc`, `tail-calls`, `memory64`, etc.) without proving active-proposal coverage for similarly named newer proposals.
4. Treat Phase 4 rows as not-yet-merged active proposals until the finished-proposals table or Core pages say otherwise.
5. For proposal families that Starshine partially mirrors locally, preserve layer splits: `string.const` and string helpers are a narrow local/reference-typed-strings subset, custom-descriptor descriptor metadata is struct-proposal-facing plus Starshine-local array metadata, ordinary atomics are not relaxed atomics, and shared-GC atomics are not the full shared-everything threads proposal.

## Durable conclusion

The living feature-status page should keep its compact high-value table, but it also needs a short active-proposal routing snapshot so maintainers do not infer unsupported proposal coverage from local generator gates or from Core 3.0 features with similar names. The highest-value additions are: Phase 4 rows are still active, Phase 3 contains Custom Descriptors alongside other not-yet-Core proposals, Phase 2 contains Relaxed Atomics and Compilation Hints, and Phase 1 contains Reference-Typed Strings plus Shared-Everything Threads and the Component Model.
