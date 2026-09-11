---
kind: concept
status: supported
last_reviewed: 2026-09-10
sources:
  - https://github.com/WebAssembly/proposals
  - https://github.com/WebAssembly/stack-switching/blob/main/proposals/stack-switching/Explainer.md
  - wasm-feature-status-and-proposal-boundaries.md
  - wast/exception-tag-authoring.md
  - wast/tail-call-authoring.md
  - validate/stack-polymorphism-and-bottom.md
  - binary/instruction-and-expression-encoding.md
  - fuzzing/generator-coverage-ledger.md
  - ../../src/lib/types.mbt
  - ../../src/validate/validate.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/wast/keywords.mbt
  - ../../src/wast/types.mbt
  - ../../src/validate/gen_valid.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wasm-jspi-host-async-boundary.md
  - wast/exception-tag-authoring.md
  - wast/tail-call-authoring.md
  - validate/stack-polymorphism-and-bottom.md
  - binary/instruction-and-expression-encoding.md
  - fuzzing/generator-coverage-ledger.md
  - tooling/external-validator-adapters.md
---

# Stack Switching Boundary

Starshine now represents continuation types and the binary `cont.new`,
`cont.bind`, `suspend`, `resume`, `resume_throw`, `resume_throw_ref` and `switch`
operations. The Binaryen 132 upgrade adds HOT execution carriers and DAE2
regression coverage. This supersedes the June 5 representation-gap inventory;
that inventory remains in git history.

| Layer | Tested representation and remaining boundary |
| --- | --- |
| Core and binary | Continuation type and instruction carriers decode and encode the represented proposal. |
| Validation | Continuation binding, resume operands, handler payloads and suspension-tag results have type rules. Exception uses require tags with no results. |
| HOT | Construction/binding preserve allocation and consumption effects. Resumption/suspension/switching carry call, branch, trap and exception effects. Resume handlers use stable label identities that lower back to binary depths. |
| DAE2 | Continuation-associated signatures stay fixed. Private direct-only functions may still receive independent signatures. Upstream intake covers construction, binding, resume, resume_throw and stack switching. |
| GenValid | The `dae2-continuations` member varies construction, binding, execution, suspension and handler branches. The dedicated aggregate also includes unrelated removable private results. |
| WAST | The general continuation text-authoring surface remains separate parser work. Binary/core fixtures provide the tested intake route. |
| Execution | Structural validation does not establish runtime support. Record each external engine's capabilities and report unsupported continuation execution explicitly. |

The [upgrade record](binaryen/version-132-upgrade.md) identifies the executable
hashes, exact fixture intake and campaign status. Do not infer support for every
optimizer from DAE2's targeted continuation tests.

The implementation is in [core types](../../src/lib/types.mbt),
[typing](../../src/validate/typecheck.mbt),
[HOT continuation targets](../../src/ir/hot_continuation.mbt),
[lifting](../../src/ir/hot_lift.mbt), [lowering](../../src/ir/hot_lower.mbt),
[DAE2 intake](../../src/passes/dead_argument_elimination2_intake_wbtest.mbt), and
[GenValid](../../src/validate/gen_valid_dae2.mbt).

Tags can have results at declaration time. `throw`, modern tagged catches,
legacy tagged catches and `resume_throw` retain the exception-use restriction;
`suspend` and resume handlers use the full control-tag signature. The
[positive and negative tests](../../src/validate/binaryen132_continuation_wbtest.mbt)
cover that distinction. Invalid GenValid mutations now throw a result-bearing
tag instead of incorrectly treating its declaration as invalid.

Typed continuations are distinct from [JSPI](wasm-jspi-host-async-boundary.md),
[ordinary exception handling](wasm-exception-handling-boundary.md),
[tail calls](wast/tail-call-authoring.md), and
[unreachable stack polymorphism](validate/stack-polymorphism-and-bottom.md).
The proposal's exact draft is part of compatibility; do not infer current
standardization status from a historical upstream fixture.
