---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-20-stack-polymorphism-and-bottom-sources.md
  - ../raw/wasm/2026-05-19-wast-control-flow-sources.md
  - ../raw/wasm/2026-05-20-wast-parametric-select-sources.md
  - ../raw/wasm/2026-06-04-runtime-trap-current-refresh.md
  - ../../../src/lib/types.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/typecheck_negative_tests.mbt
  - ../../../src/validate/validate.mbt
related:
  - ./module-validation-phases.md
  - ./constant-expressions.md
  - ./runtime-trap-semantics.md
  - ../wast/control-flow-authoring.md
  - ../wast/parametric-instruction-authoring.md
  - ../wast/tail-call-authoring.md
  - ../wast/exception-tag-authoring.md
  - ../wast/reference-instruction-authoring.md
  - ../binary/instruction-and-expression-encoding.md
---

# Stack Polymorphism And Bottom Values

## Overview

WebAssembly validation treats code after a nonfallthrough instruction as **stack-polymorphic**. In plain terms: once local execution cannot reach the next instruction, the validator may synthesize missing operands of any type so it can keep checking the rest of the expression tree.

Starshine models that rule with a `reachable` flag in [`TcState`](../../../src/validate/typecheck.mbt) and a local bottom value, [`ValType::bottom()` / `BotValType`](../../../src/lib/types.mbt). This page owns the focused validator contract. Use it when a pass, fixture, reducer, or wiki claim mentions `unreachable`, `return`, `br`, `br_table`, tail calls, throws, "bottom", stack underflow in unreachable code, or leftover stack values after a terminal instruction. Use [`runtime-trap-semantics.md`](runtime-trap-semantics.md) for the separate execution-time trap/`RuntimeError`/`mayTrap` vocabulary.

The source bridge is [`../raw/wasm/2026-05-20-stack-polymorphism-and-bottom-sources.md`](../raw/wasm/2026-05-20-stack-polymorphism-and-bottom-sources.md). It rechecked the current WebAssembly validation-instruction and validation-algorithm sources plus Starshine's typechecker, validator diagnostics, and regression tests.

## Beginner Model

A reachable instruction must find its operands on the real stack:

```wat
(func (result i32)
  i32.add) ;; invalid: reachable code has no two i32 operands
```

After `unreachable`, the continuation is not reachable. Missing operands can be supplied virtually:

```wat
(func (result i32)
  unreachable
  i32.add) ;; locally stack-polymorphic: the missing add inputs may be bottom
```

That does **not** mean every later value is ignored. Values pushed after the terminal point are real concrete values:

```wat
(func
  (block
    return
    i32.const 1)) ;; invalid in Starshine: concrete stack junk remains at block end
```

This last rule is the most important maintenance boundary: **unreachable permits virtual missing inputs, but it does not erase concrete values produced after the path became unreachable.**

## Official Model Versus Starshine Model

| Concept | Official validation-algorithm intuition | Starshine implementation |
| --- | --- | --- |
| Operand stack | Typed value stack under a control frame. | `TcState.stack : Array[ValType]` in [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt). |
| Control-frame reachability | A control frame can be marked unreachable and then has stack-polymorphic underflow behavior. | `TcState.reachable : Bool`; `set_unreachable(...)` and `set_branch_escape(...)` clear the concrete stack and mark the state nonfallthrough. |
| Bottom value | A virtual stack value that can match an expected type when underflow happens in unreachable code. | `BotValType`; [`TcState::pop1(...)`](../../../src/validate/typecheck.mbt) returns `ValType::bottom()` only when `reachable == false` and the real stack is empty. |
| Concrete pushed values | Values pushed after unreachable are still real entries and are popped before any virtual bottom is synthesized. | The real `stack.pop()` path in `pop1(...)` wins before bottom synthesis. End-stack checks reject leftover concrete values. |
| Branch escapes | Branches to surrounding labels can make the current nested body nonfallthrough while allowing the target construct to merge. | `BranchTcEscape(depth)` and `reachable_escape_depths` record which reachable branch exits can make a parent merge reachable. |

Starshine is not a byte-for-byte copy of the appendix algorithm, but the invariant is the same: virtual bottom appears only below the current unreachable frame. It is not a stored runtime value and it should not leak into encoded modules.

## What Makes Continuation Unreachable

These instruction families can make the local continuation nonfallthrough after their own operands validate:

- `unreachable` directly marks the state unreachable.
- `return` consumes the current function results and exits.
- `br` and `br_table` consume their label payloads and branch away.
- Tail calls (`return_call`, `return_call_indirect`, `return_call_ref`) validate callee/table/reference requirements and then exit the current function; see [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md).
- `throw` and `throw_ref` consume exception operands and then exit through exception control; see [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md).
- Reference branch instructions have branch-path and fallthrough-path type refinements; see [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md).

By contrast, `br_if`, `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` are conditional. They can record a reachable branch escape, but their fallthrough path remains reachable and must account for the remaining stack values.

## Concrete Shapes

### Missing operands after `unreachable` are accepted

