---
kind: concept
status: supported
last_reviewed: 2026-07-31
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

Current Starshine `merge-blocks` is primarily a HOT-region cleanup pass, supplemented by narrow raw and lowered-form repairs where stack reconstruction or type finalization would otherwise lose Binaryen-v131 behavior. It is not a direct AST port, but it deliberately has four analogous operations:

1. **region-root and branch-free loop/block-wrapper flattening**, including dropped self-target branch payload cleanup;
2. **expression-child prefix lifting** for eligible block-valued operands;
3. **raw stack repair** for exact flat call/drop, ordered-atomic, multivalue-drop, and unused reference-catch families; and
4. **lowered canonicalization** for all-null reference results, scalar spills, and unused appended locals.

Expression-child lifting covers the `if` condition, `drop`, `i32.store`, and `throw` fixtures. Raw movement crosses only proved pure or disjoint predecessors; trapping and state-dependent cases remain ordered.

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

These guards make the local rewrite safe for the present HOT representation. General regular memory atomics remain conservative because their acquire/release ordering is not represented at the boundary; the official v131 atomic fixture is handled by a narrow exact raw bridge instead. A matching WAT outline is therefore not evidence that arbitrary atomic extraction is implemented.

## Raw and lowered boundary repair

`run_hot_pipeline_raw_merge_blocks_flat_call_prefix(...)` handles only flat functions and exact two-argument direct calls shaped as an earlier value, a context-free value feeding `global.set`, a one-instruction tail value, and the call. It moves the pair only when the earlier slice has no branch, trap/unknown operation, global access, call, or exception boundary. `memory.grow` is admitted as a nontrapping disjoint memory-state operation.

Sibling raw helpers cover call/drop prefixes, literal multivalue drops, and the official ordered-atomic fixture. Recursive preclean handles direct or nested dropped self-branch payloads and unused reference catches. After HOT lowering, descriptor-specific cleanup narrows all-null branch results to hierarchy bottoms, removes redundant casts/dead suffixes, flattens scalar spill blocks, and compacts unused appended locals. Each helper has an exact shape contract; unsupported structured or effectful forms fail closed.

## Upstream relationship

Current Binaryen has generic non-control expression-child extraction alongside special drop/if/throw visitors. Starshine uses one HOT helper for its supported `drop`, `if`, store, and `throw` fixtures plus the narrow raw stack-form bridge, so the local routing is not a literal visitor-for-visitor port. The representations differ:

| Topic | Binaryen | Starshine |
| --- | --- | --- |
| IR | expression tree | HOT regions plus ordered child slots |
| generic extraction | `visitExpression(...)` over eligible **non-control** children; separate special visitors for drop/if/throw | `merge_blocks_lift_expression_block_children(...)` across supported HOT child slots |
| label policy | unnamed AST block / source helper proof | hard whole-function live-label bailout |
| prefix branch policy | source-level structural proof | explicit recursive branch rejection |
| type repair | AST refinalization | HOT guards plus later lowering/validation |

Do not infer arbitrary operand or atomic extraction from one matching fixture. The July 31 closeout claims parity only for the audited source families, focused tests, checked-in v131 fixtures, dedicated aggregate, and classified four-lane matrix.

## Exact current locations

| File | Lines | Role |
| --- | --- | --- |
| `src/passes/merge_blocks.mbt` | `293-402` | Child legality and category-aware effect-order proof. |
| `src/passes/merge_blocks.mbt` | `404-490` | Prefix lift and ordered-child replacement. |
| `src/passes/merge_blocks.mbt` | `492-577` | Recursive branch detection for prefixes. |
| `src/passes/merge_blocks.mbt` | root cleanup and traversal | Region roots, branch-free loops/wrappers, dropped branch payloads, expression-child lifting, and O4z self-`br_if` cleanup. |
| `src/passes/pass_manager.mbt` | raw/preclean/lowered helpers | Flat calls, call/drop, atomics, multivalue drops, nested dropped branches, reference catches, bottom types, spill flattening, and local compaction. |
| `src/passes/merge_blocks_test.mbt` | direct behavior | Structural, expression, effect-order, branch-value, loop, call, atomic, and negative boundaries. |
| `src/passes/pass_manager_wbtest.mbt` / `code_folding_test.mbt` | boundary and ordered behavior | Checked-in fixtures, lowered canonicalization, O4z block-exit, and EH payload cleanup. |

## Current validation evidence

The 2026-07-31 focused signoff passes `63/63` direct tests, `195/195` ordered `code-folding` tests, and `311/311` pass-manager white-box tests. The retained slot-42 repro validates.

Using native SHA-256 `01fd7706f67cf5d2628a4339b6f78d02cadcb541e830d9c7219e6136703cfcf0` and explicit Binaryen-v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`, regular GenValid is exact `100000/100000`, `merge-blocks-all` exact `10000/10000`, and wasm-smith exact for all `9956` comparable cases. Random-all is `9827` exact plus `173` strictly smaller Starshine outputs totaling `-1130` bytes, with no ties or losses. The 44 excluded wasm-smith cases are classified Binaryen-v131 parser/tool failures. See [`./fuzzing.md`](./fuzzing.md).

## Sources

- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
- [research note 0720](./index.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
