---
kind: concept
status: supported
last_reviewed: 2026-07-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp
  - ./index.md
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-hot-ir-strategy.md
  - ../simplify-locals/index.md
  - ../remove-unused-brs/index.md
  - ../remove-unused-names/index.md
---

# Starshine Strategy For `merge-blocks`

Current Starshine `merge-blocks` is primarily a HOT-region cleanup pass, with one narrow raw-boundary repair for a stack-form encoding that HOT lifting otherwise preserves. It is not a direct AST port of Binaryen, but it deliberately has three analogous operations:

1. **region-root and branch-free loop/block-wrapper flattening**;
2. **expression-child prefix lifting** for eligible block-valued operands; and
3. **flat direct-call prefix reordering** for one exact two-argument `global.set` family before HOT lifting.

The second operation covers the `if` condition, `drop`, `i32.store`, and `throw` fixtures. The third closes the binary stack-form equivalent when the prefix can cross an earlier pure or disjoint `memory.grow` operand, while trapping and state-dependent cases remain ordered.

## Region-root flattening

For a region-root `Block`, Starshine:

- computes whole-function label use;
- retains every live-label block;
- rejects unsupported typed block-parameter/carrier combinations;
- rejects blocks containing loops;
- rewrites dead value roots before `unreachable` into explicit `drop`s;
- splices the remaining roots into the parent region; and
- marks the function mutated only after an actual splice.

This is a HOT/writeback safety contract. It is stricter than simply removing syntactic wrappers.

## Expression-child prefix lifting

`merge_blocks_lift_expression_block_children(...)` examines ordinary child slots of a HOT node. When a child is a legal `Block`, it:

1. keeps the final child-region root as the operand tail;
2. inserts preceding roots immediately before the parent expression in the surrounding region; and
3. replaces the original child slot with that tail.

The implementation does **not** descend through block/loop/try/try-table nodes by this route. For `if`, it considers only child slot `0`, the condition; arms remain regions.

### Local guards

The HOT helper requires more than Binaryen's AST-level shape:

- block label unused in the whole function;
- no typed block parameters;
- no loop anywhere in the candidate body;
- at least two body roots;
- one-result tail whose result type matches the block's result type;
- no branch in the lifted prefix;
- no effect-order violation: pure operands reorder freely; local/global conflicts, hard control/call/throw barriers, trap-versus-write pairs, and overlapping memory/table categories do not; disjoint represented categories may reorder.

These guards make the local rewrite safe for the present HOT representation. Regular memory atomics remain conservative because their acquire/release ordering is not represented at the boundary. A matching WAT outline is therefore not evidence that every upstream `MergeBlocks.cpp` case is implemented.

## Flat stack-form direct calls

`run_hot_pipeline_raw_merge_blocks_flat_call_prefix(...)` handles only flat functions and exact two-argument direct calls shaped as an earlier value, a context-free value feeding `global.set`, a one-instruction tail value, and the call. It moves the `global.set` pair before the earlier value only when the earlier value slice has no branch, trap/unknown operation, global access, call, or exception boundary. `memory.grow` is admitted as a nontrapping disjoint memory-state operation. Structured functions, local/global-dependent prefix producers, loads, atomics, and unknown effects fall through unchanged to the HOT pipeline.

## Upstream relationship

Current Binaryen has generic non-control expression-child extraction alongside special drop/if/throw visitors. Starshine uses one HOT helper for its supported `drop`, `if`, store, and `throw` fixtures plus the narrow raw stack-form bridge, so the local routing is not a literal visitor-for-visitor port. The representations differ:

| Topic | Binaryen | Starshine |
| --- | --- | --- |
| IR | expression tree | HOT regions plus ordered child slots |
| generic extraction | `visitExpression(...)` over eligible **non-control** children; separate special visitors for drop/if/throw | `merge_blocks_lift_expression_block_children(...)` across supported HOT child slots |
| label policy | unnamed AST block / source helper proof | hard whole-function live-label bailout |
| prefix branch policy | source-level structural proof | explicit recursive branch rejection |
| type repair | AST refinalization | HOT guards plus later lowering/validation |

Do not describe the local `i32.store` family as full parity or as a dedicated upstream fixture. The current local tests are targeted examples; broader reference, GC, bulk-memory, call, exception, and multivalue operand families still need direct source-review and compare evidence before they become parity claims.

## Exact current locations

| File | Lines | Role |
| --- | --- | --- |
| `src/passes/merge_blocks.mbt` | `293-402` | Child legality and category-aware effect-order proof. |
| `src/passes/merge_blocks.mbt` | `404-490` | Prefix lift and ordered-child replacement. |
| `src/passes/merge_blocks.mbt` | `492-577` | Recursive branch detection for prefixes. |
| `src/passes/merge_blocks.mbt` | `579-737` | Region-root flattening, branch-free loop/block-wrapper removal, and traversal. |
| `src/passes/pass_manager.mbt` | `25580-25780` | Prefiltered narrow raw flat-call prefix bridge. |
| `src/passes/merge_blocks_test.mbt` | `132-157`, `2322-2569` | Loop-wrapper, call-operand, raw stack-form, trapping-load, local-dependency, and repeated-call coverage. |

## Current validation evidence

The 2026-07-26 final signoff passed `moon info`, `moon fmt`, focused `merge_blocks_test.mbt` (`55/55`), `src/validate` (`1719/1719`), `src/passes` (`6445/6445`), native and wasm-gc full tests (`9933/9933`), direct wasm-gc check, README/API sync, the full CI fuzz suite including `86820` binary roundtrips, and a native release build.

Using native SHA-256 `ae55a599bde483c6eb05347d85a1a5ef9d2c21c8b47dc100277763b82a0108ca` and explicit Binaryen-v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`, regular GenValid was exact `100000/100000`, `merge-blocks-all` exact `10000/10000`, random-all exact `10000/10000`, and wasm-smith exact for all `9956` comparable cases. The 44 excluded wasm-smith cases are classified Binaryen-v131 parser/tool failures. See [`./fuzzing.md`](./fuzzing.md).

## Sources

- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
- [research note 0720](./index.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
