# WebAssembly Proposal Status Current Recheck (2026-06-04)

- Source family: official WebAssembly Core specification, WebAssembly proposals tracker, WebAssembly CG process notes, and current Starshine generator-feature vocabulary.
- Capture date: 2026-06-04 (local project date).
- Reason for capture: recheck the shared feature-status page after the active proposals tracker drifted since the earlier 2026-06-04 source bridge, especially around proposal phase placement and the newly visible `Relaxed Atomics` active-proposal row.
- Status: immutable primary-source bridge. This file supplements [`2026-06-04-webassembly-proposal-status-refresh.md`](2026-06-04-webassembly-proposal-status-refresh.md); it does not supersede focused feature pages for strings, threads/atomics, SIMD, custom descriptors, validation, or external validator behavior.

## Primary sources checked

1. WebAssembly Core Specification, Release 3.0 (`2026-06-04`): <https://webassembly.github.io/spec/core/>.
2. WebAssembly proposals repository README, active proposals table, checked 2026-06-04: <https://github.com/WebAssembly/proposals>.
3. WebAssembly finished proposals table, checked 2026-06-04: <https://github.com/WebAssembly/proposals/blob/main/finished-proposals.md>.
4. WebAssembly proposal process document, checked 2026-06-04: <https://github.com/WebAssembly/meetings/blob/main/process/phases.md>.
5. Relaxed Atomics proposal repository README, checked 2026-06-04: <https://github.com/WebAssembly/relaxed-atomics>.
6. Local Starshine generator-feature vocabulary in [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt).

## Current source facts

- The official generated Core page now identifies the live Core 3.0 draft as `Release 3.0 (2026-06-04)`. Older raw notes that cite the 2026-06-03 generated pages remain useful for the page-specific rule checks they captured, but new shared feature-status claims should cite this current Core page when only the release snapshot date matters.
- The proposals README currently lists active proposals in Phase 4, Phase 3, Phase 2, and Phase 1 buckets. The Phase 2 bucket includes `Relaxed Atomics` with champions Conrad Watt and Rezvan Mahdavi Hezaveh. The proposal's own README describes it as a proposal repository for adding relaxed atomics support to WebAssembly.
- `Relaxed Atomics` is distinct from finished/Core `Relaxed SIMD` and distinct from the existing threads/linear-memory atomics surface that Starshine already models. Do not route a relaxed-atomics claim through `RelaxedSimdFeature`, and do not imply Starshine supports relaxed-atomics opcodes or memory-order variants without local AST/binary/validator/generator evidence.
- The finished-proposals table still lists `Relaxed SIMD` as Core 3.0, along with other Core 3.0 families relevant to Starshine such as tail calls, typed function references, garbage collection, multiple memories, exception handling, JS string builtins, and memory64.
- The process document and proposals README use closely related but not identical wording for phases: the process page describes Phase 2 as a feature-description stage, while the proposals README heading says proposed spec text is available. For wiki purposes, cite the proposals README when naming the current active-proposal row, and cite the process document when explaining what phase advancement means.
- Starshine's current `GenValidProposalFeature` enum still has `RelaxedSimdFeature` and `AtomicsFeature`, but no separate `RelaxedAtomicsFeature`. `AtomicsFeature` is gated by ordinary memory/shared-memory/atomics toggles and should remain the current linear-memory atomics coverage vocabulary unless a focused relaxed-atomics slice lands.

## Starshine interpretation rules

1. Treat `Relaxed Atomics` as an active proposal, not a finished/Core 3.0 feature and not a synonym for relaxed SIMD.
2. Keep the existing Starshine atomics page scoped to current linear-memory atomics plus `atomic.fence`, with a cross-link caveat that relaxed atomics would need new source, opcode, validator, generator, and pass-effect evidence.
3. Keep `RelaxedSimdFeature` and relaxed-SIMD generator profiles tied to relaxed SIMD only. Do not use them as a proxy for relaxed atomics.
4. When a future tool, Binaryen source, or external validator accepts relaxed-atomics syntax/bytes, classify it through the feature-status and external-validator adapter ladder before calling it a Starshine bug.
5. If a future Starshine slice introduces relaxed atomics, update this bridge's living dependents: [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md), [`../../wast/atomic-memory-instruction-authoring.md`](../../wast/atomic-memory-instruction-authoring.md), [`../../fuzzing/generator-coverage-ledger.md`](../../fuzzing/generator-coverage-ledger.md), and the exact implementation/tests.

## Durable conclusion

The highest-value wiki change from this recheck is not a broad rewrite of every 2026-06-03 Core-page citation. It is a focused routing correction: the shared feature-status page should now name `Relaxed Atomics` as an active Phase-2 proposal and explicitly keep it separate from both stable relaxed SIMD and Starshine's current ordinary atomics support.
