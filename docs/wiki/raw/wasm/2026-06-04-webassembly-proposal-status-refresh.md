# WebAssembly Proposal Status And Starshine Boundary Refresh (2026-06-04)

- Source family: official WebAssembly Core specification, WebAssembly proposals repository, WebAssembly CG process notes, and current Starshine source/wiki surfaces.
- Capture date: 2026-06-04.
- Reason for capture: many wiki pages need to distinguish stable Core WebAssembly 3.0, finished proposals, active proposal drafts, Binaryen-specific surfaces, and Starshine-local compatibility features without repeating or contradicting the same status vocabulary.

## Primary Sources Checked

1. WebAssembly Core Specification Release 3.0 draft pages, dated 2026-06-03 in the generated spec site: <https://webassembly.github.io/spec/core/>.
2. WebAssembly proposals repository README, active proposals and phase tables: <https://github.com/WebAssembly/proposals>.
3. WebAssembly proposals repository, finished proposals table: <https://github.com/WebAssembly/proposals/blob/main/finished-proposals.md>.
4. WebAssembly CG process document linked from the proposals README: <https://github.com/WebAssembly/meetings/blob/main/process/phases.md>.
5. Local Starshine feature gates and proposal vocabulary in [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt).
6. Existing focused source refreshes for stringref, linear-memory threads/shared memory, custom descriptors, GC type/subtyping, SIMD, and external validator adapters under [`docs/wiki/raw/wasm/`](./).

## Current Source Facts

- The generated Core specification page is the strongest stable-core anchor for ordinary syntax, binary, validation, and execution claims. The checked pages are the 2026-06-03 Core 3.0 draft snapshot used by the recent validation/WAST refreshes.
- The proposals README separates active proposals by phase and points readers to the CG process document for phase meaning. It also links a separate finished-proposals table for work already completed or integrated into the core specification.
- The finished-proposals table is the right anchor for features that should no longer be taught as merely experimental proposal surfaces once the current Core 3.0 spec covers them. Examples visible in the checked table include memory64, multi-memory, typed function references, tail calls, exception handling, relaxed SIMD, garbage collection, extended constant expressions, annotations, JS string builtins, branch hinting, and several earlier baseline features.
- The active-proposals table still matters for Starshine surfaces that deliberately track proposal drafts. The checked table lists, among others, Threads at Phase 4, Custom Descriptors and JS Interop at Phase 3, Reference-Typed Strings at Phase 1, Shared-Everything Threads at Phase 1, and the Component Model at Phase 1.
- Proposal status is not the same as local support. Starshine can implement a narrow subset of an active proposal, lack WAST text for a stable-core feature, or expose local compatibility metadata that goes beyond the current proposal text.
- External tools can disagree because they support different feature snapshots or command-line feature defaults. The local command-harness classifier already has a `proposal-gap` bucket for that reason.

## Starshine Interpretation Rules

1. **Core 3.0 / finished proposal:** cite official Core pages first, then local source/tests for Starshine support or gaps. Do not call a Starshine gap a standards gap. Examples: ordinary `ref.test` / `ref.cast` / `br_on_*` are current official instruction families, while Starshine's high-level WAST text path still has narrower keyword/parser coverage.
2. **Active proposal:** cite the proposal or proposal-derived draft first, keep phase/status visible, and document exactly which Starshine layer is implemented. Examples: stringref literal-pool and array helper support, custom-descriptor exactness, linear-memory threads/shared-memory atomics, and shared-GC aggregate atomics.
3. **Starshine-local compatibility surface:** cite the local source and keep it separate from upstream standardization claims. Example: descriptor metadata on array type definitions is useful local coverage but should not be treated as current custom-descriptor proposal evidence while the proposal text remains struct-oriented.
4. **Binaryen oracle surface:** cite Binaryen source or release tags for optimizer behavior. Binaryen support is strong pass-oracle evidence, but it does not automatically define Starshine's WAST/parser support or stable WebAssembly status.
5. **Generator feature gates:** `GenValidProposalFeature` rows are local coverage toggles and fuzzing vocabulary, not a standards-status table. They deliberately bundle some local prerequisites, such as `allow_ref_types && allow_subtyping_topology` for GC-shaped generation or `allow_mems && allow_shared_memories && allow_atomics` for the current Starshine-valid atomics lane.

## Maintenance Notes

- Recheck the proposals README and finished-proposals table whenever a page changes a claim from “proposal/local” to “Core 3.0” or vice versa.
- Recheck the relevant focused proposal source, not just the top-level tracker, before changing instruction syntax, binary opcodes, validation rules, or execution/trap semantics.
- Keep whole-wiki wording precise: “implemented in Starshine,” “accepted by Starshine WAST,” “encoded in Starshine binary,” “validated by Starshine,” “listed in Core 3.0,” “finished proposal,” and “active proposal” are distinct claims.
- When external validators disagree, route classification through the external-validator adapter page before deciding whether the case is a Starshine bug, tool limitation, feature-default mismatch, or proposal drift.
