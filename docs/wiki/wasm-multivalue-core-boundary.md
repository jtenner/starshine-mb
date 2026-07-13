---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - raw/wasm/2026-07-11-multivalue-core-boundary-recheck.md
  - ../../src/lib/types.mbt
  - ../../src/wast/parser.mbt
  - ../../src/wast/lower_to_lib.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/validate/gen_valid.mbt
  - ../../src/validate/invalid_fuzzer.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wast/control-flow-authoring.md
  - wast/function-call-and-module-authoring.md
  - wast/parametric-instruction-authoring.md
  - binary/instruction-and-expression-encoding.md
  - validate/stack-polymorphism-and-bottom.md
  - fuzzing/generator-coverage-ledger.md
  - binaryen/passes/tuple-optimization/index.md
---

# WebAssembly Multi-value Core Boundary

## Overview

**Multi-value** means that a WebAssembly function or structured-control construct can consume or produce an ordered sequence of stack values, such as `(i32, i64)`. It is finished/Core WebAssembly behavior, not an active-proposal feature flag and not one opaque runtime tuple value.

```text
function result:       [] -> [i32, i64]
call to that function: ... -> ..., i32, i64
block with those results: ... -> ..., i32, i64
branch to that block:  supply i32, i64; no local fallthrough
```

This page is the cross-layer map. Use it before treating a multi-value failure as a parser, binary, validator, IR, or pass problem. The source reconciliation is [`raw/wasm/2026-07-11-multivalue-core-boundary-recheck.md`](raw/wasm/2026-07-11-multivalue-core-boundary-recheck.md).

## Core Model

A function type has ordered parameter and result arrays. A result is not a tuple object: the producer pushes individual values in declaration order and the consumer pops the corresponding ordered sequence.

| Surface | Example | Meaning |
| --- | --- | --- |
| Function signature | `(func (result i32 i64) ...)` | The function leaves `i32` below `i64` on its result stack. |
| Direct call | `call $pair` | Pops every parameter, then pushes both declared results. |
| Block / `if` result | `(block (result i32 i64) ...)` | A reachable fallthrough path must leave both results. |
| Block / loop parameters | `(loop (param i32) (result i64) ...)` | The outer stack supplies the parameter; a branch back to the loop supplies the parameter, while loop fallthrough supplies the result. |
| Branch payload | `br $exit` | A branch to `block`/`if` supplies its result vector; a branch to `loop` supplies its parameter vector. |

A compact single-result block type such as `(block i32 ...)` is only shorthand. The general form is a function type use.

```wat
(module
  (type $pair (func (result i32 i64)))

  (func $make-pair (type $pair)
    i32.const 7
    i64.const 9)

  (func (result i32 i64)
    (block $exit (type $pair)
      (br $exit
        (i32.const 7)
        (i64.const 9)))))
```

Both `$make-pair` and `$exit` have the same ordered result contract. Reversing the payload to `i64` then `i32`, dropping either lane, or leaving an extra value is invalid.

## Why Multi-value Blocks Need a Type Index

The binary block-type immediate has three forms:

| Block type | Core representation | Binary carrier |
| --- | --- | --- |
| no params/results | `VoidBlockType` | `0x40` |
| one result, no params | `ValTypeBlockType(vt)` | value-type byte |
| params or multiple results | `TypeIdxBlockType(typeidx)` | signed `s33` type index |

The third row is the important one: a multi-result block cannot carry two result bytes inline. It refers to a function type whose parameter and result vectors describe the control boundary.

Starshine makes this explicit in [`src/lib/types.mbt`](../src/lib/types.mbt): `FuncType` contains parameter/result arrays, while `BlockType` is void, one value type, or a type index. [`src/wast/lower_to_lib.mbt`](../src/wast/lower_to_lib.mbt) keeps the compact forms for void/single-result inline text, but creates or resolves a function type and emits `TypeIdxBlockType` for parameterized or multi-result control. [`src/binary/decode.mbt`](../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../src/binary/encode.mbt) preserve the same three-way byte model.

## Validation: Every Lane Matters

The validator operates on whole type arrays, not a special pair type:

1. A `block`, `loop`, or `if` expands its block type into `(params, results)`.
2. It pops all parameters from the outer stack and starts its child body with those parameters.
3. A `block` or `if` label is typed with `results`; a `loop` label is typed with `params`.
4. A reachable child exit must leave exactly `results`; the outer continuation receives every result in order.

[`src/validate/typecheck.mbt`](../src/validate/typecheck.mbt) implements this through `expand_blocktype`, array-based `pop_types` / `push_types`, and the structured-control checkers. The same array discipline applies to calls and returns: `typecheck_call`, `typecheck_call_indirect`, and `typecheck_call_ref` pop all declared parameters and push all declared results; `return` consumes the enclosing function's complete result vector.

### Branch payload example

```wat
(module
  (func (param i32) (result i32 i64)
    (block $done (result i32 i64)
      i32.const 10
      i64.const 20
      local.get 0
      br_if $done
      ;; not-taken `br_if` keeps both payload lanes on the stack
      return)))
```

The `br_if` taken path transfers both lanes to `$done`. On the not-taken path it removes only the condition, so the `i32` and `i64` payload values remain. This is the multi-value version of the ordinary fallthrough rule in [`wast/control-flow-authoring.md`](wast/control-flow-authoring.md).

`br_table` is stricter still: every listed target and the default must accept equivalent full payload vectors. The invalid-fuzzer's `invalid-function-body-br-table-multivalue-payload-arity-mismatch` specimen is focused local regression evidence for this boundary; see [`src/validate/invalid_fuzzer.mbt`](../src/validate/invalid_fuzzer.mbt).

