# Custom Descriptor Proposal And Starshine Surface Current Recheck

- Capture date: 2026-06-04
- Source family: WebAssembly custom-descriptors proposal, WebAssembly proposals tracker, upstream bottom-input discussion/engine fix, and current Starshine WAST/lowering/validator/static-harness evidence.
- Primary sources checked on 2026-06-04:
  - WebAssembly proposals tracker, current `main`: <https://github.com/WebAssembly/proposals>
  - WebAssembly custom-descriptors overview, current `main`: <https://raw.githubusercontent.com/WebAssembly/custom-descriptors/main/proposals/custom-descriptors/Overview.md>
  - WebAssembly/custom-descriptors issue #48, `ref.get_desc in dead code`: <https://github.com/WebAssembly/custom-descriptors/issues/48>
  - V8 commit `f52d915ff72fb8771263a0baa1c6f9ce936a7d29`, `[wasm-custom-desc] Fix ref.get_desc for none/bottom inputs`: <https://chromium.googlesource.com/v8/v8.git/+/f52d915ff72fb8771263a0baa1c6f9ce936a7d29%5E%21/>
- Local Starshine sources checked:
  - `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/module_wast.mbt`, `src/wast/spec_harness.mbt`
  - `src/validate/env.mbt`, `src/validate/typecheck.mbt`, `src/validate/match.mbt`, `src/validate/typecheck_negative_tests.mbt`

## Current official/proposal takeaways

- The WebAssembly proposals tracker still lists **Custom Descriptors and JS Interop** under Phase 3. It is proposal material, not stable Core WebAssembly 3.0.
- The proposal overview remains struct-oriented. It introduces `descriptor` clauses on described struct types and `describes` clauses on descriptor struct types; those clauses are part of type identity and must agree.
- The overview still says `describes` / `descriptor` clauses are restricted to struct type definitions, with an explicit note that this restriction may be relaxed later. Array or function descriptor metadata is therefore not current upstream proposal acceptance.
- Descriptor chains remain a first-class proposal surface: a type may have both `describes` and `descriptor`, creating meta-descriptor chains, but self or cyclic descriptor chains are invalid and `describes` can only point to previously defined types in the proposal text.
- Descriptor-aware allocation remains distinct from ordinary allocation. `struct.new` and `struct.new_default` cannot allocate descriptor-bearing structs; `struct.new_desc` and `struct.new_default_desc` take a nullable exact descriptor reference as their last operand and produce an exact described-struct reference.
- The proposal's exact heap types exist to prevent allocating a base described type with a subtype descriptor. Exact types are subtypes of their base type, but declared subtypes of the base are not subtypes of the exact base.
- `ref.get_desc typeidx` consumes a reference compatible with the inspected described type. Exact inputs produce exact descriptor results; inexact-compatible inputs produce non-null inexact descriptor results.
- Issue #48 and the V8 fix keep the bottom/null edge case concrete: `none` / bottom inputs are subtypes of exact targets and must produce exact descriptor results rather than losing precision.
- JS prototype / embedding behavior is part of the proposal motivation and later design surface, but Starshine currently has no JS embedding/runtime descriptor interop layer. Static fixture success is validation/lowering evidence only.

## Starshine current-code reconciliation

- WAST parsing and printing recognize descriptor metadata plus descriptor instruction keywords: `describes`, `descriptor`, `struct.new_desc`, `struct.new_default_desc`, and `ref.get_desc`.
- WAST parsing/lowering still accepts descriptor metadata on array type definitions in focused local tests. That is a local/proposal-tracking text and lowering surface; current validation rejects non-struct descriptor metadata through `validate_descriptor_metadata_group(...)`, and the proposal still frames the feature as struct-only.
- Lowering resolves descriptor metadata and `ref.get_desc` immediates to flat `TypeIdx` values. The inspected immediate for `ref.get_desc` names the described type, not the descriptor type.
- `Env::resolve_struct_descriptor_type(...)` starts from `resolve_struct_subtype(...)`, so validator-backed descriptor allocation and `ref.get_desc` remain struct-owned even when WAST parsing/lowering can carry broader metadata shapes.
- `Env::descriptor_result_type(...)` implements the source-backed result rule: no concrete operand from stack-polymorphic bottom is exact; concrete operands must match either the inexact expected described ref or exact expected described ref; exact-compatible operands produce an exact descriptor ref.
- `typecheck_struct_new(...)` and `typecheck_struct_new_default(...)` reject descriptor-bearing structs and require the descriptor-aware variants. The descriptor-aware variants pop `(ref null (exact descriptor_type))` and return `(ref (exact described_type))`.
- `src/wast/spec_harness.mbt` keeps `binary-descriptors.wast`, `descriptors.wast`, `exact.wast`, and `ref_get_desc.wast` on static native coverage paths. Mixed runtime commands in `ref_get_desc.wast` remain skipped command-by-command rather than counted as descriptor runtime interop evidence.

## Documentation consequences

- Refresh `docs/wiki/custom-descriptors/static-fixtures.md` so static fixture conclusions cite the current Phase-3/struct-only/proposal-local split and the 2026-06-04 static-harness refresh rather than relying only on May manifests.
- Refresh `docs/wiki/custom-descriptors/ref-get-desc-fixture-path.md` so the full-stack guide distinguishes the described-type immediate, exact/inexact result rule, bottom/null exactness, and validator-owned struct-only behavior from WAST's broader local array metadata parser/lowerer tests.
- Refresh `docs/wiki/custom-descriptors/exact-reference-equivalence.md` so exact-reference matching is framed as Starshine's current local structural matching rule used by descriptor semantics, while upstream descriptor exactness remains Phase-3 proposal material.
- Keep the existing `docs/wiki/wasm-feature-status-and-proposal-boundaries.md` vocabulary as the cross-wiki source of truth: custom descriptors are active proposal evidence, array metadata is Starshine-local compatibility evidence, and static fixture success is not JS embedding conformance.

## Supersession and uncertainty

- This note supersedes the source-freshness layer of `2026-05-20-custom-descriptor-refgetdesc-exactness-refresh.md` for the current proposal status, struct-only restriction, `ref.get_desc` exactness, and local Starshine code map.
- It does not supersede the May note's detailed provenance for the original `ref.get_desc` / exactness investigation, issue #48, or V8 bottom-input fix.
- The proposal may still change before standardization. Recheck the overview and proposals tracker before changing Starshine's descriptor metadata validation, extending descriptor metadata beyond structs, or claiming JS prototype/embedding behavior.
