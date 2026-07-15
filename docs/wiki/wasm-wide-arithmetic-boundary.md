---
kind: concept
status: supported
last_reviewed: 2026-07-10
sources:
  - https://github.com/WebAssembly/wide-arithmetic/blob/main/proposals/wide-arithmetic/Overview.md
  - https://github.com/WebAssembly/proposals
  - ../../src/lib/types.mbt
  - ../../src/wast/keywords.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/typecheck.mbt
  - ../../src/validate/gen_valid.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wast/numeric-instruction-authoring.md
  - binary/instruction-and-expression-encoding.md
  - validate/module-validation-phases.md
  - tooling/external-validator-adapters.md
  - binaryen/release-horizon-and-oracles.md
---

# Wide Arithmetic Boundary

## Overview

Use this page when a fixture, external tool result, Binaryen comparison, or optimizer note mentions **Wide Arithmetic**. Wide Arithmetic is an active WebAssembly proposal for scalar integer instructions that compute or manipulate 128-bit results using pairs of `i64` stack values. It is not part of current Starshine's ordinary scalar numeric surface.

For beginners: ordinary `i64.add` consumes two `i64` values and pushes one wrapped `i64` result. Wide Arithmetic adds instructions whose result is too wide for one `i64`, so the proposal represents the result as **two `i64` values** on the wasm stack. That makes it a scalar-numeric proposal, but it also touches multi-value validation, binary prefixed-opcode assignment, WAST printing/parsing, and pass rewrite safety.

