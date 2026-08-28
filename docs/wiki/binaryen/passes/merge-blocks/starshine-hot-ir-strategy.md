---
kind: concept
status: supported
last_reviewed: 2026-08-28
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp
  - ./index.md
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/ir/effects_test.mbt
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/passes/pass_common_wbtest.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes_perf_long/merge_blocks_perf_test.mbt
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

Starshine has four local rewrite routes:

- **region-root and loop/block-wrapper cleanup:** splice legal dead-label bodies, flatten branch-free loops, and clean dropped self-target branch payloads;
- **expression-child prefix lifting:** move a legal block prefix before an expression and replace the child with its tail;
- **raw/pre-lift repair:** handle exact flat calls, call/drop prefixes, the official ordered-atomic fixture, literal multivalue drops, nested dropped branches, and unused reference catches; and
- **lowered canonicalization:** narrow all-null reference results, remove redundant casts/dead suffixes, flatten scalar spills, and compact unused appended locals.

Expression-child lifting covers `if` conditions, `drop`, `i32.store`, and `throw`. The boundary routes exist because flat binary operand order and reference typing can be reconstructed differently from equivalent nested WAT.

## August 28, 2026 shared-context envelope rule

Raw MergeBlocks helpers that resolve function or type signatures must consume the dispatcher's cached `HotModuleContext`; they must not call `hot_module_context_from_module(...)` once per function. The dropped-multivalue and flat call/drop-prefix helpers retain an optional fallback only for isolated tests and direct helper use. Production dispatch resolves the context through `run_hot_pipeline_require_module_ctx(...)` and supplies the same value to both helpers.

This rule reduced the canonical function envelope from `10,170.084ms` to `153.500ms` without changing a byte of output. The direct command now beats Binaryen v131 at `0.935x`, while pass-local work remains much faster at `0.044x`.

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
| `src/ir/effects.mbt` | exact numeric effect classification | Mark integer division/remainder and non-saturating float-to-int conversions as trapping. |
| `src/passes/pass_common.mbt` | `pass_effect_masks_can_reorder(...)` | Shared conservative reorder proof; two represented potentially trapping expressions stay ordered, and overlapping memory remains ordered because regular atomic order is not represented. |
| `src/passes/merge_blocks.mbt` | `merge_blocks_lift_expression_block_children(...)` | Preserve the tail child, splice prefixes before its parent, and apply the shared ordered-effect gate. `if` admits only condition slot `0`. |
| `src/passes/merge_blocks.mbt` | `merge_blocks_compute_drop_parent_index(...)` / `merge_blocks_drop_parent_index_contains(...)` | Lazily build one function-snapshot bitset on the first relevant multivalue root instead of rescanning every live node per candidate; scalar-only functions avoid the scan. |
| `src/passes/merge_blocks.mbt` | branch scanners | Reject any candidate prefix containing a branch. |
| `src/passes/merge_blocks.mbt` | `merge_blocks_flatten_region_root_block(...)` | Main region-root splice and typed-carrier gate, including constant-time drop-parent lookup. |
| `src/passes/merge_blocks.mbt` | structural and dropped-branch helpers | Remove branch-free parameterless/resultless loops and wrappers, clean dropped self-branch payloads, and apply the O4z-only redundant self-`br_if` cleanup. |
| `src/passes/merge_blocks.mbt` | traversal and run | Visit structured children, lift prefixes, flatten wrappers/roots, and mark mutation. |
| `src/passes/pass_manager.mbt` | raw/preclean/lowered helpers | Repair exact stack-form families before lifting and canonicalize reference/spill/local shapes after lowering; raw signature-dependent helpers reuse the dispatcher's cached `HotModuleContext`; unsafe or unknown forms fail closed. |
| `src/passes/optimize.mbt:256-259` | registry entry | Active hot-pass registration. |
| `src/passes/optimize.mbt:322-323` / `340-341` | public preset arrays | Repeated late `merge-blocks` placement in `optimize` and `shrink`. |
| `src/passes/pass_manager.mbt:9002` | dispatcher | `merge_blocks_run(ctx, func)` call site. |

## Local safety model

A reader following the code should notice six different safety layers:

1. **labels:** any referenced label keeps its block or loop;
2. **control/type shape:** typed parameters, unsafe loop-containing candidates, and non-one-result tails are rejected;
3. **prefix semantics:** nested branches, conflicting effects, and every trap/trap crossing are rejected through the shared pass predicate;
4. **raw-boundary narrowing:** only exact call/drop, atomic, multivalue, branch-payload, and reference-catch shapes are rewritten;
5. **lowered-type proof:** all-null result narrowing requires one compatible abstract hierarchy bottom and exact branch structure; scalar spill flattening requires a no-parameter single-result block containing only context-free value/set pairs plus its final get; and
6. **writeback stability:** region-root flattening repairs dead-before-`unreachable` values and uses validated HOT lowering/writeback.

This is deliberately more explicit than an AST rewrite. It also means a source-aligned upstream WAT shape must still pass every local guard before Starshine rewrites it.

## Validation surfaces

- `src/passes/merge_blocks_test.mbt`
  - root flattening, branch-free loop removal, loop/live-label, typed-carrier, `unreachable`, reference, multivalue, and dropped-branch behavior;
  - live-label prefix boundary plus `if`, `drop`, store, throw, pure/disjoint call operands, flat stack-form calls, load/division, two-load, table/division, atomic/division trap-order guards, and local-dependent negatives.
- `src/passes_perf_long/merge_blocks_perf_test.mbt`
  - skipped native-release 4,000-block call-backed partial-drop multivalue benchmark across four valid 1,000-result functions, pass-local timer output, pipeline median, and the one full-function scan per indexed function invariant.
- `src/passes/pass_manager_wbtest.mbt`
  - checked-in v131 main/atomic fixtures, stack-safe call/drop repair, bottom-reference refinalization, scalar/type-indexed spill flattening, and local compaction.
- `src/passes/code_folding_test.mbt`
  - O4z post-`code-folding` block-exit cleanup and unused reference-catch payload conversion.
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
