# 2026-06-05 More Array Constructors Boundary Refresh

- Date: 2026-06-05
- Topic: active WebAssembly More Array Constructors proposal versus Core WebAssembly GC array instructions and current Starshine array support
- Status: source bridge for [`../../wasm-more-array-constructors-boundary.md`](../../wasm-more-array-constructors-boundary.md), [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md), [`../../wasm-gc-core-boundary.md`](../../wasm-gc-core-boundary.md), and [`../../wast/gc-aggregate-instruction-authoring.md`](../../wast/gc-aggregate-instruction-authoring.md)

## Sources Checked

1. Official WebAssembly proposals tracker, checked 2026-06-05: <https://github.com/WebAssembly/proposals>
2. More Array Constructors proposal repository, checked 2026-06-05: <https://github.com/WebAssembly/more-array-constructors>
3. More Array Constructors overview, checked 2026-06-05: <https://github.com/WebAssembly/more-array-constructors/blob/main/proposals/more-array-constructors/Overview.md>
4. Current WebAssembly Core 3.0 instruction syntax page, checked 2026-06-05: <https://webassembly.github.io/spec/core/syntax/instructions.html>
5. Current WebAssembly Core 3.0 instruction validation page, checked 2026-06-05: <https://webassembly.github.io/spec/core/valid/instructions.html>
6. Current WebAssembly Core 3.0 instruction index, checked 2026-06-05: <https://webassembly.github.io/spec/core/appendix/index-instructions.html>
7. Starshine local array evidence, checked 2026-06-05: [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt), [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt), [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt), [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt), [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt), [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt), [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt)

## Observed Facts

- The current official proposals tracker lists **More Array Constructors** as an active Phase-1 proposal. Treat this as proposal-status evidence only, not a Starshine support claim and not proof that the instructions are already part of Core WebAssembly.
- The proposal overview introduces three new array-construction instructions: `array.new_array`, `array.new_memory`, and `array.new_table`. Each creates a new array from a runtime-selected subslice of another array, memory, or table, respectively. The motivation is dynamic-length, dynamic-content construction for immutable arrays.
- These proposal instructions are distinct from Core WebAssembly GC array instructions that already exist in the current Core 3.0 spec: `array.new`, `array.new_default`, `array.new_fixed`, `array.new_data`, `array.new_elem`, `array.get*`, `array.set`, `array.len`, `array.fill`, `array.copy`, `array.init_data`, and `array.init_elem`.
- Current Starshine has core instruction variants and binary encode/decode support for the Core GC array family listed above. It does not have instruction variants, WAST keywords, binary codec arms, typechecker cases, generator rows, or proposal feature gates for `array.new_array`, `array.new_memory`, or `array.new_table`.
- Current Starshine high-level WAST text still does not expose any ordinary `array.*` aggregate instructions. That WAST gap applies to the already-Core array family and to the active-proposal More Array Constructors family. Core builders, binary fixtures, or generated modules are still the right local fixture layers for current Core array work.
- Current Starshine constant-expression validation remains narrower than current Core for `array.new`, `array.new_default`, and `array.new_fixed`, and More Array Constructors does not change that local initializer allow-list.
- Current Starshine data-count docs already track `array.new_data` / `array.init_data` as Core data-index users with a local pre-code missing-data-count scanner gap. Do not confuse that existing Core/data-count gap with future `array.new_memory` proposal work, which would carry a memory index and runtime bounds/trap behavior instead of a data segment index.

## Durable Wiki Implications

1. Add a focused boundary page so maintainers do not infer `array.new_array` / `array.new_memory` / `array.new_table` support from existing Core array support, GC support, data-count notes, memory/table pages, or Binaryen/engine experiments.
2. Update the feature-status router with a dedicated More Array Constructors row instead of leaving the proposal only in the catch-all active-row bucket.
3. Update GC aggregate instruction guidance so existing `array.new_data` / `array.new_elem` remain Core GC array forms, while `array.new_array` / `array.new_memory` / `array.new_table` route to the active-proposal boundary.
4. Keep future implementation requirements explicit: new core variants, binary subopcode confirmation, WAST syntax, typechecking, memory/table/address-width interactions, generator gates, invalid strategies, and optimizer effect/trap modeling.

## No-Support Code Map

| Starshine layer | Current evidence checked | Current result |
| --- | --- | --- |
| WAST keywords/parser | [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt), [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt) | Struct and descriptor aggregate keywords exist; no ordinary `array.*` WAST text and no `array.new_array` / `array.new_memory` / `array.new_table` keywords. |
| Core instruction model | [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) | Core GC array variants exist through `ArrayInitElem`; no More Array Constructors variants. |
| Binary decode/encode | [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt), [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) | Core `0xFB` subcodes for current GC arrays exist; no proposal constructor codec arms. |
| Validation | [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt), [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt) | Typechecks current Core array constructors/access/mutation/init; no `array.new_array` / `array.new_memory` / `array.new_table` cases. |
| Generator/fuzz | [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt) | Existing GC aggregate generation is local feature/profile evidence for Core arrays only; no More Array Constructors feature gate or rows. |
