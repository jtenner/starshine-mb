---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
  - ../../../raw/research/0392-2026-04-26-remove-relaxed-simd-port-readiness.md
  - ../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
supersedes:
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
---

# Binaryen strategy for `remove-relaxed-simd`

## What Binaryen is optimizing away

Relaxed SIMD is intentionally not fully deterministic across all implementations.
The WebAssembly relaxed SIMD proposal describes operations whose result is chosen from a bounded set, leaving implementation-defined latitude.
That is useful for performance portability, but it is awkward for consumers that want no relaxed SIMD operations in the output.

Binaryen's answer is deliberately conservative: replace relaxed SIMD instructions with traps.
This avoids pretending that one deterministic SIMD sequence is a faithful substitute for every implementation-defined choice.

## Registration and public identity

`version_129` registers a public pass named `remove-relaxed-simd` in `src/passes/pass.cpp`.
The same tag declares `createRemoveRelaxedSIMDPass()` in `src/passes/passes.h` and implements the pass in `src/passes/RemoveRelaxedSIMD.cpp`.
The tagged changelog records the pass as a `version_126` addition.

Current `main`, rechecked again on 2026-04-26 for port readiness, keeps the same public pass spelling, constructor, owner file, trap-replacement strategy, refinalization shape, and dedicated lit filename. The fresh recheck is captured in [`../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md).

## Core rewrite algorithm

The implementation is small and direct:

1. Walk functions with a postwalker.
2. Visit relaxed SIMD expressions in the AST.
3. Replace each matched expression with a block that evaluates/localizes child effects and then executes `unreachable`.
4. Refinalize the walked function.

The important helper is `ChildLocalizer`.
Without it, replacing a relaxed expression by `unreachable` could erase the evaluation of side-effecting operands.
With it, Binaryen can trap at the relaxed operation site while still keeping operand effects that the original expression would have evaluated.

## Corrected feature-gate note

The 2026-04-24 dossier said the pass skipped functions whose module feature set did not include relaxed SIMD and refinalized only changed functions.
The 2026-04-25 source recheck corrects that:

- reviewed `RemoveRelaxedSIMD.cpp` calls `PostWalker::doWalkFunction(func)`;
- reviewed `RemoveRelaxedSIMD.cpp` then calls `ReFinalize().walkFunctionInModule(func, getModule())`;
- no `FeatureSet::RelaxedSIMD` guard, `hasRelaxedSIMD()` check, or pass-local `changed` field was found in the reviewed owner file.

So the practical no-op story is not “feature gate skips the function.” It is “the visitor has no relaxed SIMD expression to rewrite.”

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
- dot-product family caveat: Binaryen source/lit names omit the textual `relaxed_` prefix for `i16x8.dot_i8x16_i7x16_s`, while Starshine currently spells the WAT keyword `i16x8.relaxed_dot_i8x16_i7x16_s`.

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
- dot-product add caveat: Binaryen source/lit names omit the textual `relaxed_` prefix for `i32x4.dot_i8x16_i7x16_add_s`, while Starshine currently spells the WAT keyword `i32x4.relaxed_dot_i8x16_i7x16_add_s`.

## Non-goals

`remove-relaxed-simd` is not:

- a SIMD optimizer;
- a relaxed-to-deterministic lowering pass;
- a vector canonicalizer;
- a pass that rewrites ordinary SIMD;
- a profitability-based transform;
- a proven target-feature custom-section stripping pass.

Ordinary deterministic SIMD instructions are intentionally preserved.
The official lit file includes non-relaxed SIMD neighbors to prove that boundary.

## Why refinalization matters

A relaxed SIMD expression usually has result type `v128`.
`unreachable` can satisfy many typed contexts, but the surrounding AST still needs coherent expression types after replacement and child localization.
Binaryen therefore refinalizes after walking each function in the reviewed owner file.

## Current-main check

The current-`main` files reviewed on 2026-04-25 still present the same core teaching-level contract as `version_129`:

- same owner file name;
- same public pass spelling;
- same dedicated lit filename;
- same trap-replacement strategy;
- same absence of a feature-section cleanup step in the reviewed pass sources;
- same no-feature-gate / unconditional postwalk refinalization shape.

Treat this as a narrow no-drift check, not a proof that every implementation detail will remain unchanged forever.

## Uncertainty

The reviewed source proves expression replacement, child-effect preservation, and refinalization.
This dossier does not claim that Binaryen clears module feature metadata after removing relaxed SIMD opcodes.
Before porting, source-confirm whether Starshine should add a separate metadata cleanup step or only rewrite instructions.

## Sources

- [`../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md)
- [`../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md)
- [`../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md`](../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md)
- [`../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md`](../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md)
- Binaryen `RemoveRelaxedSIMD.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveRelaxedSIMD.cpp>
- Binaryen `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- WebAssembly relaxed SIMD overview: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>
