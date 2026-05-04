---
kind: entity
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-remove-relaxed-simd-current-main-recheck.md
  - ../../../raw/research/0437-2026-05-04-remove-relaxed-simd-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
  - ../../../raw/research/0392-2026-04-26-remove-relaxed-simd-port-readiness.md
  - ../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../precompute/index.md
  - ../strip-target-features/index.md
  - ../late-pipeline-dispatch.md
supersedes:
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
---

# Binaryen pass: `remove-relaxed-simd`

## Purpose

`remove-relaxed-simd` is Binaryen's conservative escape hatch for modules that contain relaxed SIMD instructions but need output with no relaxed SIMD operation semantics.
Instead of choosing deterministic replacements for implementation-defined relaxed operations, Binaryen replaces each relaxed SIMD expression with a trap while preserving the effects of that expression's children.

The beginner version:

- relaxed SIMD operations can legally produce one of a bounded set of results depending on the implementation;
- Binaryen does not try to guess one result;
- the pass changes every matched relaxed SIMD operation into a block ending in `unreachable`;
- ordinary non-relaxed SIMD operations remain ordinary SIMD operations.

The advanced version:

- the reviewed `version_129` and current-`main` implementation is a `WalkerPass<PostWalker<RemoveRelaxedSIMD>>` over `Unary`, `Binary`, and `SIMDTernary` relaxed opcode families;
- replacement uses `ChildLocalizer`, so child effects are preserved before the new trap;
- `doWalkFunction(...)` postwalks each function and then calls `ReFinalize().walkFunctionInModule(...)`;
- the earlier dossier wording about a per-function relaxed-SIMD feature gate and changed-flag-gated refinalization was source-overread and is superseded by the 2026-04-25 correction.

## Inputs and outputs

### Input shape

The input module may contain any of the relaxed SIMD opcodes from the proposal family, including:

- relaxed swizzle;
- relaxed truncation to integer lanes;
- relaxed fused multiply-add / negative multiply-add;
- relaxed lane-select operations;
- relaxed min/max;
- relaxed Q15 multiply-rounding and dot-product operations.

The input may mix those operations with ordinary deterministic SIMD, scalar code, calls, memory operations, and control flow.

### Output shape

The output module has the same surrounding control/function structure, but each relaxed SIMD expression is replaced by a block ending in `unreachable`.
When the relaxed expression had children with effects, those effects are kept before the trap.
Ordinary SIMD expressions are not rewritten by this pass.

## Correctness constraints

- **No deterministic-value invention:** do not replace relaxed SIMD with one arbitrary non-relaxed SIMD equivalent. Binaryen's source-backed contract is trap replacement.
- **Effect preservation:** child expressions must still run if they would have run before the relaxed operation.
- **Type preservation:** the replacement must typecheck in the original expression context; Binaryen handles this with an unreachable block plus refinalization.
- **No feature-gate overread:** the reviewed owner file does not show a per-function relaxed-SIMD feature check; if no relaxed operation is present, the visitor simply has no matching rewrite.
- **Non-relaxed boundary:** normal SIMD instructions such as `i8x16.swizzle`, `v128.bitselect`, ordinary min/max, and ordinary truncation are outside this pass.
- **Feature metadata separation:** this dossier does not claim Binaryen clears the target-features custom section; no such step was found in the reviewed pass sources.

## Notable edge cases

- Relaxed expressions whose operands include calls, stores, or other side-effecting children.
- Relaxed ternary expressions, where all relevant children must be preserved before the trap.
- Relaxed expressions in typed result positions, where the replacement block must still satisfy the surrounding `v128` context.
- Modules that contain only deterministic SIMD: body semantics should be unchanged by this pass, even though Binaryen's reviewed owner file still walks/refinalizes functions.
- Binaryen/source WAT names for the dot-product relaxed family currently omit the textual `relaxed_` prefix, while Starshine's WAT keyword table uses `i16x8.relaxed_dot_i8x16_i7x16_s` and `i32x4.relaxed_dot_i8x16_i7x16_add_s`.

## Validation strategy

For Binaryen parity research, start with the official lit file:

- `test/lit/passes/remove-relaxed-simd.wast`

For a future Starshine port, add tests in this order:

1. one unary relaxed opcode becomes `unreachable`;
2. one binary relaxed opcode becomes `unreachable`;
3. one ternary relaxed opcode becomes `unreachable`;
4. child calls or stores are preserved before the trap;
5. ordinary SIMD neighbors remain unchanged;
6. every relaxed opcode in Starshine's `Instruction` enum is covered;
7. final module validation still succeeds after the rewrite;
8. Binaryen dot-product spelling versus Starshine's current `relaxed_dot` spelling is handled or documented;
9. feature metadata cleanup, if ever source-confirmed, is tested separately from expression rewriting.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - source-backed Binaryen strategy and the corrected no-feature-gate wording.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and official test surface.
- [`wat-shapes.md`](wat-shapes.md) - before/after shape catalog.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.
- [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) - safe future implementation order, validation ladder, and local code-surface map.

## Sources

- [`../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-remove-relaxed-simd-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md)
- [`../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md)
- [`../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md`](../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md)
- [`../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md`](../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md)
- Binaryen `RemoveRelaxedSIMD.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveRelaxedSIMD.cpp>
- Binaryen lit file: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-relaxed-simd.wast>
- WebAssembly relaxed SIMD proposal overview: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>
