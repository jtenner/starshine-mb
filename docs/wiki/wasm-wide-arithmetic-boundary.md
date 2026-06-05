---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-wide-arithmetic-boundary-refresh.md
  - raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md
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

The current source bridge is [`raw/wasm/2026-06-05-wide-arithmetic-boundary-refresh.md`](raw/wasm/2026-06-05-wide-arithmetic-boundary-refresh.md). It checked the official proposals tracker, the Wide Arithmetic proposal repository/overview, the draft binary and validation pages, current Binaryen release-horizon notes, and current Starshine WAST/core/binary/validator/generator source evidence.

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

## Opcode And Source Caveat

The current proposal sources have a visible opcode-routing caveat. The proposal overview says existing `0xFC` subcodes `8` through `17` are occupied by bulk memory/table operations, `memory.discard` is expected at `18`, and Wide Arithmetic is expected at `19` through `22`. The draft rendered binary page checked in the same refresh still lists Wide Arithmetic in a `0xFC 13` through `0xFC 16` range, which collides with current Core table operations as implemented by Starshine's `0xFC` decoder.

Do not smooth over that contradiction. A future implementation slice should first recheck:

1. the proposal overview and rendered spec pages;
2. issue/PR history in the Wide Arithmetic repository;
3. the current official proposals tracker;
4. WABT, wasm-tools, and Binaryen behavior under explicit feature flags;
5. Starshine's existing `0xFC` table/bulk-memory decode cases.

Until then, this wiki treats the exact subopcode assignment as **unsettled proposal evidence** and records only that Starshine currently rejects/omits Wide Arithmetic.

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

1. **Status recheck:** refresh the proposal source bridge and resolve the subopcode contradiction before writing codec tests.
2. **Core model:** add explicit instruction variants and constructor helpers in [`src/lib/types.mbt`](../../src/lib/types.mbt).
3. **Binary:** add decode/encode cases for the final `0xFC` subcodes plus malformed/overwide/reserved-subopcode tests in [`src/binary/tests.mbt`](../../src/binary/tests.mbt).
4. **Validation:** add stack typing for four-input/two-output add/sub and two-input/two-output multiply in [`src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), including unreachable/bottom behavior through [`validate/stack-polymorphism-and-bottom.md`](validate/stack-polymorphism-and-bottom.md).
5. **WAST:** add keywords, parser classifications, lowerer mapping, printer output, and text roundtrip tests in `src/wast`.
6. **Generator/fuzzing:** add a feature gate, opcode counts, profile routing, and external-validator adapter classification before treating random inputs as ordinary valid modules.
7. **Pass contracts:** only after validation is green, decide which optimizers may fold, preserve, or lower Wide Arithmetic, with Binaryen oracle lanes kept separate from local support claims.

## Sources

- Source bridge: [`raw/wasm/2026-06-05-wide-arithmetic-boundary-refresh.md`](raw/wasm/2026-06-05-wide-arithmetic-boundary-refresh.md)
- Active proposal routing: [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md), [`wasm-feature-status-and-proposal-boundaries.md`](wasm-feature-status-and-proposal-boundaries.md)
- Numeric and binary companion pages: [`wast/numeric-instruction-authoring.md`](wast/numeric-instruction-authoring.md), [`binary/instruction-and-expression-encoding.md`](binary/instruction-and-expression-encoding.md)
- Local source evidence: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/wast/keywords.mbt`](../../src/wast/keywords.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/validate/typecheck.mbt`](../../src/validate/typecheck.mbt), [`../../src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt)