## WAST Authoring Rules

- Use repeated result types where the signature itself is the subject: `(result i32 i64)`.
- Use `(type $sig)` for reusable or named multi-value signatures.
- Use explicit `(param ...)` / `(result ...)` block type uses for parameterized or multi-result control. The one-token `block i32` shorthand covers only one result.
- Give each lane a consumer. A void function cannot quietly leave two values at its end, and a branch payload must match its target's complete ordered contract.
- Keep **typed `select`** separate. Starshine carries `Select(Array[ValType]?)`, including local multi-value typed-select regression coverage, but the portability caveat is owned by [`wast/parametric-instruction-authoring.md`](wast/parametric-instruction-authoring.md), not by ordinary Core multi-value.

[`src/wast/parser.mbt`](../src/wast/parser.mbt) has focused parsing coverage for a function type with multiple results. [`src/wast/lower_to_lib.mbt`](../src/wast/lower_to_lib.mbt) is the source of truth for converting an inline WAST type use into compact or type-indexed core control.

## Starshine Support Map

| Layer | Current support | Evidence |
| --- | --- | --- |
| Core model | Function param/result arrays; structured control references a `BlockType`. | [`src/lib/types.mbt`](../src/lib/types.mbt) |
| WAST | Repeated function results plus block `TypeUse` parsing/lowering. | [`src/wast/parser.mbt`](../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../src/wast/lower_to_lib.mbt) |
| Binary | Function type vectors and void/single/type-index block-type carriers roundtrip. | [`src/binary/decode.mbt`](../src/binary/decode.mbt), [`src/binary/encode.mbt`](../src/binary/encode.mbt), [`src/binary/tests.mbt`](../src/binary/tests.mbt) |
| Validation | Whole-vector parameters, results, calls, returns, labels, and branch payloads. | [`src/validate/typecheck.mbt`](../src/validate/typecheck.mbt) |
| Valid generation | `MultivalueControlFlow` records current generated control coverage, including type-indexed blocks. | [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt), [`src/validate/validate.mbt`](../src/validate/validate.mbt), [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md) |
| Invalid generation | Focused invalid `br_table` arity mutation and repair. | [`src/validate/invalid_fuzzer.mbt`](../src/validate/invalid_fuzzer.mbt) |
| IR / passes | Support is pass-specific. HOT/control/payload rewrites must prove every lane's order, type, branch target, effects, and traps. | [`ir2/cfg-contract.md`](ir2/cfg-contract.md), pass-local tests and dossiers |

A pass's raw skip around multi-value control is therefore a conservative optimization boundary, **not** a general Core-feature gap. For example, Binaryen's `tuple-optimization` concerns its internal tuple-local representation; Starshine's documented narrow spill-carrier work is not a claim that WebAssembly itself has a tuple instruction. See [`binaryen/passes/tuple-optimization/index.md`](binaryen/passes/tuple-optimization/index.md).

## Pass And Validation Checklist

When a transform touches a multi-value function, call, branch, or control node:

1. Preserve the complete ordered parameter/result vectors, not just arity.
2. Preserve the loop-versus-block label distinction: loop branches use parameters; block/if branches use results.
3. Preserve `br_if` fallthrough payload lanes and require all `br_table` targets to agree.
4. Update/reuse the referenced function type if a block's parameter/result signature changes; never leave a stale `TypeIdxBlockType`.
5. Re-run module validation after mutation. Use [`tooling/validation-gates.md`](tooling/validation-gates.md) and, for an upstream pass, its documented Binaryen-oracle lane.
6. Add a positive multi-lane fixture and the nearest wrong-arity, wrong-order, or wrong-target negative. Generator coverage is positive evidence; it does not replace invalid-payload tests.

## Boundaries And Non-goals

- Multi-value is Core 3.0 / finished behavior. It is not the active Wide Arithmetic proposal merely because that proposal would return two `i64` values; see [`wasm-wide-arithmetic-boundary.md`](wasm-wide-arithmetic-boundary.md).
- This page does not settle Starshine's separate tail-call result-subtyping divergence; see [`wast/tail-call-authoring.md`](wast/tail-call-authoring.md) and [`validate/local-spec-divergence-ledger.md`](validate/local-spec-divergence-ledger.md).
- This page does not prove arbitrary pass parity. Any rewrite that reorders, drops, duplicates, spills, or reconstructs lanes needs transform-specific evidence.

## Sources

- Primary/source reconciliation: [`raw/wasm/2026-07-11-multivalue-core-boundary-recheck.md`](raw/wasm/2026-07-11-multivalue-core-boundary-recheck.md)
- Feature-status routing: [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md)
- WAST authoring: [`wast/control-flow-authoring.md`](wast/control-flow-authoring.md), [`wast/function-call-and-module-authoring.md`](wast/function-call-and-module-authoring.md), [`wast/parametric-instruction-authoring.md`](wast/parametric-instruction-authoring.md)
- Core/binary/validation: [`src/lib/types.mbt`](../src/lib/types.mbt), [`src/binary/decode.mbt`](../src/binary/decode.mbt), [`src/binary/encode.mbt`](../src/binary/encode.mbt), [`src/validate/typecheck.mbt`](../src/validate/typecheck.mbt)
- Fuzzing: [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md), [`src/validate/gen_valid.mbt`](../src/validate/gen_valid.mbt), [`src/validate/invalid_fuzzer.mbt`](../src/validate/invalid_fuzzer.mbt)
