---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-relaxed-dead-code-validation-boundary-refresh.md
  - raw/wasm/2026-06-04-stack-polymorphism-current-refresh.md
  - ../../src/validate/typecheck.mbt
  - ../../src/validate/typecheck_negative_tests.mbt
  - ../../src/validate/validate.mbt
  - ../../src/lib/types.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - validate/stack-polymorphism-and-bottom.md
  - validate/module-validation-phases.md
  - wast/control-flow-authoring.md
  - wast/parametric-instruction-authoring.md
  - wast/tail-call-authoring.md
  - wast/exception-tag-authoring.md
  - binaryen/passes/dead-code-elimination/index.md
---

# Relaxed Dead Code Validation Boundary

## Overview

Use this page when a claim mentions **Relaxed Dead Code Validation**, dead-code validator behavior, bottom values, stack polymorphism, or unreachable-code fixtures.

Relaxed Dead Code Validation is an active WebAssembly proposal about **validation policy inside syntactically dead code**. It is not an optimizer pass and it does not add new instructions. Its goal is to make dead instruction sequences easier to validate by skipping stack-dependent type-system constraints after code is already known not to execute, while keeping syntax and stack-independent checks such as local-index bounds.

The current source bridge is [`raw/wasm/2026-06-05-relaxed-dead-code-validation-boundary-refresh.md`](raw/wasm/2026-06-05-relaxed-dead-code-validation-boundary-refresh.md). It checked the official WebAssembly proposals tracker, the proposal repository overview and push/pop refinement, the current Core 3.0 validation algorithm, and current Starshine typechecker/tests.

Current Starshine implements the **Core/Starshine stack-polymorphism model** documented in [`validate/stack-polymorphism-and-bottom.md`](validate/stack-polymorphism-and-bottom.md), not the relaxed proposal. Missing operands below an unreachable frame can be synthesized as `BotValType`, but concrete values pushed after the terminal point are still real stack entries and still participate in end-stack checks.

## Beginner Model

Consider a function body after a terminal instruction:

```wat
(func
  unreachable
  i32.add)
```

Current Core-style stack polymorphism lets the validator invent bottom values for the missing `i32.add` operands because the continuation cannot execute.

But this is different:

```wat
(func
  (block
    return
    i32.const 1))
```

Starshine rejects this kind of leftover concrete stack value today. The `i32.const 1` is real code after the terminal point. It is dead at runtime, but the current validator still sees a concrete value and checks the block/function result stack.

The relaxed proposal asks whether more of those dead-code stack constraints should be skipped. That is a future validator-widening question for Starshine, not current behavior.

## Current Core/Starshine Versus Proposal

| Surface | Current Core / current Starshine | Relaxed Dead Code Validation proposal | Starshine status |
| --- | --- | --- | --- |
| Instruction syntax | No new syntax; ordinary `unreachable`, branches, returns, tail calls, and throws create nonfallthrough continuations. | No new syntax; proposal is about validator rules. | No WAST parser or binary changes needed for the proposal boundary itself. |
| Missing operands after unreachable | Current validator may synthesize bottom values for missing operands below an unreachable frame. | Retains the idea that dead code should not need ordinary stack operands. | Implemented today via `TcState::pop1(...)` returning `ValType::bottom()` only in unreachable underflow. |
| Concrete values pushed after terminal code | Still checked; concrete stack junk can make a block/body invalid. | Proposal relaxes stack-dependent constraints in dead code more broadly. | Not implemented; current tests deliberately reject concrete stack junk after `return` / unreachable paths. |
| Stack-independent checks | Still checked. | Still checked; examples include syntactic restrictions and local-index bounds. | Already checked today; a future relaxed mode must preserve this class. |
| Feature status | Core 3.0 stack-polymorphism behavior. | Active Phase 2 proposal row as of the 2026-06-05 recheck. | No feature gate, CLI flag, generator gate, or validator mode. |
| Optimizer dead-code passes | Separate transforms such as Binaryen `dead-code-elimination` or Starshine cleanup passes may remove instructions if they prove safety. | Not an optimizer pass. | Do not cite this proposal as pass parity evidence. |

