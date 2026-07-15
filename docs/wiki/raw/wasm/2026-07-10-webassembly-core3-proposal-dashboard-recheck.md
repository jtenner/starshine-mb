# WebAssembly Core 3.0, Proposal Tracker, And Feature Dashboard Recheck

- Capture date: 2026-07-10
- Source family: official WebAssembly Core specification, official proposal tracker, and WebAssembly feature-status dashboard
- Reason for capture: refresh the shared standards-status date anchor and preserve the evidence boundary between Core/specification status, active-proposal phases, and browser/runtime implementation availability.
- Status: immutable primary-source bridge. This supersedes the **shared date and dashboard-routing role** of the June 2026 status snapshots; focused proposal bridges remain the authority for feature-specific syntax, binary, validation, and Starshine-support claims.

## Primary sources checked

1. WebAssembly Core Specification, Introduction, checked 2026-07-10: <https://webassembly.github.io/spec/core/intro/introduction.html>
2. WebAssembly proposals tracker README, checked 2026-07-10: <https://github.com/WebAssembly/proposals>
3. WebAssembly feature-status dashboard, checked 2026-07-10: <https://webassembly.org/features/>
4. Earlier Starshine source bridge for historical context:
   - [`2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](2026-06-04-webassembly-active-proposal-routing-current-refresh.md)

## Durable takeaways

- The live official Core introduction identifies the document as **WebAssembly 3.0 (2026-07-10)**. It defines the core ISA layer—text/binary format, validation, and execution semantics—and explicitly leaves environment-specific interaction and invocation to embedding/API documents. A later page must not infer a new Core feature merely from the changed document date.
- The proposals tracker remains the current source for active-proposal placement. Its relevant rows still place Threads and JS Promise Integration in Phase 4; ESM Integration, Wide Arithmetic, Stack Switching, Custom Page Sizes, and Custom Descriptors and JS Interop in Phase 3; Relaxed Dead Code Validation, Numeric Values in WAT Data Segments, Extended Name Section, Compilation Hints, JS Primitive Builtins, and Relaxed Atomics in Phase 2; and Component Model, Memory Control, Reference-Typed Strings, Shared-Everything Threads, More Array Constructors, and JS Text Encoding Builtins in Phase 1.
- The tracker states that Phase 5 proposals have not yet been merged into the specification and directs readers to the finished-proposals table for merged work. Therefore, a Phase 4 row remains active-proposal evidence until a Core or finished-proposals source says otherwise.
- The feature dashboard explicitly directs readers to the proposals tracker for current proposal stages and says that its own table tracks implemented features in popular engines and tools. It is an implementation-availability hint, not the authority for standards status, Starshine support, or a particular `wasm-tools`, WABT, Binaryen, Node, or browser command result.

## Starshine interpretation rules

1. Use this note for the current shared Core date anchor and the standards-status/evidence-tier distinction.
2. Use the Core specification or finished-proposals table for finished/Core claims, the proposal tracker plus focused proposal sources for active-proposal claims, and Starshine source/tests for local implementation claims.
3. Keep embedding proposals such as JSPI and ESM Integration separate from the Core ISA. The Core introduction's scope statement is not proof that Starshine has or lacks any embedding API.
4. Keep June source notes as historical, feature-specific evidence. This note does not silently revalidate their detailed instruction, binary, validator, WAST, generator, or pass claims.

## Supersession and uncertainty

- The live Core document date changed from the June snapshots to 2026-07-10. The update refreshes the shared date anchor only; it does not itself change any finished/Core feature inventory.
- The proposal rows listed above were rechecked on 2026-07-10 and match the focused living-page classifications. Recheck the tracker and the feature-specific proposal repository before changing a proposal's semantics or Starshine's support map.
- The feature dashboard requires JavaScript to display its detailed table in many clients. Its own prose is sufficient to establish the evidence-tier boundary, but not to make feature-by-feature engine-support assertions in this wiki.
