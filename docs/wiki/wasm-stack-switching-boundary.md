---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-stack-switching-boundary-refresh.md
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

## Overview

Use this page when a Starshine or WebAssembly claim mentions **Stack Switching**, **typed continuations**, `(cont ...)`, `cont.new`, `cont.bind`, `suspend`, `resume`, `resume_throw`, `resume_throw_ref`, `switch`, coroutine/generator stackful control flow, or continuation-aware Binaryen fixtures.

For beginners: ordinary WebAssembly calls run on one current call stack. Tail calls, branches, throws, and `try_table` change control flow, but they do not create a first-class suspended stack. The Stack Switching proposal adds typed continuations so Wasm code can suspend one stack, resume another, and route control through typed handlers. That is a Core-module proposal surface, not a JavaScript Promise wrapper and not the same as Starshine's current stack-polymorphic unreachable-code validation.

The current source bridge is [`raw/wasm/2026-06-05-stack-switching-boundary-refresh.md`](raw/wasm/2026-06-05-stack-switching-boundary-refresh.md). It rechecked the current WebAssembly proposals tracker, the Stack Switching proposal repository and explainer, readable WasmFX typed-continuation mirrors, current Starshine core/WAST/binary/validation/generator sources, and nearby wiki pages.

## Current Status Rule

Treat Stack Switching as **active Phase-3 proposal evidence** and a **future Core-module type/instruction/control-flow boundary**:

- **not finished/Core WebAssembly 3.0** until the finished-proposals table and Core spec pages say so;
- **not Starshine support** unless the exact local layer is implemented and tested;
- **not JSPI**: JavaScript Promise Integration is a separate host-async JavaScript API surface;
- **not current exception support**: Starshine's current tags/`try_table` lane still validates exception tags as empty-result function types;
- **not ordinary stack polymorphism**: local unreachable-bottom synthesis is a validator rule, not a first-class suspended-stack representation.

The active proposal tracker can move. Use this focused 2026-06-05 bridge for current Stack Switching routing and preserve older raw captures as historical evidence rather than silently rewriting them.

## What Stack Switching Means In Practice

The proposal-facing vocabulary is about typed continuation values and resumable control transfer:

```wat
;; Proposal-shape sketch only: not current Starshine WAST support.
(type $work (func (param i32) (result i32)))
(type $k (cont $work))

(func $producer (type $work)
  ;; Stack Switching proposal surface includes suspend/resume-style control.
  ;; Starshine does not parse, lower, decode, validate, or generate this today.
)
```

The exact proposal syntax and validation rules can change. The stable local takeaway is the routing rule: continuation types and `cont.*` / `resume*` / `suspend` / `switch` operations are a dedicated proposal family. Do not file them as ordinary `try_table`, tail-call, JSPI, stack-polymorphism, or Binaryen-pass support.

## Current Starshine Boundary

| Surface | Current Starshine evidence | Stack Switching status |
| --- | --- | --- |
| Core AST/types | [`src/lib/types.mbt`](../../src/lib/types.mbt) has ordinary control instructions, tail calls, `Throw`, `ThrowRef`, and `TryTable`. It has no continuation type carrier and no `cont.new`, `cont.bind`, `suspend`, `resume`, `resume_throw`, `resume_throw_ref`, or `switch` instruction variants. | No local representation support. |
| Tags/control tags | [`src/validate/validate.mbt`](../../src/validate/validate.mbt) validates `TagType` through a function type and rejects non-empty tag results. | Current exception-tag support is not Stack Switching control-tag support. |
| Binary bytes | [`src/binary/decode.mbt`](../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../src/binary/encode.mbt) handle current control opcodes such as `try_table` (`0x1f`) and ordinary locals (`0x20`-`0x22`), but no proposal `0xe0`-`0xe6` continuation instruction family. | No decode/encode support. |
| WAST text | [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt) and [`src/wast/types.mbt`](../../src/wast/types.mbt) expose ordinary control, tail-call, exception, reference, GC, memory/table, numeric, and SIMD keywords/opcodes. | No `cont.*`, `suspend`, `resume*`, or `switch` text surface. |
| Validation and typing | Current validation pages cover ordinary module phases, exception tags, function bodies, stack polymorphism, tail calls, and reference families. | No continuation typing, handler typing, control-tag result typing, or resume/suspend validation. |
| Generator/fuzzing | [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt) has proposal-feature gates for existing local families such as GC, function references, tail calls, exceptions, SIMD, relaxed SIMD, atomics, bulk memory, multi-memory, memory64, extended const, and reference types. | No Stack Switching gate or profile. |
| Optimizer/pass evidence | Some Binaryen pass dossiers mention stack-switching fixtures as upstream proof surfaces. | Binaryen oracle evidence only; not Starshine WAST/binary/validator/generator/pass support unless a future local pass explicitly handles the family. |

