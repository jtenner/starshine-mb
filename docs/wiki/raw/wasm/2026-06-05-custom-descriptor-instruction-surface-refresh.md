# Custom Descriptor Instruction Surface Refresh

- Capture date: 2026-06-05
- Source family: WebAssembly custom-descriptors proposal, proposals tracker, V8 bottom-input fix, and current Starshine WAST/core/binary/validator/generator evidence.
- Primary sources checked on 2026-06-05:
  - WebAssembly proposals tracker, current `main`: <https://github.com/WebAssembly/proposals>
  - WebAssembly custom-descriptors overview, current `main`: <https://raw.githubusercontent.com/WebAssembly/custom-descriptors/main/proposals/custom-descriptors/Overview.md>
  - WebAssembly/custom-descriptors issue #48, `ref.get_desc in dead code`: <https://github.com/WebAssembly/custom-descriptors/issues/48>
  - V8 commit `f52d915ff72fb8771263a0baa1c6f9ce936a7d29`, `[wasm-custom-desc] Fix ref.get_desc for none/bottom inputs`: <https://chromium.googlesource.com/v8/v8.git/+/f52d915ff72fb8771263a0baa1c6f9ce936a7d29%5E%21/>
- Local Starshine sources checked:
  - `src/wast/keywords.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/module_wast.mbt`
  - `src/lib/types.mbt`, `src/binary/decode.mbt`, `src/binary/encode.mbt`, `src/binary/tests.mbt`
  - `src/validate/env.mbt`, `src/validate/typecheck.mbt`, `src/validate/typecheck_negative_tests.mbt`, `src/validate/match.mbt`, `src/validate/gen_valid.mbt`, `src/validate/validate.mbt`

## Current official/proposal takeaways

- The WebAssembly proposals tracker still lists **Custom Descriptors and JS Interop** under Phase 3, so descriptor instructions remain active proposal material rather than stable Core WebAssembly 3.0.
- The proposal overview remains struct-oriented. `descriptor` and `describes` clauses are restricted to struct type definitions for now, while the proposal explicitly leaves possible relaxation to the future.
- Descriptor metadata is type identity. A described struct's `descriptor` clause and the descriptor struct's `describes` clause must agree, descriptor chains must not be cyclic, and descriptor/supertype relationships add subtype-side constraints.
- Descriptor-bearing structs cannot be allocated with ordinary `struct.new` or `struct.new_default`. The proposal-owned forms are `struct.new_desc` and `struct.new_default_desc`, with a nullable exact descriptor reference as the last operand and an exact described-struct reference as the result.
- `ref.get_desc` consumes a reference compatible with the inspected described type. Exact inputs produce exact descriptor results; inexact-compatible inputs produce non-null inexact descriptor references.
- The issue #48 / V8 fix is still the clearest primary-source edge case for `ref.get_desc`: `none` and stack bottom are subtypes of exact targets and must be treated as exact enough for the result.
- The proposal introduces `ref.cast_desc_eq` plus descriptor-aware branch-cast forms. Starshine currently models the non-branch `ref.cast_desc_eq` and `ref.test_desc` text/core/binary/validator surface, but does not document support for proposal branch descriptor-cast forms.
- Proposal JS prototype behavior and `wasm:js-prototypes` configuration remain outside Starshine's current runtime/embedding evidence. Static or validation success is not JS interop conformance.

## Starshine current-code reconciliation

- WAST keywords/parser/printer/lowerer recognize `describes`, `descriptor`, `struct.new_desc`, `struct.new_default_desc`, `ref.get_desc`, `ref.test_desc`, `ref.test_desc_null`, `ref.cast_desc_eq`, and `ref.cast_desc_eq_null`.
- Core instructions carry `StructNewDesc(TypeIdx)`, `StructNewDefaultDesc(TypeIdx)`, `RefGetDesc(TypeIdx)`, `RefTestDesc(Bool, HeapType)`, and `RefCastDescEq(Bool, HeapType)`. Binary encode/decode roundtrip tests cover descriptor reference instruction families.
- Validation keeps the upstream struct-only rule at the semantic layer. WAST parsing/lowering can still carry local array descriptor metadata for proposal-tracking tests, but `validate_descriptor_metadata_group(...)` rejects non-struct descriptor metadata.
- `Env::resolve_struct_descriptor_type(...)` starts from a struct-subtype lookup, so descriptor allocation and `ref.get_desc` are validator-owned struct features even if text can parse broader metadata.
- `Env::descriptor_result_type(...)` computes the exactness bridge: absent concrete operand from stack-polymorphic bottom is exact; concrete operands must match either the inexact or exact inspected described type; exact-compatible operands produce exact descriptor refs.
- `typecheck_struct_new(...)` and `typecheck_struct_new_default(...)` reject descriptor-bearing structs and tell callers to use descriptor-aware constructors.
- `typecheck_struct_new_desc(...)` and `typecheck_struct_new_default_desc(...)` require a nullable exact descriptor reference and produce a non-null exact described-struct reference, while preserving ordinary field/defaultability checks.
- `typecheck_ref_test_desc(...)` is a predicate form: it requires a concrete reference operand compatible with the descriptor target and returns `i32`.
- `typecheck_ref_cast_desc_eq(...)` is a trapping/refining cast form: it accepts stack-polymorphic bottom, otherwise requires descriptor compatibility, and pushes the target reference type.
- Valid-generator coverage can emit descriptor-bearing type pairs plus `struct.new_default_desc`, `ref.get_desc`, `ref.test_desc`, and `ref.cast_desc_eq`; this proves Starshine-valid core generation, not stable Core WebAssembly status.

## Documentation consequences

- Add a focused living page for the instruction surface instead of overloading the existing `ref.get_desc` fixture path or exact-reference structural matching page.
- Keep `ref.get_desc` exactness and bottom-input details linked to the older dedicated pages, but use the new page for descriptor-aware allocation, predicate/cast stack shapes, and pass/rewrite checklists across the whole descriptor instruction family.
- Cross-link WAST reference and GC aggregate authoring pages to the new descriptor-instruction guide so descriptor-local forms do not get mistaken for ordinary Core 3.0 `ref.test` / `ref.cast` or ordinary GC `struct.new` semantics.
- Keep feature-status wording routed through `wasm-feature-status-and-proposal-boundaries.md`: Custom Descriptors is Phase 3 and struct-oriented, while Starshine's broader parser/lowerer metadata experiments are local compatibility evidence.

## Supersession and uncertainty

- This note supplements `2026-06-04-custom-descriptor-current-recheck.md` with an instruction-surface routing page and a one-day-later primary-source spot check. It does not supersede the 2026-06-04 note's broader descriptor proposal/status reconciliation.
- The custom-descriptors proposal can still change before standardization. Recheck the overview and proposals tracker before adding descriptor metadata to non-struct validation, adding proposal branch descriptor-cast forms, or claiming JS prototype/embedding behavior.
