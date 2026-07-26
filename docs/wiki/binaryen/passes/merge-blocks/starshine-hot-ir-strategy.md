---
kind: concept
status: supported
last_reviewed: 2026-07-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp
  - ./index.md
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
---

# Starshine HOT-IR Code Map For `merge-blocks`

Read [`./starshine-strategy.md`](./starshine-strategy.md) for the design. This page is the exact current MoonBit map.

## What the local pass does

Starshine has three local rewrite routes:

- **region-root and loop/block-wrapper flattening:** splice legal dead-label bodies into the parent region;
- **expression-child prefix lifting:** move a legal block prefix before an expression and replace the child with its tail; and
- **raw flat-call repair:** reorder one exact stack-form direct-call `global.set` prefix before HOT lifting.

The second route covers `if` conditions, `drop`, `i32.store`, and `throw`. The third exists because flat binary operand order can be reconstructed differently from equivalent nested WAT.

## Exact local code map

| Lines | Surface | Role |
| --- | --- | --- |
| `src/passes/pass_common.mbt:2-45` | `pass_compute_label_used(...)` / `pass_label_is_used(...)` | Whole-function label-use scan and live-label bailout. |
| `src/passes/merge_blocks.mbt:2-13` | `merge_blocks_descriptor()` | Active HOT descriptor and invalidated analyses. |
| `src/passes/merge_blocks.mbt:20-32` | `merge_blocks_has_candidate(...)` | Cheap live-`Block` scan before deeper work. |
| `src/passes/merge_blocks.mbt:34-77` | root/type helpers | Collect region roots and resolve block parameter types. |
| `src/passes/merge_blocks.mbt:88-154` | `merge_blocks_region_contains_loop(...)` | Refuse a candidate whose body contains a loop. |
| `src/passes/merge_blocks.mbt:155-198` | `merge_blocks_rewrite_dead_unreachable_suffix_roots(...)` | Preserve dead values before `unreachable` as explicit `drop`s. |
| `src/passes/merge_blocks.mbt:199-292` | `merge_blocks_visit_control_node(...)` | Recurse through block, loop, `if`, `try`, and `try-table` regions. |
| `src/passes/merge_blocks.mbt:293-348` | `merge_blocks_can_lift_block_child(...)` | Child-block legality: dead label, no params/loops, multi-root, one-result tail, matching result types. |
| `src/passes/merge_blocks.mbt:350-402` | effect helpers | Category-aware reorder proof; overlapping memory remains ordered because regular atomic order is not represented. |
| `src/passes/merge_blocks.mbt:404-490` | `merge_blocks_lift_expression_block_children(...)` | Preserve the tail child, splice prefixes before its parent, and apply the ordered-effect gate. `if` admits only condition slot `0`. |
| `src/passes/merge_blocks.mbt:492-577` | branch scanners | Reject any candidate prefix containing a branch. |
| `src/passes/merge_blocks.mbt:579-639` | `merge_blocks_flatten_region_root_block(...)` | Main region-root splice and typed-carrier gate. |
| `src/passes/merge_blocks.mbt:641-692` | `merge_blocks_flatten_branch_free_loop_block_body(...)` | Remove branch-free, parameterless, resultless loop/block wrappers. |
| `src/passes/merge_blocks.mbt:694-758` | traversal and run | Visit structured children, lift prefixes, flatten wrappers/roots, and mark mutation. |
| `src/passes/pass_manager.mbt:25600-25750` | raw flat-call bridge | Reorder the exact context-free `global.set` prefix family before lifting; trap/state dependencies fail closed. |
| `src/passes/optimize.mbt:256-259` | registry entry | Active hot-pass registration. |
| `src/passes/optimize.mbt:322-323` / `340-341` | public preset arrays | Repeated late `merge-blocks` placement in `optimize` and `shrink`. |
| `src/passes/pass_manager.mbt:9002` | dispatcher | `merge_blocks_run(ctx, func)` call site. |

## Local safety model

A reader following the code should notice five different safety layers:

1. **labels:** any referenced label keeps its block or loop;
2. **control/type shape:** typed parameters, unsafe loop-containing candidates, and non-one-result tails are rejected;
3. **prefix semantics:** nested branches and conflicting/trapping effect order are rejected;
4. **raw-boundary narrowing:** only flat two-argument direct calls with context-free prefix values and proved-safe earlier slices are reordered; and
5. **writeback stability:** region-root flattening repairs dead-before-`unreachable` values and uses the existing HOT lowering path.

This is deliberately more explicit than an AST rewrite. It also means a source-aligned upstream WAT shape must still pass every local guard before Starshine rewrites it.

## Validation surfaces

- `src/passes/merge_blocks_test.mbt`
  - root flattening, branch-free loop-wrapper removal, loop/live-label, typed-carrier, `unreachable`, reference, and multivalue stability;
  - live-label prefix boundary plus `if`, `drop`, store, throw, pure/disjoint call operands, flat stack-form calls, trapping loads, and local-dependent prefix negatives.
- `src/validate/gen_valid_merge_blocks_tests.mbt`
  - aggregate membership, aliases, labels, validity, deterministic routing, and random-all membership.
- `src/passes/optimize_test.mbt:382-403`, `407-428`, `469-512`
  - repeated preset-slot exposure and `simplify-locals -> merge-blocks` handoff.
- `src/passes/registry_test.mbt:64`, `189-190`, `206-207`, `214-215`
  - active category, descriptor, and preset expansion.
- `src/cmd/cmd_wbtest.mbt:1959-1993`
  - direct CLI acceptance and output validation.

## Sources

- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
- [research note 0720](./index.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/pass_common.mbt`](../../../../../src/passes/pass_common.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
