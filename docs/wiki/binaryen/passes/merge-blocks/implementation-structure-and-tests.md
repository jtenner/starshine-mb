---
kind: concept
status: supported
last_reviewed: 2026-07-26
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
- release anchor [`version_131/src/passes/MergeBlocks.cpp`](https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeBlocks.cpp)

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
- release anchors [`version_131/test/lit/passes/merge-blocks.wast`](https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/merge-blocks.wast), [`merge-blocks-atomics.wast`](https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/merge-blocks-atomics.wast), and [`merge-blocks-eh.wast`](https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/merge-blocks-eh.wast)

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
| `293-348` | child eligibility | Require a dead label, no params/loops, at least two roots, one-result tail, and matching result type. |
| `350-402` | effect ordering | Permit pure/disjoint categories while rejecting control, call, throw, trap/write, local/global, memory, and table conflicts. |
| `404-490` | child-prefix lifting | Replace a child block with its tail and splice legal prefixes before the parent expression. |
| `492-577` | branch scanners | Reject lift candidates whose prefixes contain branches. |
| `579-758` | root/wrapper flatten and run | Region-root splice, branch-free loop/block removal, traversal order, mutation marking. |
| `src/passes/pass_manager.mbt:25600-25750` | raw flat-call bridge | Repair the exact two-argument stack-form `global.set` prefix family before HOT lifting. |

## Local direct tests

Primary proof file:

- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)

| Lines | Test family |
| --- | --- |
| `38-2319` | Region-root flattening; loop/live-label, typed-carrier, multivalue, reference, `unreachable`, and expression-child stability. |
| `132-157` | Branch-free untyped loop/block-wrapper removal. |
| `2322-2354` | Effectful prefix crossing a pure earlier call operand. |
| `2356-2569` | Direct flat stack-form call fixture: pure and `memory.grow` positives; trapping-load and local-dependency negatives; repeated eligible calls. |
| `2571+` | Disjoint memory/global HOT case plus throw and remaining expression families. |

These tests establish the represented direct-call and effect-order families; regular acquire/release memory-atomic ordering remains outside the boundary representation.

## Registry, dispatch, and integration evidence

| Location | Evidence |
| --- | --- |
| `src/passes/optimize.mbt:256-259` | Active hot-pass registry entry. |
| `src/passes/optimize.mbt:322-323`, `340-341` | Repeated late preset slots. |
| `src/passes/pass_manager.mbt:25580-25780`, dispatcher pipeline | Prefiltered raw flat-call bridge followed by `merge_blocks_run(ctx, func)`. |
| `src/passes/registry_test.mbt:64`, `189-190`, `206-207`, `214-215` | Active category, descriptor, and preset tests. |
| `src/passes/optimize_test.mbt:382-403`, `407-428`, `469-512` | Repeated slot and `simplify-locals` handoff coverage. |
| `src/cmd/cmd_wbtest.mbt:1959-1993` | Direct `--merge-blocks` CLI coverage. |

## Binaryen–Starshine boundary

Both implementations have expression-child prefix extraction, but their safety proofs are not interchangeable. Binaryen works in an expression AST and refinalizes. Starshine edits HOT child arrays and regions, imposes hard label/type/branch/effect gates, uses one exact raw stack-form bridge, and relies on HOT writeback validation. The 2026-07-26 represented-surface parity claim is backed by the dedicated aggregate and four-lane explicit-v131 matrix, not tests alone.

## Validation guidance

For a behavior change:

1. add a focused fixture in `src/passes/merge_blocks_test.mbt` and demonstrate its intended red state;
2. run `moon test src/passes` and `moon test src/cmd` when the public surface changes;
3. build a fresh native CLI with `moon build --target native --release src/cmd`;
4. use a pass-targeted `compare-pass --pass merge-blocks ... --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` lane; and
5. classify output differences from inspected transform evidence rather than validation alone.

Do not use a stale `target/native/...` artifact as current signoff evidence; see [`../../../AGENTS.md`](../../../AGENTS.md) and [`../../../tooling/pass-fuzz-compare.md`](../../../tooling/pass-fuzz-compare.md).

## Correctness hardening and closeout

The 2026-07-21 HOT unreachable-root repair moves only effect-free, nontrapping values before an `unreachable`; ambiguous effectful roots fail closed. The 2026-07-26 closeout additionally removes safe branch-free untyped loop/block wrappers, admits only proved-disjoint HOT effect motion, and repairs the exact flat two-argument direct-call encoding family. Red-first tests cover each positive and negative boundary.

Final validation: focused `55/55`, `src/validate` `1719/1719`, `src/passes` `6445/6445`, native and wasm-gc full Moon `9933/9933`, direct wasm-gc check, README/API sync, and the full CI fuzz suite including `86820` binary roundtrips; native SHA-256 `ae55a599bde483c6eb05347d85a1a5ef9d2c21c8b47dc100277763b82a0108ca`, regular `100000/100000`, dedicated `10000/10000`, random-all `10000/10000`, and wasm-smith `9956/9956` comparable matches with 44 classified Binaryen-only failures.

## Sources

- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
- [research note 0720](./index.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
