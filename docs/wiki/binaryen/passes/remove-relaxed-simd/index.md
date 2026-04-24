---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/ir/hot_lift.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../precompute/index.md
  - ../instrument-memory/index.md
  - ../late-pipeline-dispatch.md
---

# Binaryen pass: `remove-relaxed-simd`

## Purpose

`remove-relaxed-simd` is Binaryen's conservative escape hatch for modules that contain relaxed SIMD instructions but need output with no relaxed SIMD behavior.
Instead of choosing deterministic replacements for implementation-defined relaxed operations, Binaryen replaces each relaxed SIMD expression with a trap while preserving the effects of that expression's children.

The beginner version:

- relaxed SIMD operations can legally produce one of a bounded set of results depending on the implementation;
- Binaryen does not try to guess one result;
- the pass changes every relaxed SIMD operation into `unreachable`;
- ordinary non-relaxed SIMD operations remain ordinary SIMD operations.

The advanced version:

- the pass is a function-parallel AST rewrite over `Unary`, `Binary`, and `SIMDTernary` relaxed opcode families;
- replacement uses `ChildLocalizer`, so child effects are preserved before the new trap;
- functions are refinalized after changes;
- the pass skips work when the module feature set does not include relaxed SIMD.

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
- **Feature gate:** when the module lacks relaxed SIMD, there is nothing for this pass to do.
- **Non-relaxed boundary:** normal SIMD instructions such as `i8x16.swizzle`, `v128.bitselect`, ordinary min/max, and ordinary truncation are outside this pass.

## Notable edge cases

- Relaxed expressions whose operands include calls, stores, or other side-effecting children.
- Relaxed ternary expressions, where all relevant children must be preserved before the trap.
- Relaxed expressions in typed result positions, where the replacement block must still satisfy the surrounding `v128` context.
- Modules that contain only deterministic SIMD: the pass should be a no-op.
- Feature metadata cleanup is **not** asserted by this dossier; the reviewed sources prove opcode replacement and refinalization, not a local feature-section rewrite contract.

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
8. if source-confirmed, feature metadata cleanup is tested separately from expression rewriting.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - source-backed Binaryen strategy.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and official test surface.
- [`wat-shapes.md`](wat-shapes.md) - before/after shape catalog.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.

## Sources

- [`../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md)
- [`../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md`](../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md)
- Binaryen `RemoveRelaxedSIMD.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveRelaxedSIMD.cpp>
- Binaryen lit file: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-relaxed-simd.wast>
- WebAssembly relaxed SIMD proposal overview: <https://github.com/WebAssembly/relaxed-simd/blob/main/proposals/relaxed-simd/Overview.md>
