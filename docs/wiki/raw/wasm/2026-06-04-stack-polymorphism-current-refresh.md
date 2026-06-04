# Stack Polymorphism Current Source Refresh (2026-06-04)

## Purpose

This manifest refreshes the focused Starshine stack-polymorphism guide against the current WebAssembly 3.0 validation pages and the current local validator source. It supersedes no prior source note; instead it updates the 2026-05-20 bridge with a current-source check and a clearer maintenance split between value-polymorphic instructions, stack-polymorphic unconditional transfers, conditional branch fallthrough, and Starshine's concrete-stack-junk diagnostics.

## Primary external sources checked

- WebAssembly Core 3.0 validation algorithm appendix, current page dated 2026-06-04: <https://webassembly.github.io/spec/core/appendix/algorithm.html>
  - Rechecked the `Bot` value type, control-frame `unreachable` flag, operand/control-stack model, `pop_val` behavior that returns `Bot` only when the current frame is unreachable at its stack height, the `unreachable()` helper that purges prior operand types, the note that later pushed operands still push/pop normally, and the representative opcode rules for `unreachable`, `br`, `br_if`, `br_table`, `return`, `return_call_ref`, and `throw`.
- WebAssembly Core 3.0 instruction validation, current page dated 2026-06-04: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Rechecked the spec's distinction between value-polymorphic instructions such as `drop`/`select` and stack-polymorphic unconditional control transfers such as `unreachable`, `br`, `br_table`, `return`, `return_call*`, `throw`, and `throw_ref`.
  - Rechecked the direct example where `unreachable; i32.add` can validate but `unreachable; i64.const 0; i32.add` remains invalid because concrete values pushed after the terminal point still constrain later instructions.
  - Rechecked `br_if` as conditional: its instruction type consumes an `i32` condition and preserves the label payload on fallthrough, so it is not an unconditional stack-polymorphic transfer.
- WebAssembly Core 3.0 module validation, current page dated 2026-06-04: <https://webassembly.github.io/spec/core/valid/modules.html>
  - Rechecked that table initializers and active data offsets are valid only when their initializer/offset expression is both valid at the expected value type and constant, preserving the page's warning that Starshine constant-expression validation is intentionally stricter than ordinary function-body stack polymorphism.
- WebAssembly Core 3.0 instruction syntax, current page dated 2026-06-04: <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - Rechecked the syntax/execution split: the `unreachable` instruction causes a runtime trap, which remains a separate concept from the validation-time stack-polymorphic typing rule.

## Local Starshine sources checked

- `src/lib/types.mbt`
  - `ValType` still includes `BotValType`, with `ValType::bottom()` as the local bottom constructor used only by the validator/typechecker layer.
- `src/validate/typecheck.mbt`
  - `TcState` still stores `stack`, `reachable`, `escape`, and `reachable_escape_depths`.
  - `TcState::set_unreachable(...)` and `TcState::set_branch_escape(...)` still clear the concrete stack before marking the current continuation nonfallthrough.
  - `TcState::pop1(...)` still returns `ValType::bottom()` only when the real stack is empty and `reachable == false`; reachable underflow is still an error.
  - `pop_expect(...)` still accepts `ValType::bottom()` for any expected type, while concrete popped values must match normally.
  - `typecheck_br_if(...)` still validates the condition and target payload but returns the fallthrough state for reachable input, while `typecheck_br_table(...)`, `typecheck_return(...)`, tail calls, and exception throws still make the local continuation nonfallthrough after their operands validate.
- `src/validate/typecheck_negative_tests.mbt`
  - Direct tests still cover bottom synthesis (`pop1`, `pop_expect`, `pop_types`), branch operand underflow before terminal transfer, `br_if` condition and label checks, `br_table` selector/label/payload checks, if-branch reachability merging, unreachable block bodies, loop backedge nonfallthrough, and descriptor/ref bottom handling.
- `src/validate/validate.mbt`
  - `validate_const_expr(...)` still rejects unreachable constant expressions after typechecking, preserving the initializer/offset stricter-than-body split.
  - End-of-body diagnostics still report underflow, type mismatch, and extra concrete values with stack-shape details.
  - Regressions still reject concrete stack junk after `return` inside a block and wrong concrete loop results after an infinite inner loop.

## Durable conclusions

1. The current WebAssembly Core 3.0 sources preserve the 2026-05-20 understanding: stack polymorphism is a validation rule for unreachable continuations, not a runtime value, dynamic typing, or a waiver for later concrete stack entries.
2. The official algorithm and Starshine implementation share the same essential shape: mark the current frame/continuation unreachable, clear the prior stack to the frame boundary, synthesize bottom only for underflow, and continue checking concrete values pushed afterward.
3. `br_if` and `br_on_*` families remain fallthrough-sensitive conditional branches. They may record branch escapes, but they do not make the fallthrough continuation stack-polymorphic the way `br`, `br_table`, `return`, tail calls, and throws do.
4. Starshine's `reachable_escape_depths`/`BranchTcEscape` model is not a one-to-one copy of the spec control stack, but it preserves the maintenance invariant future passes need: a nested nonfallthrough child can still make an enclosing label reachable when a branch exits to that label.
5. Constant expressions must stay routed through `validate/constant-expressions.md`: current official module rules require valid constant initializer/offset expressions at expected types, and Starshine additionally rejects unreachable constant expressions rather than borrowing ordinary function-body bottom synthesis.

## Follow-ups

- If Starshine later adopts a closer explicit control-frame stack, update `validate/stack-polymorphism-and-bottom.md` with the new mapping from local frames to the official algorithm.
- If any pass or generator starts relying on `br_on_*` type-refinement fallthrough details, refresh the reference-branch WAST page and this bottom page together so conditional branch facts are not flattened into generic terminal-control wording.
- If constant-expression validation widens or narrows, update this note's constant-expression caveat, `validate/constant-expressions.md`, and the initializer/offset pages in the same change.
