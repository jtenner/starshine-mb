---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp
  - ./index.md
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
---

# `merge-blocks` Implementation Structure And Tests

Use this page to map current upstream owner/test evidence to the active Starshine HOT pass. The 2026-07-11 review corrects an incomplete owner map: Binaryen retains dedicated drop/if/throw visitors while also using generic non-control expression-child extraction for ordinary operands.

## Upstream Binaryen owner

Primary owner:

- current main [`src/passes/MergeBlocks.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp)
- release anchor [`version_130/src/passes/MergeBlocks.cpp`](https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/MergeBlocks.cpp)

| Current source unit | Role |
| --- | --- |
| `visitBlock(...)` / `optimizeBlock(...)` | Merge a legal nested child block into its parent block list. |
| `visitLoop(...)` | Merge a legal tail block into a loop body. |
| `visitDrop(...)` / `optimizeDroppedBlock(...)` | Handle dropped-block cleanup and preserved break values. |
| `visitIf(...)` | Handle the condition only; arms remain control regions. |
| `visitThrow(...)` | Handle throw operands under the relevant effect boundary. |
| `visitExpression(...)` | Extract a legal block prefix from an ordinary non-control child slot while retaining its tail as the child. |
| `visitFunction(...)` | Run the traversal and refinalize after rewrites. |
| `ProblemFinder` / break-value support | Protect the branch/value-sensitive structural cleanup paths. |

The special visitors and generic visitor are complementary: `drop`, `if`, and `throw` are not evidence that all ordinary child extraction is special-cased.

## Upstream proof surface

Focused fixture:

- current main [`test/lit/passes/merge-blocks.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-blocks.wast)
- release anchor [`version_130/test/lit/passes/merge-blocks.wast`](https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/merge-blocks.wast)

The reviewed fixture covers:

- safe child-block and loop-tail merging;
- special dropped-block and `if`-condition cleanup;
- generic ordinary-child extraction through aggregate and multi-argument call fixtures;
- type/result and effect-order boundaries;
- the interaction with `remove-unused-names` when block names are absent.

For source work, read the owner and fixture together. The owner establishes the legality/effect rule; a fixture establishes a concrete observable shape.

## Current Starshine owner map

Primary owner:

- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)

| Lines | Surface | Role |
| --- | --- | --- |
| `2-17` | descriptor / summary | Active HOT pass declaration. |
| `20-87` | candidates / type helpers | Fast candidate scan, region-root collection, and typed block parameter resolution. |
| `88-154` | loop scan | Reject a candidate body containing a loop. |
| `155-292` | unreachable repair / control traversal | Maintain writeback-safe dead-value shape, then recurse through regions. |
| `293-334` | child eligibility | Require a dead label, no params/loops, at least two roots, one-result tail, and matching result type. |
| `336-414` | child-prefix lifting | Replace a child block with its tail and splice legal prefixes before the parent expression. |
| `415-490` | branch scanners | Reject lift candidates whose prefixes contain branches. |
| `492-603` | root flatten / run | Region-root splice, traversal order, mutation marking. |

## Local direct tests

Primary proof file:

- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)

| Lines | Test family |
| --- | --- |
| `38-2137` | Region-root flattening; loop/live-label, typed-carrier, multivalue, reference, and `unreachable` stability. |
| `2138-2166` | A live-label block retains its prefix boundary. |
| `2168-2198` | Condition-prefix lift. |
| `2200-2232` | `drop`-operand prefix lift. |
| `2234-2266` | Store-operand lift without reordering effects. |
| `2268-2295` | `throw`-operand prefix lift. |

The four expression tests establish a targeted correspondence, not an exhaustive operand-family signoff.

## Registry, dispatch, and integration evidence

| Location | Evidence |
| --- | --- |
| `src/passes/optimize.mbt:256-259` | Active hot-pass registry entry. |
| `src/passes/optimize.mbt:322-323`, `340-341` | Repeated late preset slots. |
| `src/passes/pass_manager.mbt:9002` | `merge_blocks_run(ctx, func)` dispatcher arm. |
| `src/passes/registry_test.mbt:64`, `189-190`, `206-207`, `214-215` | Active category, descriptor, and preset tests. |
| `src/passes/optimize_test.mbt:382-403`, `407-428`, `469-512` | Repeated slot and `simplify-locals` handoff coverage. |
| `src/cmd/cmd_wbtest.mbt:1959-1993` | Direct `--merge-blocks` CLI coverage. |

## Binaryen–Starshine boundary

Both implementations have expression-child prefix extraction, but their safety proofs are not interchangeable. Binaryen works in an expression AST and refinalizes. Starshine edits HOT child arrays and regions, imposes a hard live-label bailout, rejects branch prefixes and loop-containing candidates, and relies on HOT writeback validation. A future parity claim needs source-family review plus dedicated comparison evidence, not just matching these tests.

## Validation guidance

For a behavior change:

1. add a focused fixture in `src/passes/merge_blocks_test.mbt` and demonstrate its intended red state;
2. run `moon test src/passes` and `moon test src/cmd` when the public surface changes;
3. build a fresh native CLI with `moon build --target native --release src/cmd`;
4. use a pass-targeted `compare-pass --pass merge-blocks ... --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` lane; and
5. classify output differences from inspected transform evidence rather than validation alone.

Do not use a stale `target/native/...` artifact as current signoff evidence; see [`../../../AGENTS.md`](../../../AGENTS.md) and [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md).

## 2026-07-21 correctness hardening

The HOT unreachable-root repair now moves only effect-free, nontrapping values before an `unreachable`. An effectful root in the ambiguous post-terminator root suffix makes block flattening fail closed, because it may be source-level dead code that originally followed the trap. `merge_blocks_test.mbt` covers a dead call that previously became live before `unreachable`.

## Sources

- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
- [research note 0720](./index.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
