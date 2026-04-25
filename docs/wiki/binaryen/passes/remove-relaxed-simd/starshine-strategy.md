---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
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
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ../precompute/index.md
  - ../strip-target-features/index.md
supersedes:
  - ../../../raw/research/0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
---

# Starshine strategy for `remove-relaxed-simd`

## Current status

Starshine does **not** currently implement Binaryen's `remove-relaxed-simd` pass.

The local status is stronger than ordinary “not ported”:

- `src/passes/optimize.mbt:126-151` contains no `remove-relaxed-simd` entry in boundary-only or removed pass names;
- the pass is therefore not `HotPass`, `ModulePass`, `Removed`, or `BoundaryOnly` in the current registry vocabulary;
- explicit requests hit the generic `unknown pass flag` path in `run_hot_pipeline_expand_passes(...)` (`src/passes/optimize.mbt:455-461`);
- no owner file, dispatch case, preset slot, parity page, or active backlog slice was found in this run.

So today's correct user-facing description is:

> Starshine can round-trip and typecheck relaxed SIMD instructions, and HOT can represent them as SIMD nodes, but Starshine has no pass that removes relaxed SIMD yet.

## Existing local relaxed-SIMD surfaces

### Registry and request behavior

- `src/passes/optimize.mbt:126-151`
  - source of truth for boundary-only and removed names;
  - no `remove-relaxed-simd` entry was found.
- `src/passes/optimize.mbt:455-461`
  - unknown requested names are rejected before pass expansion.

### WAT syntax and parsing

- `src/wast/types.mbt:720-740`
  - includes `Opcode` variants for the relaxed SIMD family.
- `src/wast/keywords.mbt:440-468`
  - maps text names such as `i8x16.relaxed_swizzle`, `f32x4.relaxed_madd`, and `i32x4.relaxed_dot_i8x16_i7x16_add_s` to opcode variants.
  - Caveat: Binaryen's lit/source spelling for the dot-product relaxed family omits `relaxed_`; Starshine currently uses `relaxed_dot` spellings.
- `src/wast/parser.mbt:3798-3806`
  - classifies relaxed lane-select and madd/nmadd forms as `SimdTernary(...)`.
- `src/wast/parser.mbt:3907-3919`
  - classifies the remaining relaxed-SIMD no-immediate family as `SimdRelaxed(...)`.
- `src/wast/lower_to_lib.mbt:2365-2367`
  - lowers `SimdTernary(...)` / `SimdRelaxed(...)` into `@lib.Instruction` values through the generic no-argument numeric path.

### Core instruction model and binary format

- `src/lib/types.mbt:1058-1076`
  - includes relaxed SIMD `Instruction` variants.
- `src/lib/types.mbt:5547-5628`
  - exposes relaxed SIMD instruction constructors.
- `src/binary/encode.mbt:3792-3814`
  - encodes relaxed SIMD prefixed opcodes `256` through `275`.
- `src/binary/decode.mbt:3783-3813`
  - decodes those same prefixed opcodes back into relaxed SIMD instructions.

### Validation and HOT IR

- `src/validate/typecheck.mbt:3710-3729`
  - typechecks each relaxed SIMD opcode using v128 unary/binary/ternary helpers.
- `src/validate/typecheck.mbt:9573-9790`
  - contains focused typechecking tests for the relaxed SIMD families.
- `src/ir/hot_lift.mbt:1178-1198`
  - classifies relaxed SIMD instructions as `HotOp::Simd`.
- `src/ir/hot_lower.mbt:1091`
  - lowers `HotOp::Simd` by emitting the exact stored instruction payload.

## How Starshine should map the corrected Binaryen strategy

The corrected Binaryen strategy is expression-local trap replacement plus child-effect preservation.
A future Starshine port should therefore start as function/HOT rewriting work, not as a feature metadata pass.

The minimum faithful local algorithm would:

1. add a registry decision for `remove-relaxed-simd`;
2. implement a relaxed-SIMD classifier over `@lib.Instruction` or HOT `Simd` payloads;
3. replace each matched node with an unreachable-typed block or equivalent local HOT shape;
4. preserve side-effecting children before the trap;
5. validate and lower back to the same binary/WAT surfaces;
6. separately decide whether Starshine should support Binaryen's dot-product WAT spelling aliases.

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
- A binary relaxed min/max, swizzle, Q15, or dot operation becomes a trap.
- A ternary relaxed madd, lane-select, or dot-add operation becomes a trap.
- Side-effecting child calls are still emitted before the trap.
- Ordinary SIMD instructions are unchanged.
- Every local relaxed SIMD `Instruction` constructor has coverage.
- Final module validation remains green.
- Binaryen dot-product spelling and Starshine's current `relaxed_dot` spelling are explicitly tested or documented.
- A Binaryen compare lane against `test/lit/passes/remove-relaxed-simd.wast` or reduced fixtures is added.

## Current uncertainty

- Feature metadata cleanup remains separate source-confirmation work. The 2026-04-25 recheck did not find a feature-section rewrite in the pass sources.
- HOT `Simd` payloads give Starshine a convenient landing zone, but no existing pass currently uses that surface to replace arbitrary SIMD expressions with trapping blocks.
- The pass is outside the current no-DWARF / saved-`-O4z` parity queue, so it should not displace higher-priority open parity blockers unless a user explicitly asks for relaxed-SIMD feature-removal work.

## Sources

- [`../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md)
- [`../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md)
- [`../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md`](../../../raw/research/0355-2026-04-25-remove-relaxed-simd-current-main-source-correction.md)
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
