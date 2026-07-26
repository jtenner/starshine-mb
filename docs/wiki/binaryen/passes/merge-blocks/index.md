---
kind: entity
status: supported
last_reviewed: 2026-07-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeBlocks.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/merge-blocks.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/merge-blocks-atomics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/merge-blocks-eh.wast
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

## 2026-07-25 Binaryen-v131 renewal

The explicit `version_131` owner and lit fixtures do not introduce a new `MergeBlocks.cpp` transform family beyond the already documented structural merge, dropped-block, condition/throw, and generic child-prefix routes. The v130-to-v131 release-impact audit did not classify `merge-blocks` as a direct owner-file reopen.

The relevant v131 shared-helper change is atomic ordering, especially acquire/release and sequentially consistent barriers in `EffectAnalyzer::orderedBefore(...)`. Binaryen's `merge-blocks-atomics.wast` proves the asymmetric rule: a shared read may move before a release store, but may not move from after to before an acquire load; sequentially consistent operations remain barriers in both directions.

Starshine treats represented atomic nodes conservatively as memory effects and therefore fails closed rather than performing the release-store optimization. Its boundary IR does not preserve regular memory-atomic or `atomic.fence` order as an `AtomicOrder`, so exact parity for that v131 surface is a representation blocker rather than a missing local `merge-blocks` predicate. Reopen that family when regular atomic/fence ordering is represented through decode, IR, encode, and HOT effects.

## 2026-07-26 executable renewal

The post-repair audit is closed for the represented surface. Red-first work added the `merge-blocks-all` GenValid aggregate, removed safe branch-free untyped loop/block wrappers, broadened HOT effect reordering only for proved-disjoint categories, and added a narrow raw-boundary bridge for flat two-argument direct calls whose later operand contains a context-free `global.set` prefix. The raw bridge allows pure and disjoint `memory.grow` predecessors, but retains order across trapping loads, global dependencies, and local-dependent prefix values.

The final explicit-v131 matrix is exact: regular GenValid `100000/100000`, dedicated `merge-blocks-all` `10000/10000`, and `random-all-profiles` `10000/10000`; wasm-smith is `9956/9956` for every comparable case, with only 44 classified Binaryen-v131 parser/tool failures. All lanes have zero Starshine validation, property, generator, or comparison failures. See [`./fuzzing.md`](./fuzzing.md).

## Beginner summary

**Binaryen:** merge safe structural blocks; when a block supplies a value to another expression, move only a safe prefix out and keep its tail in the operand slot.

**Starshine:** flatten guarded dead-label HOT roots and branch-free loop/block wrappers, lift guarded expression-child prefixes while retaining their tails, and repair one exact flat-stack direct-call encoding family before HOT lifting.

## Inputs, outputs, and correctness

| | Binaryen | Starshine |
| --- | --- | --- |
| Input | Function-local expression AST; child blocks, loops, and expression operands. | Decoded function bodies plus lifted `HotFunc` regions, ordered child slots, whole-function label use, and type context. |
| Output | Fewer structural wrappers; simpler eligible expression operands; refinalized AST. | Reordered exact flat-call prefixes, flattened guarded roots/wrappers, and lifted guarded prefixes; HOT lowering/writeback remains valid. |
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
- `src/passes/merge_blocks.mbt` implements region-root flattening, branch-free loop/block-wrapper removal, expression-child prefix lifting, and category-aware effect reordering.
- `src/passes/pass_manager.mbt` owns the narrow pre-lift flat direct-call prefix bridge required by stack-form binary inputs.
- `src/passes/merge_blocks_test.mbt` covers `if`, `drop`, store, throw, loop-wrapper, pure/disjoint call-operand, trapping-load, and local-dependency boundaries.
- `src/validate/gen_valid.mbt` and `src/validate/gen_valid_merge_blocks_tests.mbt` own the stable four-family `merge-blocks-all` aggregate.
- The 2026-07-26 explicit-v131 four-lane matrix is exact for every comparable case; the older June evidence is historical only.

## Validation guidance

For documentation work, cross-read the current raw capture, the upstream strategy, local strategy, and exact test map.

For behavior changes:

1. add a focused `merge_blocks_test.mbt` case first;
2. run relevant `src/passes` and `src/cmd` tests;
3. build a fresh native CLI; and
4. run pass-targeted Binaryen comparison with `_build/native/release/build/cmd/cmd.exe` and classify any residual difference from source and replay evidence.

The final 2026-07-26 matrix used native Starshine SHA-256 `ae55a599bde483c6eb05347d85a1a5ef9d2c21c8b47dc100277763b82a0108ca` and explicit Binaryen-v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`. See [`./fuzzing.md`](./fuzzing.md) for commands and counts. The historical 2026-05-06 revalidation remains provenance only.

## Sources

- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>; registration: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>; fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast>
- research note 0720
- research note 0514
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