[`src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt) locks the direct mechanics:

- `Typecheck unreachable pop1 returns bot (polymorphic stack)`
- `Typecheck unreachable pop_expect succeeds for any type`
- `Typecheck unreachable pop_types succeeds for any types`

Those tests prove the local bottom behavior without depending on any specific WAST parser shape.

### Unreachable branches can merge with reachable branches

An `if` where one branch is unreachable and the other branch produces the result can still be reachable after the `if`:

```wat
(func (param i32) (result i32)
  local.get 0
  if (result i32)
    unreachable
  else
    i32.const 1
  end)
```

The validator uses the reachable branch's result. If both branches are nonfallthrough, the `if` continuation is nonfallthrough too. The focused tests are `Typecheck if with one unreachable branch merges to reachable` and `Typecheck if with both unreachable branches yields unreachable` in [`src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt).

### Branch payload checks still happen first

A branch instruction is only terminal after its own operands validate. For example, a reachable `br` to a label expecting `[i32, i64]` still fails if those payload values are missing. The test `Typecheck br with insufficient stack for label types` keeps that distinction visible.

### `br_if` fallthrough keeps payload values

`br_if` is conditional. It validates the target payload, pops the `i32` condition, and leaves the payload on the not-taken path. The WAST-facing explanation and examples live in [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md); the typechecker owner is `typecheck_br_if(...)` in [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt).

### Concrete stack junk is rejected

The validator still checks block/function result stacks. [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) has focused regressions:

- `validate_module reports end-of-body underflow with stack shape`
- `validate_module reports wrong end-of-body result type with stack shape`
- `validate_module reports end-of-body extra values with stack shape`
- `validate_module rejects concrete stack junk after return inside block`
- `validate_module rejects wrong concrete loop result after infinite inner loop`

Use these as examples when explaining why a pass cannot leave arbitrary constants after a terminal instruction just because that local path is unreachable.

## Constant Expressions Are Stricter

Module-level constant expressions reuse instruction typechecking, but Starshine adds a reachability check in [`validate_const_expr(...)`](../../../src/validate/validate.mbt): an unreachable constant expression is rejected. That is deliberate because initializers and active offsets must produce one concrete value of the expected type.

Use [`constant-expressions.md`](constant-expressions.md) for the full initializer/offset allow-list, immutable-`global.get` visibility, and local/spec differences. Do not use ordinary function-body stack polymorphism as evidence that an initializer may be unreachable.

## Pass And Fixture Guidance

When an optimization or generator creates, removes, or moves a terminal instruction:

1. **Validate the terminal instruction itself.** `return`, `br`, `br_table`, tail calls, and throws still need their operands before continuation becomes unreachable.
2. **Do not preserve dead concrete junk accidentally.** If a rewrite inserts constants, locals, or calls after a terminal instruction inside a resultful block, those concrete values still participate in end-stack checks.
3. **Keep branch escapes distinct from terminal escapes.** A branch to an enclosing label can make that enclosing construct reachable even when the nested body is nonfallthrough. Do not collapse every nonfallthrough child to unconditional function exit.
4. **Prefer focused WAST pages for syntax.** Ordinary labels and `br_if` payload behavior live in [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md); `drop` / `select` stack behavior lives in [`../wast/parametric-instruction-authoring.md`](../wast/parametric-instruction-authoring.md); tail-call and exception syntax have their own pages.
5. **Record semantic evidence for mismatch classification.** If a compare-pass mismatch depends on unreachable cleanup, cite the transform contract or a reduced validation result. Do not call it safe merely because both outputs validate.

## Code Map

| Surface | File / tests | What it proves |
| --- | --- | --- |
| Bottom value | [`src/lib/types.mbt`](../../../src/lib/types.mbt) | `ValType` includes `BotValType`; `ValType::bottom()` constructs it. |
| State model | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) | `TcState` carries `stack`, `reachable`, `escape`, and reachable branch-escape summaries. |
| Bottom synthesis | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) | `pop1(...)` returns bottom only for underflow in unreachable states; `pop_expect(...)` accepts bottom for any expected type. |
| End-stack checks | [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) | `validate_end_stack(...)` and function-body diagnostics reject underflow, mismatched results, and extra concrete values. |
| Regression coverage | [`src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt), [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`src/validate/validate.mbt`](../../../src/validate/validate.mbt) | Bottom-pop tests, if/loop/block reachability tests, descriptor bottom tests, end-body stack-shape tests, and concrete-junk rejection tests. |
| Related authoring docs | [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md), [`../wast/parametric-instruction-authoring.md`](../wast/parametric-instruction-authoring.md), [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md), [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md), [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md) | Human-facing syntax and fixture guidance for the instruction families that interact with unreachable continuations. |

## Sources

- Source bridge: [`../raw/wasm/2026-05-20-stack-polymorphism-and-bottom-sources.md`](../raw/wasm/2026-05-20-stack-polymorphism-and-bottom-sources.md)
- Runtime trap source refresh for the execution/host boundary: [`../raw/wasm/2026-06-04-runtime-trap-current-refresh.md`](../raw/wasm/2026-06-04-runtime-trap-current-refresh.md)
- Earlier control-flow source manifest: [`../raw/wasm/2026-05-19-wast-control-flow-sources.md`](../raw/wasm/2026-05-19-wast-control-flow-sources.md)
- Official WebAssembly sources checked: <https://webassembly.github.io/spec/core/valid/instructions.html>, <https://webassembly.github.io/spec/core/appendix/algorithm.html>, <https://webassembly.github.io/spec/core/valid/modules.html>, <https://webassembly.github.io/spec/core/syntax/instructions.html>
- Starshine implementation and tests: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/typecheck_negative_tests.mbt`](../../../src/validate/typecheck_negative_tests.mbt), [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt)
