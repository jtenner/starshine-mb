# WebAssembly GC Core Boundary Refresh

- Capture date: 2026-06-05
- Source family: current WebAssembly Core 3.0 / finished-proposal routing plus Starshine GC type, instruction, binary, validation, WAST, generator, and custom-descriptor evidence
- Purpose: add a durable bridge that ties the existing focused GC type, reference, aggregate-instruction, constant-expression, and descriptor pages together without duplicating their detailed contracts.

## Primary sources checked

- WebAssembly finished-proposals table, current on 2026-06-05: <https://github.com/WebAssembly/proposals/blob/main/finished-proposals.md>
- WebAssembly Core Specification, `Syntax / Types`, WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/syntax/types.html>
- WebAssembly Core Specification, `Syntax / Instructions`, WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- WebAssembly Core Specification, `Text Format / Types`, WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/text/types.html>
- WebAssembly Core Specification, `Text Format / Instructions`, WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/text/instructions.html>
- WebAssembly Core Specification, `Binary Format / Types`, WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/binary/types.html>
- WebAssembly Core Specification, `Binary Format / Instructions`, WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/binary/instructions.html>
- WebAssembly Core Specification, `Validation / Types`, WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/types.html>
- WebAssembly Core Specification, `Validation / Instructions`, WebAssembly 3.0 page dated 2026-06-03: <https://webassembly.github.io/spec/core/valid/instructions.html>
- WebAssembly GC proposal overview repository, useful as historical design context now that the feature is in Core 3.0: <https://github.com/WebAssembly/gc>
- WebAssembly custom-descriptors overview, current `main` on 2026-06-05: <https://raw.githubusercontent.com/WebAssembly/custom-descriptors/main/proposals/custom-descriptors/Overview.md>

## Existing Starshine / wiki sources reused

- [`2026-06-04-gc-type-subtyping-current-refresh.md`](2026-06-04-gc-type-subtyping-current-refresh.md) for Core 3.0 GC type-use, rec-group, subtype, binary type, and validation details.
- [`2026-06-04-reference-call-and-cast-current-refresh.md`](2026-06-04-reference-call-and-cast-current-refresh.md) for reference instructions, `call_ref`, `ref.test` / `ref.cast`, and `br_on_*` WAST-versus-core layer splits.
- [`2026-06-04-constant-expression-current-refresh.md`](2026-06-04-constant-expression-current-refresh.md) for the local constant-expression allow-list split around aggregate constructors.
- [`2026-06-04-struct-atomic-get-sources.md`](2026-06-04-struct-atomic-get-sources.md) for the shared-GC aggregate atomic get-only WAST surface.
- [`2026-06-05-custom-descriptor-instruction-surface-refresh.md`](2026-06-05-custom-descriptor-instruction-surface-refresh.md) and [`2026-06-04-custom-descriptor-current-recheck.md`](2026-06-04-custom-descriptor-current-recheck.md) for active-proposal descriptor metadata and instruction routing.

## Local code checked

- [`src/lib/types.mbt`](../../../../src/lib/types.mbt) carries the `AbsHeapType`, `HeapType`, `RefType`, `CompType::{Struct,Array,Func}`, `SubType`, `RecType`, `TypeMetadata`, `CastOp`, and GC/reference/aggregate `Instruction` variants.
- [`src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt), and [`src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) prove the narrower current WAST text surface.
- [`src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../../../src/binary/encode.mbt) prove the wider binary/Core model for GC types, references, and aggregate instructions.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt) owns type-section validation, subtype validation, descriptor metadata validation, and constant-expression admission.
- [`src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) owns `typecheck_ref_test`, `typecheck_ref_cast`, `typecheck_struct_*`, `typecheck_array_*`, `typecheck_ref_i31`, `typecheck_i31_get`, `typecheck_any_convert_extern`, and `typecheck_extern_convert_any`.
- [`src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) keeps GC/reference-generation gates local to Starshine and is not standards-status evidence by itself.

## Durable takeaways

1. WebAssembly GC should be taught as a finished/Core-3.0 feature for ordinary `func` / `struct` / `array` composite types, recursive groups, abstract heap types such as `any`, `eq`, `struct`, `array`, `i31`, bottom heap types such as `none`, and ordinary reference/aggregate instructions.
2. Starshine's **Core/binary/validator/generator** layer is wider than the high-level `src/wast` text layer. That means parser absence for ordinary `ref.test`, `ref.cast`, `br_on_*`, `call_ref`, `struct.set`, or `array.*` is a local WAST text gap, not evidence that the feature is still proposal-only or absent from Core.
3. Starshine's **constant-expression** layer is narrower than ordinary body typechecking. Current Core 3.0 lists more aggregate constructors as constant instructions than Starshine admits in `validate_const_instr(...)`; keep initializer claims routed through the constant-expression page.
4. Custom descriptors and exact descriptor-aware instructions are not part of the ordinary Core GC baseline. The official custom-descriptors source is still active-proposal evidence and remains struct-oriented; Starshine's broader local metadata parser/lowerer behavior must stay labeled local unless future primary sources broaden the proposal.
5. Shared-GC aggregate atomics are not the same evidence layer as linear-memory atomics. Current Starshine WAST support is documented for `struct.atomic.get*` only; broader aggregate atomic set/RMW/cmpxchg or array atomic claims need a separate implementation/source slice.
6. Binaryen pass dossiers that say “GC” should distinguish which GC layer they need: type-section graph, reference casts/branches/calls, aggregate allocation/access/mutation, descriptor exactness, or initializer validation. Mixing those layers hides different rewrite obligations and validator risks.

## Documentation consequences

- Add a top-level living page, `wasm-gc-core-boundary.md`, as the router for ordinary Core GC versus Starshine layer-specific support.
- Refresh `wasm-feature-status-and-proposal-boundaries.md` so GC has its own row like relaxed SIMD, JS String Builtins, and Memory Control.
- Cross-link the WAST GC type, aggregate-instruction, and reference-instruction pages through the new boundary so readers can start with the big picture and then descend to exact type/instruction contracts.
- Do not create a duplicate page for every GC subfeature. Keep the detailed pages authoritative for type-use, reference branches/casts, aggregate instructions, constant expressions, and custom descriptors.
