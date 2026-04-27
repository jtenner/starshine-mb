# Binaryen `type-finalizing` port-readiness primary-source capture

_Capture date:_ 2026-04-27  
_Status:_ immutable current-main source recheck for the `docs/wiki/binaryen/passes/type-finalizing/` dossier

## Scope

This source capture extends the 2026-04-24 `type-finalizing` manifest with a narrower implementation-readiness recheck. It asks: if Starshine eventually moves `type-finalizing` out of boundary-only status, what exact upstream and local surfaces must the first implementation slice preserve?

Use this file as provenance, not as the explanatory destination. The living pages are:

- `docs/wiki/binaryen/passes/type-finalizing/index.md`
- `docs/wiki/binaryen/passes/type-finalizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-finalizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-finalizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-finalizing/starshine-port-readiness-and-validation.md`

## Official online sources rechecked

- Binaryen `main` `TypeFinalizing.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeFinalizing.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeFinalizing.cpp>
  - Relevant source locations observed on 2026-04-27:
    - `TypeFinalizing::run(Module*)`: early return when GC is not enabled.
    - `TypeFinalizing::run(Module*)`: finalizing mode builds a subtype index and admits only private heap types with no immediate subtypes; unfinalizing skips the leaf proof.
    - Nested `TypeRewriter : GlobalTypeRewriter`: toggles `TypeBuilder` entries with `setOpen(!finalize)` and then updates the module globally.
    - `createTypeFinalizingPass()` / `createTypeUnFinalizingPass()`: shared owner file creates both public pass factories.
- Binaryen `main` `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Relevant source locations observed on 2026-04-27:
    - Lines 3288-3292: public `type-finalizing` registration says it marks leaf types final.
    - Lines 3306-3310: public sibling spelling is `type-unfinalizing`, not Starshine's local `type-un-finalizing` spelling.
- Binaryen `main` `type-finalizing.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-finalizing.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-finalizing.wast>
  - Relevant source locations observed on 2026-04-27:
    - Lines 432-434: the same lit fixture runs both `--type-unfinalizing` and `--type-finalizing`.
    - Lines 436-453: public open and public final types are asserted unchanged.
    - Later generated checks in the same file cover private type state changes, non-leaf preservation under finalizing, and function-heap-type participation.

## Local Starshine source surfaces rechecked

- `src/passes/optimize.mbt`
  - Lines 127-136: `pass_registry_boundary_only_names()` includes `type-finalizing` and local `type-un-finalizing`.
  - Lines 83-91: boundary-only entries are categorized as `BoundaryOnly`.
  - Lines 483-487: direct requests to boundary-only passes produce the standard not-implemented-in-hot-pipeline error.
  - Lines 286-288: boundary-only names are inserted into the registry after active pass entries.
- `src/lib/types.mbt`
  - Lines 98-148: `TypeIdx`, type metadata, and `SubType(Bool, Array[TypeIdx], TypeMetadata, CompType)` encode the final/open bit plus supertype edges that a future pass would rewrite.
  - Lines 433 and 481-532: function-section and instruction references include type-index uses that must remain coherent after a type-section rewrite.
  - Lines 736-743 and neighboring GC opcodes: struct instructions carry `TypeIdx` immediates that must validate after finality changes.
- `src/wast/parser.mbt`
  - Lines 2211-2250: text parsing accepts `(sub final ...)` and records `final_`.
- `src/wast/lower_to_lib.mbt`
  - Lines 408-410: WAST lowering creates `SubType::new(td.final_, ...)` for final/open state.
  - Lines 5103-5175: descriptor/final-subtype fixture proves current text-to-library lowering can already carry final subtype shapes through validation.
- `src/wast/module_wast.mbt`
  - Lines 682-685: WAT pretty-printing writes `final` when the type declaration has `final_` set.
- `src/validate/typecheck.mbt` and `src/validate/env.mbt`
  - Rechecked as the post-rewrite validation surfaces for heap-type environments and final/subtype legality. A future pass must route through normal validation rather than trusting a syntactic toggle.
- `src/binary/encode.mbt` and `src/binary/decode.mbt`
  - Rechecked as roundtrip surfaces for any future final/open bit mutation.

## Durable observations

- No teaching-relevant current-main drift was found from the 2026-04-24 `version_129` contract: the pass remains a small GC-gated module/type-section rewrite, not a body optimizer.
- The implementation-readiness gap is not source discovery; it is Starshine infrastructure. Starshine can already parse, lower, pretty-print, validate, encode, and decode final subtype shapes, but it does not yet have a `GlobalTypeRewriter`-equivalent helper that can safely rebuild the type graph and all references.
- A first Starshine implementation should therefore be a no-op analyzer/status slice or a very narrow private-leaf finalization slice over already-private, non-export-visible type declarations, with validation after every rewrite.
- The sibling naming mismatch remains important: Binaryen's public spelling is `type-unfinalizing`, while Starshine currently preserves `type-un-finalizing` as the local boundary-only spelling.
- The future validation ladder should include both positive type-section changes and negative preservation cases: no-GC no-op, public types unchanged, private non-leaf unchanged under finalizing, private function heap types handled, and local/global/instruction references still valid after the global rewrite.

## Uncertainties and caveats

- This capture did not prove a complete equivalence between Binaryen `main` and `version_129`; it only rechecked the owner, registration, and dedicated lit surfaces relevant to `type-finalizing`.
- Starshine's exact notion of private heap-type observability still needs a design decision before implementation. Binaryen's `ModuleUtils::getPrivateHeapTypes(...)` should be treated as the oracle behavior, not assumed equivalent to any current local helper.
- A faithful port may need shared type-graph rewrite infrastructure that will also serve `type-un-finalizing`, `type-merging`, `minimize-rec-groups`, `unsubtyping`, and related GC/type passes.