## Starshine Implementation Map

| Local surface | File / tests | What it proves |
| --- | --- | --- |
| Validation state | [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) | `TcState` stores `stack`, `reachable`, escape state, and reachable branch-escape summaries. |
| Current unreachable transition | [`TcState::set_unreachable(...)`](../../src/validate/typecheck.mbt) | Clears the concrete stack, marks the continuation unreachable, and records terminal escape. |
| Bottom synthesis | [`TcState::pop1(...)`](../../src/validate/typecheck.mbt) | Returns `ValType::bottom()` only when the real stack underflows in an unreachable state. |
| Bottom type carrier | [`ValType::bottom()` / `BotValType`](../../src/lib/types.mbt) | Local validator-only bottom value; binary encoding rejects bottom value types. |
| Current negative evidence | [`src/validate/typecheck_negative_tests.mbt`](../../src/validate/typecheck_negative_tests.mbt), [`src/validate/validate.mbt`](../../src/validate/validate.mbt) | Bottom-pop tests, branch payload checks, unreachable branch merges, and concrete-stack-junk rejection. |
| WAST authoring | [`wast/control-flow-authoring.md`](wast/control-flow-authoring.md) | Human-facing syntax and rewrite guidance for current control-flow fixtures. |

## Validation And Future-Port Checklist

If Starshine ever implements a relaxed-dead-code mode:

1. **Add a named feature/config gate first.** Do not silently widen the default validator without deciding whether the proposal should be enabled by default, only for adapter parity, or only for fuzzing experiments.
2. **Write contrast tests.** Include fixtures that fail under current Core/Starshine stack-polymorphism because of dead concrete stack junk and pass only under the relaxed mode.
3. **Keep stack-independent checks live.** Invalid local/global/table/data/type indices, malformed immediates, invalid labels, and other checks not dependent on popping the value stack must remain rejected.
4. **Do not use it as an optimizer shortcut.** A pass that deletes or reorders dead instructions still needs ordinary validity and effect/trap proof. Validator relaxation is not proof that dead code can be arbitrarily moved.
5. **Classify external-tool disagreements carefully.** A wasm accepted by a relaxed-dead-code-aware tool and rejected by current Starshine is a proposal-support difference unless the repo intentionally enabled a matching mode.
6. **Update generators separately.** A valid-module generator may choose to produce relaxed-only dead-code cases only behind a dedicated feature/profile gate.

## Wording Rules

Prefer:

- “Starshine follows current Core-style stack polymorphism here; it does not implement Relaxed Dead Code Validation.”
- “This fixture relies on proposal-relaxed dead-code stack checks, not merely ordinary `unreachable` bottom synthesis.”
- “Relaxed Dead Code Validation is validator-policy proposal work, not Binaryen `dead-code-elimination` pass evidence.”

Avoid:

- “Dead code is ignored by validation.” It is too broad; current Starshine still checks concrete stack junk and all ordinary syntax/index constraints.
- “Bottom means any later values are free.” Bottom only stands in for missing operands below an unreachable frame.
- “Starshine supports relaxed dead code.” There is no current feature gate or implementation.

## Sources

- Focused source bridge: [`raw/wasm/2026-06-05-relaxed-dead-code-validation-boundary-refresh.md`](raw/wasm/2026-06-05-relaxed-dead-code-validation-boundary-refresh.md)
- Current Core/Starshine stack-polymorphism guide: [`validate/stack-polymorphism-and-bottom.md`](validate/stack-polymorphism-and-bottom.md)
- Feature-status router: [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md)
- Current typechecker: [`../../src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt)
- Current validation tests: [`../../src/validate/typecheck_negative_tests.mbt`](../../src/validate/typecheck_negative_tests.mbt), [`../../src/validate/validate.mbt`](../../src/validate/validate.mbt)