## Do Not Conflate With Nearby Features

| Nearby feature | Why it is different | Routing |
| --- | --- | --- |
| JSPI | JSPI wraps Promise-returning host imports and exported functions in the JavaScript embedding. It does not add Starshine continuation types or `cont.*` core instructions. | [`wasm-jspi-host-async-boundary.md`](wasm-jspi-host-async-boundary.md) |
| Exception handling / `try_table` | Current Starshine exception tags have empty result lists and `try_table` catches transfer exception payloads. Stack Switching extends control-flow with resumable typed continuations and control tags. | [`wast/exception-tag-authoring.md`](wast/exception-tag-authoring.md) |
| Tail calls | Tail calls exit the current function by returning through a callee. They do not create, bind, suspend, or resume first-class continuations. | [`wast/tail-call-authoring.md`](wast/tail-call-authoring.md) |
| Stack polymorphism and bottom | Starshine's unreachable-bottom model permits missing operands after nonfallthrough control. It is a validation convenience, not dynamic suspended-stack state. | [`validate/stack-polymorphism-and-bottom.md`](validate/stack-polymorphism-and-bottom.md) |
| Binaryen pass fixtures | Upstream tests such as DCE, precompute, unsubtyping, or JS-interface pruning may mention stack-switching forms. They prove Binaryen pass contracts, not local Starshine feature support. | [`tooling/external-validator-adapters.md`](tooling/external-validator-adapters.md), [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md) |

## Future Implementation Checklist

If Starshine decides to support Stack Switching, start with an explicit representation and validation slice:

1. **Representation:** add continuation composite/heap/reference type carriers and instruction variants for the proposal family.
2. **Tag policy:** decide how proposal control tags coexist with current exception tags and update tag-result validation deliberately.
3. **Binary:** implement proposal type encodings and instruction opcode handling only after rechecking the current draft bytes.
4. **WAST:** add keyword parsing, lowering, printing, identifier resolution, and roundtrip tests for continuation types, handlers, and instructions.
5. **Validation:** test handler typing, resume/suspend stack shapes, control-tag result flow, reference subtyping, and interaction with ordinary exception/tail-call control.
6. **Generator:** add a dedicated feature gate/profile before producing proposal-shaped modules.
7. **Optimizer/IR:** classify continuation operations for effects, traps, terminators, label liveness, CFG, local SSA, and pass bailouts.
8. **External tools:** classify `wasm-tools`, WABT, Binaryen, or runtime disagreements as proposal-support/tooling facts before treating them as Starshine bugs.
9. **Docs:** update this page, [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md), [`wast/index.md`](wast/index.md), focused WAST/binary/validation/generator pages, and [`index.md`](index.md) together.

Do **not** start by adding a pass-only exception or treating Binaryen Stack Switching fixtures as locally parseable input. Current evidence points to missing representation, binary, WAST, validation, and generator layers first.

## Source Map

- Current source bridge: [`raw/wasm/2026-06-05-stack-switching-boundary-refresh.md`](raw/wasm/2026-06-05-stack-switching-boundary-refresh.md)
- Shared feature-status router: [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md)
- JSPI boundary: [`wasm-jspi-host-async-boundary.md`](wasm-jspi-host-async-boundary.md)
- Exception-tag authoring: [`wast/exception-tag-authoring.md`](wast/exception-tag-authoring.md)
- Tail-call authoring: [`wast/tail-call-authoring.md`](wast/tail-call-authoring.md)
- Stack-polymorphism validation: [`validate/stack-polymorphism-and-bottom.md`](validate/stack-polymorphism-and-bottom.md)
- Binary instruction map: [`binary/instruction-and-expression-encoding.md`](binary/instruction-and-expression-encoding.md)
- Generator coverage ledger: [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md)
- Current local sources: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/validate/validate.mbt`](../../src/validate/validate.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`../../src/wast/types.mbt`](../../src/wast/types.mbt), [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt)
