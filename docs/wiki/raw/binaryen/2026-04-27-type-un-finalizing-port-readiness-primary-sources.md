# Binaryen `type-unfinalizing` port-readiness primary-source capture

_Capture date:_ 2026-04-27  
_Status:_ immutable current-main source recheck for the `docs/wiki/binaryen/passes/type-un-finalizing/` dossier

## Scope

This source capture extends the 2026-04-24 `type-un-finalizing` manifest with a narrower implementation-readiness recheck. It asks: if Starshine eventually moves local `type-un-finalizing` out of boundary-only status, what exact upstream and local surfaces must the first implementation slice preserve?

Use this file as provenance, not as the explanatory destination. The living pages are:

- `docs/wiki/binaryen/passes/type-un-finalizing/index.md`
- `docs/wiki/binaryen/passes/type-un-finalizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-un-finalizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-un-finalizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-un-finalizing/starshine-port-readiness-and-validation.md`

## Official online sources rechecked

- Binaryen `main` `TypeFinalizing.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeFinalizing.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeFinalizing.cpp>
  - Relevant source locations observed on 2026-04-27:
    - `TypeFinalizing::run(Module*)`: early return when GC is not enabled.
    - `TypeFinalizing::run(Module*)`: unfinalizing mode does not build `SubTypes` and does not apply the leaf-only `getImmediateSubTypes(type).empty()` filter used by finalizing mode.
    - `ModuleUtils::getPrivateHeapTypes(*module)`: still defines the candidate visibility boundary.
    - Nested `TypeRewriter : GlobalTypeRewriter`: toggles selected `TypeBuilder` entries with `setOpen(!finalize)`; in unfinalizing mode that is `setOpen(true)`.
    - `createTypeFinalizingPass()` / `createTypeUnFinalizingPass()`: shared owner file creates both public pass factories.
- Binaryen `main` `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Relevant source locations observed on 2026-04-27:
    - The public upstream pass name is `type-unfinalizing`, without Starshine's extra hyphen.
    - The public description remains a narrow type-state description: mark types open again.
    - The sibling registration sits near `type-finalizing`; neither registration implies default optimize-preset scheduling.
- Binaryen `main` `type-finalizing.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-finalizing.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-finalizing.wast>
  - Relevant source locations observed on 2026-04-27:
    - The same lit fixture runs both `--type-unfinalizing` and `--type-finalizing`.
    - Public open and public final types are asserted unchanged.
    - Private type state changes, non-leaf reopening, and function-heap-type participation are covered by the generated checks.

## Local Starshine source surfaces rechecked

- `src/passes/optimize.mbt`
  - Lines 127-139: `pass_registry_boundary_only_names()` includes `type-finalizing` and local `type-un-finalizing`.
  - Lines 379-405: `optimize_preset_passes(...)` and `shrink_preset_passes(...)` omit both type-finality siblings.
  - Lines 480-488: direct requests to boundary-only passes produce the standard not-implemented-in-hot-pipeline error.
- `src/lib/types.mbt`
  - Lines 98-148: `TypeIdx`, `TypeMetadata`, and `SubType(Bool, Array[TypeIdx], TypeMetadata, CompType)` encode subtype edges plus the final/open bit a future pass would toggle.
  - Function signatures, globals, locals, block types, `call_ref`, and GC instructions use type indices or heap types that must remain coherent after a type-section rewrite.
- `src/wast/parser.mbt`
  - Around lines 2211-2250: text parsing accepts `(sub final ...)` and records `final_`.
- `src/wast/lower_to_lib.mbt`
  - Around lines 408-410: WAST lowering creates `SubType::new(td.final_, ...)`.
  - Lines 5103-5175: descriptor/final-subtype fixture proves current text-to-library lowering can carry final subtype shapes through validation.
- `src/wast/module_wast.mbt`
  - Around lines 682-685: WAT pretty-printing writes `final` when the type declaration has `final_` set.
- `src/validate/env.mbt` and `src/validate/typecheck.mbt`
  - Rechecked as the post-rewrite validation surfaces for heap-type environments and final/subtype legality.
- `src/binary/encode.mbt` and `src/binary/decode.mbt`
  - Rechecked as roundtrip surfaces for any future final/open bit mutation; `decode.mbt` decodes the final subtype opcode and ordinary subtype opcode into the same `SubType` finality bit.

## Durable observations

- No teaching-relevant current-main drift was found from the 2026-04-24 `version_129` contract: `type-unfinalizing` remains a tiny GC-gated module/type-section rewrite, not a body optimizer.
- The sibling's correctness hinge is **less** proof than `type-finalizing`, not more: after the GC gate, privacy is the key boundary and there is intentionally no leaf-only filter.
- The implementation-readiness gap is Starshine infrastructure. Starshine can parse, lower, pretty-print, validate, encode, and decode final subtype shapes, but it does not yet have a `GlobalTypeRewriter`-equivalent helper or a documented `ModuleUtils::getPrivateHeapTypes(...)` equivalent.
- A first Starshine implementation should therefore be either a no-op analyzer/status slice or a narrow private-type reopening slice over already-proven-private final/open type declarations, with validation after every rewrite.
- The naming mismatch remains important: Binaryen's public spelling is `type-unfinalizing`, while Starshine currently preserves `type-un-finalizing` as the local boundary-only spelling.

## Uncertainties and caveats

- This capture did not prove a complete equivalence between Binaryen `main` and `version_129`; it only rechecked the owner, registration, and dedicated lit surfaces relevant to `type-unfinalizing`.
- Starshine's exact notion of private heap-type observability still needs a design decision before implementation. Binaryen's `ModuleUtils::getPrivateHeapTypes(...)` should be treated as the oracle behavior, not assumed equivalent to any current local helper.
- A faithful port may need shared type-graph rewrite infrastructure that will also serve `type-finalizing`, `remove-unused-types`, `type-merging`, `minimize-rec-groups`, `unsubtyping`, and related GC/type passes.