The [proposal tracker](https://github.com/WebAssembly/proposals), maintained [Wide Arithmetic overview](https://github.com/WebAssembly/wide-arithmetic/blob/main/proposals/wide-arithmetic/Overview.md), rendered [binary draft](https://webassembly.github.io/wide-arithmetic/core/binary/instructions.html), rendered [validation draft](https://webassembly.github.io/wide-arithmetic/core/valid/instructions.html), and Starshine's current `0xFC` codec establish this boundary. The overview supplies the operational placement below; the older rendered binary table remains inconsistent.

## Proposal Shape

The proposal-level instruction family is:

| Instruction | Proposal stack shape | Meaning |
| --- | --- | --- |
| `i64.add128` | `low1:i64 high1:i64 low2:i64 high2:i64 -> low:i64 high:i64` | Add two 128-bit integer pairs and return the low/high words. |
| `i64.sub128` | `low1:i64 high1:i64 low2:i64 high2:i64 -> low:i64 high:i64` | Subtract one 128-bit integer pair from another. |
| `i64.mul_wide_s` | `lhs:i64 rhs:i64 -> low:i64 high:i64` | Signed `i64 * i64`, returning the full 128-bit product pair. |
| `i64.mul_wide_u` | `lhs:i64 rhs:i64 -> low:i64 high:i64` | Unsigned `i64 * i64`, returning the full 128-bit product pair. |

The important differences from current Starshine scalar numeric instructions are:

- **two results:** every Wide Arithmetic instruction pushes two `i64` values;
- **word-pair ordering:** future text, binary, validator, and printer tests must agree on low/high order;
- **signedness:** `mul_wide_s` and `mul_wide_u` are distinct operations, not aliases;
- **no ordinary overflow trap:** these are arithmetic operations that expose the high word rather than trapping on overflow;
- **proposal status:** a tool accepting the syntax or bytes is not enough to prove Starshine support.

## Current Starshine Status

Starshine currently has **no documented Wide Arithmetic support**.

| Layer | Current local evidence | Status |
| --- | --- | --- |
| WAST text | [`src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt) | No `i64.add128`, `i64.sub128`, `i64.mul_wide_s`, or `i64.mul_wide_u` keyword/parser/lowerer cases. |
| Core instruction model | [`src/lib/types.mbt`](../../src/lib/types.mbt) | Ordinary `I64Add`, `I64Sub`, `I64Mul`, `I64Div*`, and `I64Rem*` exist; no wide-arithmetic instruction variants. |
| Binary codec | [`src/binary/decode.mbt`](../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../src/binary/encode.mbt) | `0xFC` decode/encode currently covers saturating truncation plus bulk memory/table subcodes `0..17`; no Wide Arithmetic subcodes are accepted or emitted. |
| Validation | [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt) | Ordinary `i64` binary ops consume two `i64`s and produce one `i64`; no multi-result wide-arithmetic typecheck cases. |
| Generator/fuzzing | [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt) | No Wide Arithmetic feature gate, opcode-count row, or valid-generator production row is documented. |
| Optimizer passes | `src/passes/*` plus Binaryen pass dossiers | No local pass contract may create or rewrite Wide Arithmetic until the core/binary/validator layer exists. |

This means current Wide Arithmetic inputs should be classified as `unsupported-feature` or active-proposal evidence in external-validator/fuzz reports, not as ordinary scalar numeric parser bugs.

## Opcode Routing: Current Operational Rule And Draft Lag

The proposal is still active, so its encoding is not a final Core compatibility promise. However, the current sources no longer leave a Starshine implementation free to choose either apparent range:

| `0xFC` subcodes | Current meaning | Starshine handling today |
| --- | --- | --- |
| `13..17` | Current Core table operations: `elem.drop`, `table.copy`, `table.grow`, `table.size`, `table.fill` | Decoded and encoded as those table instructions. They are **not** Wide Arithmetic bytes. |
| `18` | Expected Memory Control `memory.discard` slot in the Wide Arithmetic overview | Unsupported; keep separate from Wide Arithmetic. |
| `19..22` | Current Wide Arithmetic overview placement: `i64.add128`, `i64.sub128`, `i64.mul_wide_s`, `i64.mul_wide_u` | Unsupported; these are the only bytes a future proposal-gated Wide Arithmetic slice should target. |

The maintained proposal overview explicitly rejects `13..16` because those values collide with table instructions and places Wide Arithmetic at `19..22`. The rendered proposal binary page still shows `13..16` and identifies itself as a 2025-09-21 draft. Record that page as an unreconciled/stale artifact, not an alternate legal encoding. A compatibility decoder for its values would reinterpret valid Core table instructions and is therefore forbidden.

Before implementation, recheck the overview, rendered drafts, tracker, and exact tool versions/feature flags. The task is to detect whether the rendered draft caught up—not to reopen `13..16` as a possible implementation choice.

## Examples And Non-Examples

### Proposal-style multiply

```wat
(func (param $x i64) (param $y i64) (result i64 i64)
  (i64.mul_wide_u
    (local.get $x)
    (local.get $y)))
```

This is useful proposal documentation, but it is not a current Starshine WAST fixture. Today Starshine has no keyword, core instruction, validator, or binary encoding for `i64.mul_wide_u`.

### Not equivalent to ordinary `i64.mul`

```wat
(func (param $x i64) (param $y i64) (result i64)
  (i64.mul
    (local.get $x)
    (local.get $y)))
```

This current Core/Starshine instruction returns only the low wrapped `i64` result. It cannot replace `i64.mul_wide_u` or `i64.mul_wide_s` when the high word is observable.

### Not a SIMD instruction

Wide Arithmetic uses scalar `i64` stack values and multi-value results. It is unrelated to `i64x2.*` SIMD lanes in [`wast/simd-authoring.md`](wast/simd-authoring.md). Do not use SIMD parser, binary, or relaxed-SIMD generator evidence to claim Wide Arithmetic support.

## Implementation Checklist For A Future Slice

A safe Starshine implementation would need all of these, in order:

1. **Status recheck:** refresh the proposal source bridge and record whether the rendered draft has caught up; use the maintained overview's `0xFC 19..22` placement unless the upstream project changes it.
2. **Core model:** add explicit instruction variants and constructor helpers in [`src/lib/types.mbt`](../../src/lib/types.mbt).
3. **Binary:** add proposal-gated decode/encode cases for `0xFC 19..22`, malformed/overwide/reserved-subopcode tests, and explicit non-reinterpretation tests proving `13..17` remain Core table instructions in [`src/binary/tests.mbt`](../../src/binary/tests.mbt).
4. **Validation:** add stack typing for four-input/two-output add/sub and two-input/two-output multiply in [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), including unreachable/bottom behavior through [`validate/stack-polymorphism-and-bottom.md`](validate/stack-polymorphism-and-bottom.md).
5. **WAST:** add keywords, parser classifications, lowerer mapping, printer output, and text roundtrip tests in `src/wast`.
6. **Generator/fuzzing:** add a feature gate, opcode counts, profile routing, and external-validator adapter classification before treating random inputs as ordinary valid modules.
7. **Pass contracts:** only after validation is green, decide which optimizers may fold, preserve, or lower Wide Arithmetic, with Binaryen oracle lanes kept separate from local support claims.

## Sources

- Proposal status and opcode sources: [tracker](https://github.com/WebAssembly/proposals), [overview](https://github.com/WebAssembly/wide-arithmetic/blob/main/proposals/wide-arithmetic/Overview.md), [rendered binary draft](https://webassembly.github.io/wide-arithmetic/core/binary/instructions.html), and [rendered validation draft](https://webassembly.github.io/wide-arithmetic/core/valid/instructions.html)
- Shared status routing: [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md)
- Numeric and binary companion pages: [`wast/numeric-instruction-authoring.md`](wast/numeric-instruction-authoring.md), [`binary/instruction-and-expression-encoding.md`](binary/instruction-and-expression-encoding.md)
- Local source evidence: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt)
