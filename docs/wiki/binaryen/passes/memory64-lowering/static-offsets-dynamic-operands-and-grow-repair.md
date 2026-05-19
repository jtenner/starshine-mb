---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md
  - ../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md
  - ../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md
  - ../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md
  - ../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../wast/memory-argument-authoring.md
---

# `memory64-lowering` static offsets, dynamic operands, and grow repair

This page is the corrected guide to the easiest part of `memory64-lowering` / `table64-lowering` to overgeneralize: which “large constants” are known traps, which ones are just expression operands that get wrapped, and why grow repair is about the lowered grow result.

Read this with the raw primary-source correction in [`../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md). Future Starshine implementation checkpoints for these shapes are now maintained in [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md). For WAST fixture authoring, pair this page with [`../../../wast/memory-argument-authoring.md`](../../../wast/memory-argument-authoring.md) so text-byte `align=`, static `offset=`, dynamic stack addresses, and the current WAST nonzero-memory-index gap stay explicit.

## The corrected distinction

Do not teach a single rule named “high constants become unreachable.”
Binaryen has at least four different surfaces here:

| Surface | Correct current rule |
| --- | --- |
| Dynamic address / index / count expression | lower with `i32.wrap_i64(...)` |
| `i64.const` used as that expression | still an expression; lower through the wrap path |
| Static `MemArg.offset` immediate on memory access | if it is at or above `2^32`, replace the operation with `unreachable` after preserving child effects |
| Active data / element segment offset expression | lower the expression to 32-bit address type; no reviewed high-offset-to-`unreachable` special case |
| `memory.grow` / `table.grow` delta | wrap the delta for the lowered operation, then repair the lowered `i32` result |

That distinction replaces the folder's earlier over-broad wording about “known constant address operands” and high active offsets.

## Why dynamic operands wrap, even when syntactically constant

A memory64 load has two address-like pieces:

- the static `offset=` immediate in the `MemArg`;
- the stack address expression.

For the stack expression, Binaryen's owner source uses expression-width repair. If a former memory64 address expression is `i64`, the lowered memory32 instruction receives an `i32.wrap_i64(...)` expression.

So this source-level shape:

```wat
(i32.load (i64.const 4294967296))
```

is an operand-expression case, not the static-offset case. The corrected teaching rule is:

```wat
(i32.load (i32.wrap_i64 (i64.const 4294967296)))
```

A later cleanup pass may simplify that expression, but `memory64-lowering` itself should not be described as preclassifying every high `i64.const` operand as `unreachable`.

## Static `MemArg.offset` is the trap-preserving high-offset family

The official memory lit file's high-offset cases are about the immediate offset on the memory instruction, for example schematically:

```wat
(i32.load offset=4294967296 (local.get $p))
```

For a lowered i32-address memory, that static offset is already outside the representable 32-bit address space. Binaryen preserves the guaranteed bad access by replacing the operation with an `unreachable` shape while keeping child effects.

That means a future Starshine test suite needs both families:

1. dynamic operand high constant wraps;
2. static memarg high offset becomes `unreachable`.

If those are collapsed into one test, the port can pass the easy case while still getting Binaryen parity wrong.

## Active segment offsets are not memargs

Active data and element offsets are also expressions, not `MemArg.offset` immediates. The same segment-versus-function-body distinction is summarized for WAST authors in [`../../../wast/memory-argument-authoring.md`](../../../wast/memory-argument-authoring.md).
The pass must rewrite them because memory/table declarations have been lowered to 32-bit limits, but the reviewed source check did not find a high-active-offset special case comparable to static memarg offsets.

Correct current teaching: an active offset such as `(i64.const 16)` must be rewritten to a 32-bit offset expression form after declaration lowering. The exact printed form can depend on Binaryen expression printing and later simplification; the important correction is negative: do not claim current Binaryen turns high active offsets into `unreachable` unless a newer source or oracle run proves that drift.

## Grow repair is about the result sentinel

`memory.grow` and `table.grow` are special because they return the old size or a failure sentinel.
After lowering, the actual grow returns an `i32` result. A wasm64 caller expects an `i64` result.

A faithful lowering therefore needs:

1. wrap the former `i64` delta into the lowered grow;
2. store the lowered `i32` result once;
3. if it equals `i32 -1`, return `i64 -1`;
4. otherwise return `i64.extend_i32_u(result)`.

That is different from both:

- a blind `i64.extend_i32_u(memory.grow(...))`, which mishandles failure;
- a separate “high constant delta becomes failure before calling grow” rule, which this source check did not find.

## Starshine implementation impact

The current local code already has the key representational split a future port must use:

- `src/lib/types.mbt:162-164` distinguishes `Limits::I32Limits` from `Limits::I64Limits`.
- `src/lib/types.mbt:1263-1267` maps those limits to the stack address value type.
- `src/validate/typecheck.mbt:1538-1577` validates static `MemArg.offset` separately from stack operand typing.
- `src/validate/typecheck.mbt:2408-2426` derives `memory.size` / `memory.grow` operand and result types from memory limits.
- `src/validate/typecheck.mbt:2468-2488` already models `memory.copy` positions independently.
- `src/validate/typecheck.mbt:587-635` still hard-codes `table.get`, `table.set`, `table.size`, and `table.grow` to `i32`, so table64 validation cleanup remains a prerequisite.
- `src/binary/encode.mbt:1208-1284` encodes the existing limit forms; a lowering pass must rewrite declarations before encoding.

## Minimum reduced tests for this corrected slice

A future Starshine port should add at least these tests before calling the out-of-range behavior covered:

1. dynamic load address `i64.const 4294967296` lowers through `i32.wrap_i64`, not `unreachable`;
2. static scalar-load `offset=4294967296` lowers to an `unreachable` shape with address child effects preserved;
3. static SIMD or atomic high offset follows the same `unreachable` family;
4. active data offset expression lowers to a 32-bit expression without assuming the static-memarg trap rule;
5. dynamic `memory.grow` delta wraps and the result gets failure-sentinel repair;
6. `memory.size` remains the simpler unsigned result-extension case;
7. the same distinctions are repeated for table64 once table operation typechecking is coherent.

## Sources

- [`../../../raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md)
- [`../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md`](../../../raw/research/0411-2026-04-26-memory64-lowering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md`](../../../raw/research/0374-2026-04-25-memory64-lowering-static-offset-correction.md)
- [`../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md)
- [`../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md`](../../../raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md)
- [`../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-24-memory64-lowering-primary-sources.md)
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Memory64Lowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory64-lowering.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/table64-lowering.wast>
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
