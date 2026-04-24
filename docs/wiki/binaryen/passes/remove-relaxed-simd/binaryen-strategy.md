---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Binaryen strategy for `remove-relaxed-simd`

## What Binaryen is optimizing away

Relaxed SIMD is intentionally not fully deterministic across all implementations.
The WebAssembly relaxed SIMD proposal describes operations whose result is chosen from a bounded set, leaving implementation-defined latitude.
That is useful for performance portability, but it is awkward for consumers that want no relaxed SIMD behavior in the output.

Binaryen's answer is deliberately conservative: replace relaxed SIMD instructions with traps.
This avoids pretending that one deterministic SIMD sequence is a faithful substitute for every implementation-defined choice.

## Registration and public identity

`version_129` registers a public pass named `remove-relaxed-simd` in `src/passes/pass.cpp`.
The same tag declares `createRemoveRelaxedSIMDPass()` in `src/passes/passes.h` and implements the pass in `src/passes/RemoveRelaxedSIMD.cpp`.
The tagged changelog records the pass as a `version_126` addition.

## Core rewrite algorithm

The implementation is small and direct:

1. Walk functions in parallel.
2. Skip each function if the module feature set does not include relaxed SIMD.
3. Visit relaxed SIMD expressions in the AST.
4. Replace each matched expression with a block that evaluates/localizes child effects and then executes `unreachable`.
5. Mark the function as changed.
6. Refinalize changed functions.

The important helper is `ChildLocalizer`.
Without it, replacing a relaxed expression by `unreachable` could erase the evaluation of side-effecting operands.
With it, Binaryen can trap at the relaxed operation site while still keeping operand effects that the original expression would have evaluated.

## Covered instruction families

Binaryen covers the relaxed SIMD op families through visitors by expression arity.

### Unary relaxed operations

The reviewed source handles the relaxed truncation family:

- `i32x4.relaxed_trunc_f32x4_s`
- `i32x4.relaxed_trunc_f32x4_u`
- `i32x4.relaxed_trunc_f64x2_s_zero`
- `i32x4.relaxed_trunc_f64x2_u_zero`

### Binary relaxed operations

The reviewed source handles relaxed binary-style operations including:

- `i8x16.relaxed_swizzle`
- `f32x4.relaxed_min`
- `f32x4.relaxed_max`
- `f64x2.relaxed_min`
- `f64x2.relaxed_max`
- `i16x8.relaxed_q15mulr_s`
- `i16x8.relaxed_dot_i8x16_i7x16_s`

### Ternary relaxed operations

The reviewed source handles relaxed ternary-style operations including:

- `f32x4.relaxed_madd`
- `f32x4.relaxed_nmadd`
- `f64x2.relaxed_madd`
- `f64x2.relaxed_nmadd`
- `i8x16.relaxed_laneselect`
- `i16x8.relaxed_laneselect`
- `i32x4.relaxed_laneselect`
- `i64x2.relaxed_laneselect`
- `i32x4.relaxed_dot_i8x16_i7x16_add_s`

## Non-goals

`remove-relaxed-simd` is not:

- a SIMD optimizer;
- a relaxed-to-deterministic lowering pass;
- a vector canonicalizer;
- a pass that rewrites ordinary SIMD;
- a profitability-based transform.

Ordinary deterministic SIMD instructions are intentionally preserved.
The official lit file includes non-relaxed SIMD neighbors to prove that boundary.

## Why refinalization matters

A relaxed SIMD expression usually has result type `v128`.
`unreachable` can satisfy many typed contexts, but the surrounding AST still needs coherent expression types after replacement and child localization.
Binaryen therefore refinalizes changed functions as part of the pass contract.

## Current-main check

The current-`main` files reviewed on 2026-04-24 still present the same teaching-level contract as `version_129`:

- same owner file name;
- same public pass spelling;
- same dedicated lit filename;
- same trap-replacement strategy.

Treat this as a narrow no-drift check, not a proof that every implementation detail will remain unchanged forever.

## Uncertainty

The reviewed source proves expression replacement and refinalization.
This dossier does not claim that Binaryen clears module feature metadata after removing relaxed SIMD opcodes.
Before porting, source-confirm whether a Starshine implementation must also adjust feature declarations or only rewrite the instructions.

## Sources

- [`../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md)
- [`../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md`](../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md)
- Binaryen `RemoveRelaxedSIMD.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveRelaxedSIMD.cpp>
- Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- WebAssembly relaxed SIMD overview: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>
