# Exception Tag Current Source Refresh

- Capture date: 2026-06-04
- Source family: current WebAssembly Core 3.0 tag type, exception instruction, binary tag, module-tag, and Starshine WAST/core/binary/validator source surfaces

## Primary Sources Checked

- WebAssembly Core Specification, `Syntax / Instructions — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/valid/instructions.html>
- WebAssembly Core Specification, `Validation / Types — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/valid/types.html>
- WebAssembly Core Specification, `Validation / Modules — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/valid/modules.html>
- WebAssembly Core Specification, `Binary Format / Types — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/binary/types.html>
- WebAssembly Core Specification, `Binary Format / Modules — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/binary/modules.html>
- WebAssembly Core Specification, `Text Format / Types — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/text/types.html>
- WebAssembly Core Specification, `Text Format / Modules — WebAssembly 3.0 (2026-06-03)`: <https://webassembly.github.io/spec/core/text/modules.html>

## Durable Takeaways

- Current Core 3.0 still exposes `throw`, `throw_ref`, `try_table`, `catch`, `catch_ref`, `catch_all`, and `catch_all_ref` as the live exception-handling instruction and catch-clause surface. No replacement spelling was found in the checked current pages.
- The current official tag-type validation rule accepts a type use whose expansion is a function type `func params -> results`; unlike the older js-string-builtins/proposal-style rule, the current Core 3.0 `valid/types.html` rule does not itself state an empty-result side condition.
- The current official exception-instruction rules still require empty-result tag expansions at EH use sites: `throw`, `catch`, and `catch_ref` all refer to tags expanding as `func params -> epsilon`; `catch_ref` appends a non-null `(ref exn)` to the branch payload, `catch_all` branches with no values, and `catch_all_ref` branches with non-null `(ref exn)`.
- `throw_ref` still consumes nullable `exnref` / `(ref null exn)` and is stack-polymorphic after that operand. A non-null exception reference is valid by subtyping, but null remains a runtime trap concern for execution-preserving rewrites.
- Binary tag types still encode as leading `0x00` plus a type index. The official binary page still calls out the leading byte as a future attribute slot; Starshine's decode/encode currently requires and emits `0x00`.

## Starshine Evidence Checked

- [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) registers `throw`, `throw_ref`, `try_table`, `catch`, `catch_ref`, `catch_all`, `catch_all_ref`, `delegate`, `rethrow`, and `tag` keywords.
- [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses tag fields/import descriptors, `throw`, `throw_ref`, modern `try_table`, all four modern catch clauses, and legacy `try`/`catch`/`delegate`/`rethrow` compatibility syntax.
- [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) resolves tag ids through the imported-prefix tag index space, lowers modern catch clauses to `@lib.Catch` variants, resolves catch labels against the enclosing label context, and lowers legacy EH syntax through compatibility scaffolding.
- [`../../../../src/wast/module_wast.mbt`](../../../../src/wast/module_wast.mbt) prints tag fields, tag imports/exports, `throw_ref`, and modern `try_table` catch clauses.
- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) keeps `TagIdx`, `TagType`, `Catch::{Catch,CatchRef,CatchAll,CatchAllRef}`, and `Instruction::{Throw,ThrowRef,TryTable}` as the core model.
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) decode/encode tag types as `0x00` plus `TypeIdx` and tag sections as section id `13`.
- [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt) currently validates `TagType` more strictly than current Core 3.0 tagtype validation by requiring the referenced function type to have an empty result list at import/tag-section validation time.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) uses tag parameters as `throw` payloads, pops nullable `exnref` for `throw_ref`, typechecks catch clauses against the enclosing label stack, and adds non-null `(ref exn)` for `catch_ref` / `catch_all_ref` branch payloads.
- [`../../../../src/validate/typecheck_negative_tests.mbt`](../../../../src/validate/typecheck_negative_tests.mbt), [`../../../../src/validate/invalid_fuzzer.mbt`](../../../../src/validate/invalid_fuzzer.mbt), and [`../../../../src/validate/gen_valid_tests.mbt`](../../../../src/validate/gen_valid_tests.mbt) keep payload mismatch, invalid tag, and generated try-table feature evidence visible.

## Caveats And Supersession

- This refresh supersedes only the source-date and tag-result-shape split in the May exception-tag notes. The May raw manifests remain useful for the original broad Starshine source map and the `throw_ref` nullability correction.
- Current Starshine behavior intentionally or accidentally remains stricter than the current official tagtype validation rule for resultful tag types. Until a deliberate validator change lands, resultful tag declarations or tag imports should be treated as Starshine validator-gap evidence, not ordinary portable fixtures.
- This refresh does not change the local WAST legacy-EH boundary: prefer modern `try_table` for semantic fixtures, and use legacy `try`/`delegate`/`rethrow` only when the parser/lowerer compatibility surface is under test.
