# Relaxed Dead Code Validation Boundary Refresh

_Status:_ immutable source bridge for [`../../wasm-relaxed-dead-code-validation-boundary.md`](../../wasm-relaxed-dead-code-validation-boundary.md), [`../../validate/stack-polymorphism-and-bottom.md`](../../validate/stack-polymorphism-and-bottom.md), and [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md).
_Date:_ 2026-06-05.

## Sources Checked

Primary / standards-process sources:

- WebAssembly proposals tracker, current `main`: <https://github.com/WebAssembly/proposals>
  - The tracker places **Relaxed dead code validation** in **Phase 2 - Proposed Spec Text Available (CG + WG)** with Conrad Watt and Ross Tate as champions.
- Relaxed Dead Code Validation proposal repository README: <https://github.com/WebAssembly/relaxed-dead-code-validation>
  - The repository describes itself as a clone of the WebAssembly spec repository for discussion, prototype specification, and implementation of a proposal to relax current dead-code validation behavior.
- Proposal overview: <https://github.com/WebAssembly/relaxed-dead-code-validation/blob/main/proposals/relaxed-dead-code-validation/Overview.md>
  - It says the proposal aims to make syntactically dead code easier by relaxing validation requirements.
  - It proposes that type-system constraints depending on popping from the type stack are skipped in dead code, while syntactic restrictions and stack-independent checks such as local-index bounds still run.
  - It contrasts current polymorphic-stack behavior with a bottom-form typing notation and sketches an algorithm where reachable checks gate most stack-dependent validation in dead code.
- Proposal push/pop refinement: <https://github.com/WebAssembly/relaxed-dead-code-validation/blob/main/proposals/relaxed-dead-code-validation/Push-Pop.md>
  - It explores reusing push/pop helpers so expected pops and pushes become no-ops in unreachable code, while instructions that need an unconstrained pop, such as `drop` and `select`, remain special cases.
- Current Core 3.0 validation algorithm: <https://webassembly.github.io/spec/core/appendix/algorithm.html>
  - Current Core still carries the `Bot` value type in the validator algorithm and says pushed operands after an unreachable flag is set still participate in stack validation.

Starshine repository evidence:

- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
  - `TcState` stores `stack`, `reachable`, and escape state.
  - `TcState::set_unreachable(...)` clears the concrete stack and marks the state unreachable.
  - `TcState::pop1(...)` synthesizes `ValType::bottom()` only when `reachable == false` and no real concrete stack value is available.
  - `pop_expect(...)`, `check_pop_types_from_top(...)`, and end-stack checks still validate concrete values that were pushed after a nonfallthrough instruction.
- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt)
  - `ValType::bottom()` / `BotValType` remains a local validation-only type carrier and cannot be encoded as a source-level value.
- [`../../../../src/validate/typecheck_negative_tests.mbt`](../../../../src/validate/typecheck_negative_tests.mbt) and [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt)
  - Existing tests cover bottom-pop behavior, unreachable branch merging, insufficient branch payloads, and concrete-stack-junk rejection.
- [`../../wast/control-flow-authoring.md`](../../wast/control-flow-authoring.md) and [`../../validate/stack-polymorphism-and-bottom.md`](../../validate/stack-polymorphism-and-bottom.md)
  - The current living docs explain Core/Starshine stack polymorphism; this bridge adds the active proposal boundary so future wording does not present proposal behavior as current Starshine or Core behavior.

## Durable Takeaways

1. **Relaxed Dead Code Validation is active Phase 2, not Core 3.0.** Treat it as proposal evidence until the official finished/Core sources change.
2. **The proposal changes validation strategy, not instruction syntax.** It does not add WAST keywords or binary opcodes. It relaxes stack-dependent validation checks after syntactically nonfallthrough code.
3. **Current Core and Starshine still use polymorphic-bottom semantics.** Missing operands below an unreachable frame can be synthesized as bottom, but concrete values pushed after the nonfallthrough point are still checked.
4. **Stack-independent checks still matter under the proposal.** Bounds and syntactic checks such as local-index validity remain mandatory, so a future Starshine implementation must not skip all validation in dead code.
5. **Do not conflate this proposal with optimizer dead-code elimination.** It is a validator acceptance policy for syntactically dead instruction sequences, not a pass contract for deleting dead instructions.

## Starshine Boundary

Current Starshine has no proposal gate, CLI option, WAST flag, external-validator adapter mode, generator feature, or typechecker implementation for relaxed dead-code validation. The current validator behavior remains:

- terminal instructions validate their operands first;
- `set_unreachable(...)` clears the concrete stack;
- `pop1(...)` returns `BotValType` only for underflow in an unreachable continuation;
- real values pushed after the terminal point must still match expected result stacks or be consumed.

A future implementation should start with explicit tests that prove the difference between current Core behavior and the relaxed proposal, then add a named feature/config gate before widening parser/validator/fuzzer expectations.

## Links To Update With This Bridge

- Living focused boundary: [`../../wasm-relaxed-dead-code-validation-boundary.md`](../../wasm-relaxed-dead-code-validation-boundary.md)
- Feature-status router: [`../../wasm-feature-status-and-proposal-boundaries.md`](../../wasm-feature-status-and-proposal-boundaries.md)
- Current Core/Starshine validator guide: [`../../validate/stack-polymorphism-and-bottom.md`](../../validate/stack-polymorphism-and-bottom.md)
- WAST control-flow guide: [`../../wast/control-flow-authoring.md`](../../wast/control-flow-authoring.md)
