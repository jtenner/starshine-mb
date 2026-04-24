---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
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
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../precompute/index.md
---

# Starshine strategy for `remove-relaxed-simd`

## Current status

Starshine does **not** currently implement Binaryen's `remove-relaxed-simd` pass.

The local status is stronger than ordinary “not ported”:

- `src/passes/optimize.mbt` contains no registry entry for `remove-relaxed-simd`;
- the pass is therefore not `HotPass`, `ModulePass`, `Removed`, or `BoundaryOnly` in the current registry vocabulary;
- explicit requests hit the generic `unknown pass flag` path today;
- no owner file, dispatch case, preset slot, parity page, or active backlog slice was found in this run.

So today's correct user-facing description is:

> Starshine can round-trip and typecheck relaxed SIMD instructions, and HOT can represent them as SIMD nodes, but Starshine has no pass that removes relaxed SIMD yet.

## Existing local relaxed-SIMD surfaces

### Registry and request behavior

- `src/passes/optimize.mbt`
  - source of truth for registered pass names;
  - no `remove-relaxed-simd` entry was found;
  - unknown requested names are rejected before pass expansion.

### WAT syntax and parsing

- `src/wast/types.mbt`
  - includes `Opcode` variants for the relaxed SIMD family.
- `src/wast/keywords.mbt`
  - maps text names such as `i8x16.relaxed_swizzle`, `f32x4.relaxed_madd`, and `i32x4.relaxed_dot_i8x16_i7x16_add_s` to opcode variants.
- `src/wast/parser.mbt`
  - classifies relaxed unary/binary-style opcodes as `SimdRelaxed(...)`;
  - classifies relaxed lane-select and madd/nmadd forms as `SimdTernary(...)`.
- `src/wast/lower_to_lib.mbt`
  - has a focused test that lowers the relaxed SIMD no-immediate family into `@lib.Instruction` values.

### Core instruction model and binary format

- `src/lib/types.mbt`
  - includes relaxed SIMD `Instruction` variants and constructors.
- `src/binary/encode.mbt`
  - encodes relaxed SIMD prefixed opcodes `256` through `275`.
- `src/binary/decode.mbt`
  - decodes those same prefixed opcodes back into relaxed SIMD instructions.

### Validation and HOT IR

- `src/validate/typecheck.mbt`
  - contains focused typechecking tests for relaxed SIMD opcodes.
- `src/ir/hot_lift.mbt`
  - classifies relaxed SIMD instructions as `HotOp::Simd`.
- `src/ir/hot_lower.mbt`
  - lowers `HotOp::Simd` by emitting the exact stored instruction payload.

## Future implementation shape

The pass could plausibly be a HOT pass for function-body rewriting, because Starshine's HOT IR already groups relaxed SIMD instructions under `HotOp::Simd` and lowers them exactly.
However, two questions must be answered before locking that in:

1. **Feature metadata:** if Binaryen clears or expects cleanup of relaxed-SIMD feature metadata, Starshine may need module-level work too.
2. **Child effect preservation:** HOT rewrite helpers must preserve child evaluation order before emitting the replacement trap.

A practical first port would likely:

1. add a registry decision for `remove-relaxed-simd`;
2. implement a relaxed-SIMD classifier over `@lib.Instruction` or HOT `Simd` payloads;
3. replace each matched node with an unreachable-typed block or equivalent local HOT shape;
4. preserve side-effecting children before the trap;
5. validate and lower back to the same binary/WAT surfaces;
6. only then decide whether feature metadata cleanup is necessary.

## Why not make deterministic substitutions?

Binaryen does not choose deterministic equivalents.
Starshine should not either unless a future source changes the contract.

Examples of tempting but wrong shortcuts:

- replacing relaxed min/max with ordinary min/max;
- replacing relaxed lane-select with `v128.bitselect`;
- expanding relaxed dot products into a fixed arithmetic sequence;
- folding relaxed operations during precompute.

Those rewrites could accidentally choose one implementation-defined behavior and make it look portable.
The Binaryen-compatible behavior is to trap at the relaxed operation site.

## Candidate tests for a Starshine port

- `--pass remove-relaxed-simd` is accepted only once the pass exists.
- A unary relaxed truncation becomes a trap.
- A binary relaxed min/max or dot operation becomes a trap.
- A ternary relaxed madd or lane-select operation becomes a trap.
- Side-effecting child calls are still emitted before the trap.
- Ordinary SIMD instructions are unchanged.
- Every local relaxed SIMD `Instruction` constructor has coverage.
- Final module validation remains green.
- A Binaryen compare lane against `test/lit/passes/remove-relaxed-simd.wast` or reduced fixtures is added.

## Current uncertainty

- Feature metadata cleanup remains source-confirmation work.
- HOT `Simd` payloads give Starshine a convenient landing zone, but no existing pass currently uses that surface to replace arbitrary SIMD expressions with trapping blocks.
- The pass is outside the current no-DWARF / saved-`-O4z` parity queue, so it should not displace higher-priority open parity blockers unless a user explicitly asks for relaxed-SIMD feature-removal work.

## Sources

- [`../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md)
- [`../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md`](../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/wast/types.mbt`](../../../../../src/wast/types.mbt)
- [`../../../../../src/wast/keywords.mbt`](../../../../../src/wast/keywords.mbt)
- [`../../../../../src/wast/parser.mbt`](../../../../../src/wast/parser.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- [`../../../../../src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt)
- [`../../../../../src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt)
