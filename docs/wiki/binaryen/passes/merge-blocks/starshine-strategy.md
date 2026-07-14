---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-merge-blocks-expression-child-current-main-recheck.md
  - ../../../raw/research/0720-2026-06-08-merge-blocks-o4z-behavior-audit.md
  - ../../../raw/research/0514-2026-05-06-merge-blocks-direct-revalidation.md
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

Current Starshine `merge-blocks` is a HOT-region cleanup pass. It is not a direct AST port of Binaryen, but it deliberately has two analogous operations:

1. **region-root flattening** for a branch-free nested `Block`; and
2. **expression-child prefix lifting** for an eligible block-valued operand.

The second operation is important: the local pass does not only flatten region roots. It can lift prefixes from the `if` condition, `drop`, `i32.store`, and `throw` fixtures covered in the direct test file.

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
- no effect-order violation: either the prefix or all earlier sibling operands must be pure.

These guards make the local rewrite safe for the present HOT representation. They also mean a matching WAT outline is not evidence that every upstream `MergeBlocks.cpp` case is implemented.

## Upstream relationship

Current Binaryen has generic non-control expression-child extraction alongside special drop/if/throw visitors. Starshine uses one HOT helper for its supported `drop`, `if`, store, and `throw` fixtures, so the local routing is not a literal visitor-for-visitor port. The representations differ:

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
| `src/passes/merge_blocks.mbt` | `293-334` | Candidate legality for a block-valued expression child. |
| `src/passes/merge_blocks.mbt` | `336-414` | Prefix lift, ordered-child replacement, and HOT effect gate. |
| `src/passes/merge_blocks.mbt` | `415-490` | Recursive branch detection for prefixes. |
| `src/passes/merge_blocks.mbt` | `492-583` | Region-root flattening and traversal. |
| `src/passes/merge_blocks_test.mbt` | `2138-2166` | Live-label boundary. |
| `src/passes/merge_blocks_test.mbt` | `2168-2295` | `if` condition, `drop`, store, and `throw` expression-child cases. |

## Existing validation evidence

The 2026-05-06 direct revalidation ran `moon info`, `moon fmt`, `moon test`, mixed-generator `pass-fuzz-compare` for `--merge-blocks`, and debug-artifact `self-optimize-compare` for `--merge-blocks`.

- `moon test`: `2798` passed, `0` failed.
- `.tmp/pass-fuzz-merge-blocks`: `9975/10000` comparable cases, `9975` normalized matches, `0` mismatches, and `25` Binaryen/tool command failures in wasm-smith lanes.
- Debug artifact: normalized WAT equality and canonical function equality; Starshine pass runtime `214.434 ms` versus Binaryen `1526.350 ms`.

This is historical validation, not a substitute for a new pass signoff after behavior changes. See [`../../../raw/research/0514-2026-05-06-merge-blocks-direct-revalidation.md`](../../../raw/research/0514-2026-05-06-merge-blocks-direct-revalidation.md).

## Sources

- [`../../../raw/binaryen/2026-07-11-merge-blocks-expression-child-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-merge-blocks-expression-child-current-main-recheck.md)
- [`../../../raw/research/0720-2026-06-08-merge-blocks-o4z-behavior-audit.md`](../../../raw/research/0720-2026-06-08-merge-blocks-o4z-behavior-audit.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
