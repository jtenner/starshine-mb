# Stack Polymorphism And Bottom Source Bridge (2026-05-20)

## Purpose

This manifest anchors the focused validator guide for WebAssembly unreachable-code stack polymorphism and Starshine's `BotValType` implementation. It narrows a common maintenance mistake: treating unreachable code as "validation is off" instead of "missing operands below the current frame may be synthesized, while concrete values pushed afterward are still checked."

## Primary external sources checked

- WebAssembly core spec, validation instructions: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Checked for the current WebAssembly 3.0 rule that `unreachable` is stack-polymorphic, and for the broader instruction-typing model where instructions have input and output stack types.
- WebAssembly core spec, validation algorithm appendix: <https://webassembly.github.io/spec/core/appendix/algorithm.html>
  - Checked for the control-stack/value-stack algorithm: each control frame records start/end types, stack height, and an unreachable flag; marking a frame unreachable purges prior operand types; later pushes/pops remain concrete; underflow in unreachable code produces `Bot` values.
- WebAssembly core spec, valid modules: <https://webassembly.github.io/spec/core/valid/modules.html>
  - Checked for the function-body validation context and the implicit outer label shape that function body typechecking relies on.
- WebAssembly core spec, syntax instructions: <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - Checked for the ordinary control instructions and reference/branch families that can make local continuation unreachable.

## Local Starshine sources checked

- `src/lib/types.mbt`
  - `ValType` includes `BotValType`, with `ValType::bottom()` as the local bottom-value constructor used by stack-polymorphic typechecking.
- `src/validate/typecheck.mbt`
  - `TcState` stores `stack`, `reachable`, `escape`, and `reachable_escape_depths`.
  - `TcState::set_unreachable(...)` and `TcState::set_branch_escape(...)` clear the concrete stack before marking continuation nonfallthrough.
  - `TcState::pop1(...)` returns `ValType::bottom()` on stack underflow only when `reachable == false`; reachable underflow remains an error.
  - `pop_expect(...)`, `check_pop_types_from_top(...)`, `validate_end_stack(...)`, `normalize_untyped_block_exit(...)`, `normalize_loop_exit(...)`, and `normalize_untyped_if_branch_exit(...)` are the local mechanics that combine virtual bottom operands with concrete end-stack checks.
  - `Instruction::Unreachable`, `Br`, `BrTable`, `Return`, tail calls, and `throw`/`throw_ref` set nonfallthrough state after their own operands validate.
- `src/validate/typecheck_negative_tests.mbt`
  - Locks direct bottom behavior (`pop1`, `pop_expect`, `pop_types`), if-merge reachability, unreachable block bodies, branch-label boundary underflow, and unconditional-loop nonfallthrough behavior.
  - Includes the descriptor/reference regression `RefCastDescEq accepts polymorphic stack in unreachable state`, showing bottom use outside ordinary numeric/control instructions.
- `src/validate/validate.mbt`
  - Function-body validation reports end-stack underflow, wrong result type, and extra concrete values with stack-shape diagnostics.
  - Regressions `validate_module rejects concrete stack junk after return inside block` and `validate_module rejects wrong concrete loop result after infinite inner loop` keep the "unreachable is not free" boundary visible.
  - Constant-expression validation explicitly rejects unreachable constant expressions, even though ordinary function-body typechecking permits stack-polymorphic unreachable continuation.
- `docs/wiki/wast/control-flow-authoring.md`, `docs/wiki/wast/parametric-instruction-authoring.md`, `docs/wiki/wast/tail-call-authoring.md`, `docs/wiki/wast/exception-tag-authoring.md`, and `docs/wiki/validate/module-validation-phases.md`
  - Existing pages had partial explanations and backlinks; this source bridge supports the new focused validator page and lets those pages link to one canonical bottom/stack-polymorphism contract.

## Durable conclusions

1. WebAssembly stack polymorphism is a validation convenience for unreachable continuations, not dynamic typing and not a blanket waiver for concrete values.
2. Starshine models the spec algorithm with a `reachable` flag plus `BotValType` synthesis from `pop1(...)` when the concrete stack is empty in unreachable code.
3. `set_unreachable(...)` and `set_branch_escape(...)` intentionally clear the old concrete stack so later pops can synthesize bottom below the frame, but any new values pushed afterward remain ordinary stack entries and must be consumed or match declared results.
4. End-of-block and end-of-function checks are the main guardrail against hidden stack junk after terminal instructions.
5. Constant expressions are stricter than ordinary function bodies in Starshine: an unreachable const expression is rejected before the expected one-result type match.
6. Passes that create or remove terminal instructions must re-run validation and must not classify leftover concrete stack values as semantically harmless simply because the path is unreachable.

## Follow-ups

- If the validator grows a closer one-to-one control-frame model, update the focused page with the new mapping from `TcState` / `LabelStack` to the official algorithm.
- If constant-expression validation is widened or narrowed, keep the focused constant-expression page and this bottom/stack-polymorphism page aligned so initializer behavior is not confused with function-body behavior.
