# Custom Descriptor `ref.get_desc` And Exactness Refresh

Date: 2026-05-20

## Sources Checked

- WebAssembly custom-descriptors proposal overview, current `main`: <https://raw.githubusercontent.com/WebAssembly/custom-descriptors/main/proposals/custom-descriptors/Overview.md>
- WebAssembly proposals tracker, current `main`: <https://github.com/WebAssembly/proposals> / <https://raw.githubusercontent.com/WebAssembly/proposals/main/README.md>
- WebAssembly/custom-descriptors issue #48, `ref.get_desc in dead code`: <https://github.com/WebAssembly/custom-descriptors/issues/48>
- V8 commit `f52d915ff72fb8771263a0baa1c6f9ce936a7d29`, `[wasm-custom-desc] Fix ref.get_desc for none/bottom inputs`: <https://chromium.googlesource.com/v8/v8.git/+/f52d915ff72fb8771263a0baa1c6f9ce936a7d29%5E%21/>
- Starshine code and tests:
  - [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt)
  - [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt)
  - [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt)
  - [`src/validate/env.mbt`](../../../../src/validate/env.mbt)
  - [`src/validate/match.mbt`](../../../../src/validate/match.mbt)
  - [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
  - [`src/validate/match_tests.mbt`](../../../../src/validate/match_tests.mbt)
  - [`src/validate/typecheck_negative_tests.mbt`](../../../../src/validate/typecheck_negative_tests.mbt)
  - [`src/wast/ref_null_exact_surface_test.mbt`](../../../../src/wast/ref_null_exact_surface_test.mbt)
  - [`src/wast/exact_type_equivalence_test.mbt`](../../../../src/wast/exact_type_equivalence_test.mbt)

## Durable Takeaways

1. The official custom-descriptors proposal is still proposal material, not baseline WebAssembly 3.0. The proposals tracker lists **Custom Descriptors and JS Interop** in Phase 3, so Starshine should keep proposal/local caveats visible on descriptor pages.
2. The proposal frames custom descriptors as a WasmGC struct feature: a described struct type has a `descriptor` clause and the descriptor struct type has a `describes` clause. The overview explicitly says these clauses are part of type identity, must agree, can participate in descriptor chains, and are currently restricted to struct type definitions.
3. The proposal introduces exact heap types to make descriptor-bearing allocation sound. Exact refs are subtypes of their base type but do not accept declared subtypes of that base; bottom-null families such as `none` still subtype exact defined types.
4. `ref.get_desc typeidx` consumes a reference compatible with the inspected described type. If the operand is exact, the descriptor result is also exact; if the operand is only inexact-compatible, the descriptor result is non-null but inexact.
5. Issue #48 and the V8 fix establish a subtle edge case: `none` and unreachable/bottom operands are more specific than any exact target in this context and must produce an exact descriptor result. Starshine's `Env::descriptor_result_type(...)` already has the same outcome: no concrete operand (`None` from `pop_ref_or_bot`) is exact, and `ref.null none` / `ref.null nofunc` can satisfy the exact-target match path.
6. Starshine deliberately differs from current upstream proposal text in one documented local surface: WAST parsing/lowering tests still accept descriptor metadata on array type definitions even though the proposal currently restricts `descriptor` / `describes` clauses to structs. Keep that as proposal-tracking evidence, not as a stable upstream rule.

## Starshine Mapping

- Text metadata parsing lives in `parse_type_metadata_clauses(...)` and preserves `describes` before `descriptor` ordering; `wt_type_metadata(...)` resolves source ids to flat `TypeIdx` values during lowering.
- `render_type_metadata(...)` prints both clauses, so roundtrip tests can expose ordering and identity mistakes.
- `Env::resolve_struct_descriptor_type(...)` intentionally starts from `resolve_struct_subtype(...)`, so validator-backed `ref.get_desc` is still struct-owned even if the WAST local array metadata parser accepts broader syntax.
- `Env::descriptor_result_type(...)` owns the inspected-type / operand-compatibility / result-exactness rule used by `typecheck_ref_get_desc(...)`.
- `Match::matches(...)` owns exact reference compatibility. Exact-to-exact compatibility uses structural closure equivalence with cycle guards instead of raw type-index equality; inexact bottom-null abstract refs (`none`, `nofunc`) have special paths when the expected type is exact and the target shape is compatible.

## Uncertainties And Follow-Up

- The proposal may still change before standardization. In particular, the overview itself leaves room to relax or adjust descriptor-chain and struct-only restrictions.
- Starshine's array-metadata WAST surface should be rechecked whenever the custom-descriptors proposal advances or when the validator starts rejecting descriptor metadata outside structs.
- Descriptor JS interop and prototype configuration are outside the current Starshine static-fixture contract; the living custom-descriptor pages should continue to separate core validation/typechecking evidence from JS embedding behavior.
