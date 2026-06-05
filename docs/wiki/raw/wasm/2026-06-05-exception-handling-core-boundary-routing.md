# Exception Handling Core Boundary Routing

- Capture date: 2026-06-05
- Source family: current WebAssembly exception-handling status, Core 3.0 instruction rules, proposal routing, and Starshine WAST/core/validator implementation evidence

## Primary Sources Checked

- WebAssembly proposals `finished-proposals.md`: <https://github.com/WebAssembly/proposals/blob/main/finished-proposals.md>
- WebAssembly proposals active tracker: <https://github.com/WebAssembly/proposals>
- Archived WebAssembly exception-handling proposal repository: <https://github.com/WebAssembly/exception-handling>
- WebAssembly Core Specification, `Syntax / Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/syntax/instructions.html>
- WebAssembly Core Specification, `Validation / Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/valid/instructions.html>
- WebAssembly Core Specification, `Execution / Instructions — WebAssembly 3.0`: <https://webassembly.github.io/spec/core/exec/instructions.html>
- WebAssembly Stack Switching proposal repository: <https://github.com/WebAssembly/stack-switching>

## Starshine Evidence Checked

- [`../../../../src/wast/keywords.mbt`](../../../../src/wast/keywords.mbt) registers `throw`, `throw_ref`, `try_table`, catch keywords, legacy `try` compatibility keywords, and `tag`.
- [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses tag declarations/import descriptors, modern `try_table`, all four catch clauses, `throw`, `throw_ref`, and legacy `try`/`delegate`/`rethrow` compatibility syntax.
- [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) resolves tags through the imported-prefix tag index space, lowers modern catches to `@lib.Catch`, and keeps legacy EH as a text-compatibility lowering path rather than a preserved core instruction family.
- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) models `TagIdx`, `TagType`, `Catch::{Catch,CatchRef,CatchAll,CatchAllRef}`, and `Instruction::{Throw,ThrowRef,TryTable}`.
- [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt) currently validates tag definitions more strictly than current Core 3.0 by requiring empty tag result lists at declaration/import time.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) typechecks exception instruction operands, nullable `throw_ref`, non-null catch-reference payloads, and catch-label compatibility.

## Durable Takeaways

- Exception Handling is a finished proposal listed for Core/JS API 3.0 in the current finished-proposals table. It should not be routed as an active-proposal gap when the claim is about ordinary Core 3.0 `tag`, `throw`, `throw_ref`, or `try_table` syntax/validation.
- The current active proposals tracker no longer lists Exception Handling as active, while Stack Switching remains an active Phase-3 row. Treat continuation instructions such as `cont.new`, `suspend`, `resume*`, and `switch` as Stack Switching proposal evidence, not as Exception Handling evidence.
- Current Core 3.0 instruction syntax still names `throw`, `throw_ref`, `try_table`, `catch`, `catch_ref`, `catch_all`, and `catch_all_ref` as the exception-handling surface.
- Current Core 3.0 validation still types `throw_ref` with a nullable exception-reference operand and stack-polymorphic continuation; `try_table` validates its body under the block-result label and validates each catch clause separately.
- Execution still distinguishes `throw_ref` on a non-null exception reference from `throw_ref` on null, which traps. Pass documentation must preserve operand evaluation and the null-trap/throw split.
- Starshine has a real local WAST/core/binary/validator/generator surface for modern exception handling, but with layer-specific caveats: stricter resultful tag declaration validation than current Core 3.0, high-level legacy `try` compatibility that lowers away, and ordinary pass rewrite obligations around tag/catch carriers.

## Caveats And Supersession

- This bridge does not replace [`2026-06-04-exception-tag-current-refresh.md`](2026-06-04-exception-tag-current-refresh.md). That file remains the detailed source refresh for tag result-shape validation, binary tag bytes, and local owner files.
- This bridge adds feature-status routing: Exception Handling is finished/Core-3.0 evidence; Stack Switching, JSPI, Relaxed Dead Code Validation, and legacy Starshine text compatibility are separate boundaries.
- No Starshine implementation behavior changed in this source read.
