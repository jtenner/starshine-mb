---
kind: entity
status: supported
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
supersedes:
---

# `merge-blocks`

## Role

`merge-blocks` is an active implemented **hot pass** in Starshine and a late structural cleanup pass in Binaryen.

Current upstream Binaryen has two complementary rewrite layers:

- merge eligible nested child blocks into parent block lists and loop tails; and
- extract a legal prefix from a block-valued expression child while leaving that block's tail as the child.

The generic non-control rule covers ordinary operands such as `i32.store`; dedicated `visitDrop(...)`, `visitIf(...)`, and `visitThrow(...)` routes cover their special surfaces. None is arbitrary flattening. Current Starshine has a narrower HOT analogue in addition to its region-root flattening.

## 2026-07-11 current-source correction

Older local prose correctly rejected named-block retargeting as the main story, but still taught the current owner as a few special `drop`, `if`, and `throw` helpers and described Starshine as root-only flattening. Both descriptions were incomplete.

The source-backed current contract is:

- Binaryen merges safe child blocks and loop tails;
- its generic expression visitor can move a legal **block prefix** before a non-control parent expression while retaining the final block item as that expression child;
- dedicated drop/if-condition/throw visitors coexist with that generic route; `i32.store` is a representative ordinary-child shape;
- unnamed/multi-item/result-tail shape and `EffectAnalyzer::orderedBefore(...)` constrain the move;
- Starshine has a guarded HOT counterpart with live-label, type, loop, branch-prefix, and effect gates.

The July 11, 2026 source review supersedes the prior *current-source interpretation*; its durable facts are retained here and grounded in Binaryen's current [`MergeBlocks.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp), [`pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp), and [`merge-blocks.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast). Older retained research stays as historical provenance.

## Beginner summary

**Binaryen:** merge safe structural blocks; when a block supplies a value to another expression, move only a safe prefix out and keep its tail in the operand slot.

**Starshine:** flatten a guarded dead-label HOT block root, or lift a guarded dead-label block prefix from an eligible expression child while retaining its tail.

## Inputs, outputs, and correctness

| | Binaryen | Starshine |
| --- | --- | --- |
| Input | Function-local expression AST; child blocks, loops, and expression operands. | Lifted `HotFunc`; regions, ordered child slots, whole-function label use, and type context. |
| Output | Fewer structural wrappers; simpler eligible expression operands; refinalized AST. | Flattened guarded roots and lifted guarded prefixes; HOT lowering/writeback remains valid. |
| Core safety | Preserve branch/result behavior and left-to-right operand effects. | Preserve live labels, typed carriers, branch-free prefixes, loop boundaries, effects, and dead-before-`unreachable` values. |

Do not infer a rewrite merely because the output validates. In particular, moving a prefix past an earlier effectful operand changes WebAssembly execution order and is invalid.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) — current upstream structural merging plus generic expression-child prefix extraction.
- [`./wat-shapes.md`](./wat-shapes.md) — beginner-safe before/after shapes for block/loop, special drop/if/throw routes, generic store-shaped extraction, and effect-order negatives.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) — source owner/test map and exact Starshine locations.
- [`./starshine-strategy.md`](./starshine-strategy.md) — local rules, intentionally narrower boundaries, and historical validation evidence.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) — exact HOT helper, traversal, registry, dispatch, and test map.

## Current local status

- `merge-blocks` is registered, dispatched, and accepted by the CLI.
- Both public presets run it twice in the late cleanup cluster around `simplify-locals`, `remove-unused-brs`, and `remove-unused-names`.
- `src/passes/merge_blocks.mbt` implements both region-root flattening and expression-child prefix lifting.
- `src/passes/merge_blocks_test.mbt:2168-2295` covers the local `if` condition, `drop`, `i32.store`, and `throw` examples; this is targeted correspondence, not an exhaustive upstream operand-family parity claim.
- The 2026-06-08 behavior audit records a behavior-normalized 100000-case comparison with zero mismatches, while keeping three raw unnormalized debris mismatches explicitly non-semantic.

## Validation guidance

For documentation work, cross-read the current raw capture, the upstream strategy, local strategy, and exact test map.

For behavior changes:

1. add a focused `merge_blocks_test.mbt` case first;
2. run relevant `src/passes` and `src/cmd` tests;
3. build a fresh native CLI; and
4. run pass-targeted Binaryen comparison with `_build/native/release/build/cmd/cmd.exe` and classify any residual difference from source and replay evidence.

The historical 2026-05-06 direct revalidation found `9975/10000` comparable normalized matches, zero mismatches, and 25 Binaryen/tool failures in wasm-smith lanes; its debug-artifact run had normalized WAT and canonical-function equality. See research note 0514. It is historical evidence, not a substitute for post-change signoff.

## Sources

- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>; registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>; fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast>
- research note 0720
- research note 0514
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
