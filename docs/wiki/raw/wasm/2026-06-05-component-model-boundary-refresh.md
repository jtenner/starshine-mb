# Component Model Boundary Refresh (2026-06-05)

- Source family: official WebAssembly proposals tracker, official Component Model design/specification repository, user-facing Component Model documentation, and current Starshine core-module source evidence.
- Capture date: 2026-06-05 (local project date).
- Reason for capture: create a focused Starshine wiki boundary for the WebAssembly Component Model so maintainers do not confuse Component Model / WIT / Canonical ABI claims with Starshine's current Core WebAssembly module pipeline.
- Status: immutable primary-source bridge. The living page is [`../../wasm-component-model-boundary.md`](../../wasm-component-model-boundary.md); the broad feature-status router remains [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md).

## Primary sources checked

1. WebAssembly proposals repository README, active proposals table, checked 2026-06-05: <https://github.com/WebAssembly/proposals>. The table lists `Component Model` under Phase 1 / Feature Proposal.
2. WebAssembly Component Model repository README, checked 2026-06-05: <https://github.com/WebAssembly/component-model>. It is the design/specification home and says the repository contains goals, use cases, design choices, FAQ, and lower-level explainers for IDL, text format, binary format, concurrency model, and Canonical ABI; it also says a formal spec, reference interpreter, and test suite are future work.
3. Component Model MVP explainer, checked 2026-06-05: <https://github.com/WebAssembly/component-model/blob/main/design/mvp/Explainer.md>. The explainer models a top-level `(component ...)` as a sequence of component definitions, embeds Core WebAssembly modules behind `(core module ...)`, tracks component-level and core-level index spaces, and describes `lift` / `lower` Canonical ABI wrappers between core and component functions.
4. Component Model documentation, WIT reference, checked 2026-06-05: <https://component-model.bytecodealliance.org/design/wit.html>. WIT defines component interfaces and worlds; it is not a behavior language.
5. Component Model documentation, Canonical ABI, checked 2026-06-05: <https://component-model.bytecodealliance.org/advanced/canonical-abi.html>. The Canonical ABI is the shared data-layout/calling convention that lets components interoperate across language boundaries.

## Starshine repository evidence checked

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) defines a Core WebAssembly `Module` with ordinary core sections such as type, import, function, table, memory, global, export, start, element, data-count, code, data, name, custom, stringrefs, and function-annotation sections. It has no component, WIT, world, component-instance, component-function, Canonical ABI, or lift/lower model.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) decodes a Core WebAssembly module from the standard core preamble and optional core sections into `Module`; it has no component-binary dispatcher or component-section decoder.
- [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses WAST `module` commands, quoted/binary modules, `register`, `invoke`, static assertions, and Core module fields. It has no `(component ...)` command/field grammar and no WIT parser.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) exposes local generator-feature gates for Core/proposal-shaped families such as GC, function references, tail calls, exceptions, SIMD, relaxed SIMD, atomics, bulk memory, multi-memory, memory64, extended const, and reference types. There is no Component Model or WIT gate.
- A focused `src/` search for `component`, `canonical`, `wit`, and `preview2` found only unrelated uses such as canonical NaN token text and test prose; no local component model implementation surface was found.

## Durable conclusions

1. The Component Model is currently an active proposal-tracker row, not a stable Core 3.0 feature claim and not Starshine-local implementation evidence.
2. Component Model syntax and semantics are intentionally layered above Core WebAssembly modules. The proposal can embed core modules, but a component also introduces component definitions, component index spaces, instances, interfaces/worlds, and Canonical ABI lift/lower boundaries that Starshine does not model today.
3. Starshine should keep component-shaped inputs out of ordinary WAST, binary, validation, GenValid, pass-fuzz, and Node package support claims until a focused design/implementation slice adds the required representation and tests.
4. If future Starshine work targets WASI Preview 2, WIT, or component binaries, it should begin as a new boundary design rather than as a small WAST opcode widening: the first slice needs a component/WIT source format decision, binary/component decoder policy, Canonical ABI representation, validator behavior, and package/API exposure plan.
