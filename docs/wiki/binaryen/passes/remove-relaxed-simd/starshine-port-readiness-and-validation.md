---
kind: strategy
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
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/wast/types.mbt
  - ../../../../../src/wast/keywords.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/lib/show.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../precompute/index.md
  - ../strip-target-features/index.md
---

# Starshine port readiness and validation for `remove-relaxed-simd`

This page bridges the source-backed Binaryen strategy to a future Starshine implementation plan. It does **not** claim the pass is implemented today. Starshine currently round-trips and validates relaxed SIMD instructions, but `remove-relaxed-simd` is still an unknown pass name in the local registry.

## Current local truth

As of the 2026-04-26 recheck:

- [`src/passes/optimize.mbt:126-151`](../../../../../src/passes/optimize.mbt) lists boundary-only and removed pass names; `remove-relaxed-simd` is absent.
- [`src/passes/optimize.mbt:455-461`](../../../../../src/passes/optimize.mbt) rejects unknown requested names with `unknown pass flag`.
- There is no `src/passes/remove_relaxed_simd.mbt` owner file, no dispatcher case, no preset slot, and no active backlog slice found in this run.

That means a future port should start with a deliberate registry choice. Until real rewriting exists, do not add the pass as active. If the project wants discoverability before implementation, use the boundary-only vocabulary honestly and keep the rejection message explicit.

## Existing surfaces a port can reuse

| Surface | Code location | Port relevance |
| --- | --- | --- |
| Relaxed SIMD opcode inventory | [`src/wast/types.mbt:720-740`](../../../../../src/wast/types.mbt) | Gives the full local enum set to classify. |
| WAT keyword spellings | [`src/wast/keywords.mbt:440-468`](../../../../../src/wast/keywords.mbt) | Shows current Starshine names, including `relaxed_dot` spellings that differ from Binaryen's lit spelling. |
| Binary codec | [`src/binary/encode.mbt:3792-3814`](../../../../../src/binary/encode.mbt), [`src/binary/decode.mbt:3783-3813`](../../../../../src/binary/decode.mbt) | Confirms relaxed opcodes already survive binary roundtrips. |
| Type checking | [`src/validate/typecheck.mbt:3710-3729`](../../../../../src/validate/typecheck.mbt), [`src/validate/typecheck.mbt:9573-9790`](../../../../../src/validate/typecheck.mbt) | Provides arity and `v128` validation expectations for unary, binary, and ternary families. |
| HOT representation | [`src/ir/hot_lift.mbt:1178-1198`](../../../../../src/ir/hot_lift.mbt), [`src/ir/hot_lower.mbt:1091`](../../../../../src/ir/hot_lower.mbt) | Relaxed SIMD can already be carried as `HotOp::Simd`; a HOT pass could classify the stored instruction payload. |
| Text output caveat | [`src/lib/show.mbt:2106-2113`](../../../../../src/lib/show.mbt) | Pretty-printer dot-product names currently omit some underscores; verify before WAT roundtrip oracle tests. |

## Minimum viable port slice

A safe first slice should be intentionally small:

1. Add a reduced classifier for all local relaxed SIMD instruction variants from [`src/wast/types.mbt:720-740`](../../../../../src/wast/types.mbt).
2. Add tests proving that a requested pass is still rejected until implementation lands, or reserve it as boundary-only with an explicit unsupported message.
3. Implement one unary relaxed opcode replacement to a typed trap shape.
4. Preserve child effects before the trap; do not simply drop operands.
5. Validate the rewritten function/module.
6. Expand to binary and ternary relaxed opcodes.
7. Add ordinary-SIMD preservation tests.
8. Only then compare against Binaryen's `test/lit/passes/remove-relaxed-simd.wast` reductions.

The hard part is step 4. Binaryen uses `ChildLocalizer`; Starshine needs an equivalent local proof. A replacement that erases a child `call`, `load`, `store`, or trapping expression is not Binaryen-compatible.

## Shape-specific test ladder

Use the shape catalog in [`wat-shapes.md`](wat-shapes.md) as the source of reduced tests.

### Unary relaxed operation

Start with one relaxed truncation:

```wat
(drop (i32x4.relaxed_trunc_f32x4_s (local.get 0)))
```

Expected local invariant: the relaxed opcode is gone and the expression traps in a valid `v128`-typed context.

### Binary relaxed operation

Then cover a binary opcode such as `f32x4.relaxed_min` or `i8x16.relaxed_swizzle`.

Expected invariant: both operands are evaluated before the trap if they have effects.

### Ternary relaxed operation

Then cover `f32x4.relaxed_madd` or a lane-select.

Expected invariant: all three children are preserved in evaluation order before the trap.

### Ordinary SIMD preservation

Include deterministic SIMD neighbors such as `i8x16.swizzle` and `v128.bitselect`.

Expected invariant: non-relaxed SIMD output is unchanged by this pass.

## Binaryen oracle comparison order

Do not begin with whole-suite fuzzing. Use this order:

1. Handwritten unary, binary, ternary, and ordinary-SIMD fixtures.
2. Reduced fixtures extracted from Binaryen `test/lit/passes/remove-relaxed-simd.wast`.
3. Binaryen comparison with `wasm-opt --remove-relaxed-simd -S` on those reduced fixtures.
4. Repository pass harness comparison only after the pass is a known local pass name.
5. Wider randomized coverage only after child-effect and typed-result tests are stable.

## Dot-product spelling decision

Binaryen's current lit/source spellings for the dot-product relaxed family omit the textual `relaxed_` prefix:

- `i16x8.dot_i8x16_i7x16_s`
- `i32x4.dot_i8x16_i7x16_add_s`

Current Starshine keyword and printer surfaces use `relaxed_dot` spellings instead, with [`src/lib/show.mbt:2106-2113`](../../../../../src/lib/show.mbt) also omitting some underscores in the printed names.

Before writing oracle tests, decide one of these policies:

- add Binaryen-compatible WAT aliases and keep current spellings as aliases;
- translate Binaryen reduced fixtures before feeding Starshine;
- document that this pass's local tests use Starshine spellings while Binaryen oracle tests use binary input instead of text fixtures.

Do not hide the spelling split inside the pass itself; it is a parser/printer compatibility question.

## Feature metadata caveat

Unlike [`../strip-target-features/index.md`](../strip-target-features/index.md), this pass dossier does not have source proof that Binaryen removes a target-feature custom section after replacing relaxed SIMD operations. The reviewed owner file proves expression trap replacement and function refinalization.

A Starshine port should therefore keep two concerns separate:

- expression lowering: replace relaxed SIMD operations with traps while preserving child effects;
- metadata policy: decide later whether target-feature custom sections need a separate cleanup pass or explicit divergence note.

## Exit criteria for a future Starshine implementation

A local `remove-relaxed-simd` port is not complete until it proves:

- all relaxed SIMD opcodes in [`src/wast/types.mbt:720-740`](../../../../../src/wast/types.mbt) are classified;
- unary, binary, and ternary arities each rewrite;
- side-effecting and trapping children are preserved before the replacement trap;
- typed `v128` result contexts validate after rewrite;
- ordinary SIMD is unchanged;
- Binaryen-vs-Starshine dot-product spelling is resolved for tests;
- requested-pass behavior is intentional and documented;
- feature metadata is either explicitly out of scope or separately implemented with source backing.
