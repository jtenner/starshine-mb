---
kind: concept
status: supported
last_reviewed: 2026-07-31
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp
  - ./index.md
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/ir/effects_test.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/passes/pass_common_wbtest.mbt
  - ../../../../../src/passes/merge_blocks.mbt
  - ../../../../../src/passes/merge_blocks_test.mbt
  - ../../../../../src/passes_perf_long/merge_blocks_perf_test.mbt
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
| shared `effects.mbt` classification plus `pass_common.mbt` predicate | effect ordering | Mark exact trapping numeric operations and permit pure/disjoint categories while rejecting control, call, throw, trap/trap, trap/write, local/global, memory, and table conflicts. |
| child-prefix lifting | Replace a child block with its tail and splice legal prefixes before the parent expression through the shared reorder predicate. |
| drop-parent index | Build one function-snapshot bitset and use constant-time multivalue-root hazard queries instead of a full scan per candidate. |
| branch scanners | Reject lift candidates whose prefixes contain branches. |
| root/wrapper cleanup | Region-root splice, branch-free loop/block removal, dropped self-target branch values, and an O4z-only redundant self-`br_if` wrapper cleanup. |
| pass-manager raw admission | Repair flat call/drop prefixes, the exact v131 ordered-atomic call fixture, and dropped literal multivalue blocks before HOT lifting. |
| pass-manager preclean | Recursively normalize direct and nested dropped self-branch payloads plus unused reference-catch payloads before lifting. |
| pass-manager lowered cleanup | Refinalize all-null reference blocks, flatten scalar spill blocks, compact unused appended locals, and preserve valid stack order. |

## Local direct tests

Primary proof file:

- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)

| Lines | Test family |
| --- | --- |
| Structural roots | Nested blocks, branch-free multi-root loops, loop/live-label negatives, typed carriers, multivalue/reference results, and unreachable suffixes. |
| Dropped branches | Pure scalar and reference payloads, nested wrappers, dropped literal multivalue blocks, and effectful-value negative guards. |
| Expression/effect order | `drop`, `if`, store, throw, direct calls, pure/disjoint predecessors, load/division, two trapping loads, table/division, atomic/division, local/global dependencies, and repeated candidates. |
| Official v131 fixtures | Checked-in main and atomic binaries plus direct EH-focused regressions; the atomic fixture is byte-identical. |
| Lowered/writeback cleanup | Bottom-reference block results, scalar and type-indexed spill blocks, local compaction, and stack-safe multi-parameter calls. |
| Ordered neighborhood | O4z post-`code-folding` block-exit cleanup and unused `catch_ref` / `catch_all_ref` payload removal. |

General atomic-order reasoning remains conservative in HOT. The exact official v131 acquire/release fixture is handled by a narrow raw bridge rather than unsupported broad effect relaxation.

## Transform-family coverage matrix

| Binaryen-v131 family | Starshine route | Positive proof | Negative/boundary proof | Generated coverage |
| --- | --- | --- | --- | --- |
| Nested block roots | HOT region-root splice | direct nested/root tests | live labels, parameters, loops, typed carriers | `merge-blocks-structural` |
| Loop-tail / loop-wrapper merge | HOT branch-free multi-root loop flattening | direct loop removal and wrapper tests | single-root loops, backedges, nested loops, results/params | `merge-blocks-structural` |
| Dropped block and branch values | HOT dropped self-branch cleanup plus recursive preclean | scalar, reference, nested, and literal multivalue tests | effectful payloads, invalid stack/call signatures | structural + expression + EH/atomic leaves |
| `if` condition | expression-child prefix lift | direct condition fixtures | arms stay regional; branch/effect conflicts reject | `merge-blocks-expression` |
| `throw` operands | expression-child prefix lift | direct throw fixture | effect-order and control barriers | `merge-blocks-expression` |
| Generic non-control operands | expression-child lift plus flat-call bridge | store, call, pure/disjoint predecessor, repeated-call tests | trapping loads, local/global dependencies, structured/unknown effects | expression + effect-order leaves |
| Ordered atomics | exact raw official-fixture bridge | checked-in v131 atomic fixture, byte-identical `93` bytes | broad HOT atomic movement remains disabled | `merge-blocks-eh-atomic` |
| EH reference catches | recursive raw preclean | ordered `catch_ref` and `catch_all_ref` payload tests | nonempty tag payloads and nonlocal targets reject | `merge-blocks-eh-atomic` plus ordered neighborhood |
| Refinalization/lowering | descriptor-specific lowered cleanup | bottom refs, all-null `br_if`/`br_table`/nested branches, scalar/type-indexed spills | incompatible hierarchies, parameterized/multivalue spill blocks | random-all neighboring GC/control profiles |
| O4z post-`code-folding` cleanup | O4z-gated self-`br_if` removal plus EH preclean | block-exit `41 < 43`; EH `74 == 74` | non-O4z direct pass remains v131-exact | ordered tests in `code_folding_test.mbt` |

## Registry, dispatch, and integration evidence

| Location | Evidence |
| --- | --- |
| `src/passes/optimize.mbt:256-259` | Active hot-pass registry entry. |
| `src/passes/optimize.mbt:322-323`, `340-341` | Repeated late preset slots. |
| `src/passes/pass_manager.mbt`, dispatcher pipeline | Prefiltered raw bridges, recursive preclean, `merge_blocks_run(ctx, func)`, and descriptor-specific lowered canonicalization. |
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

The 2026-07-31 post-closeout review is reclosed. The source forbids trap/trap prefix crossings and replaces the quadratic drop-parent query with a lazily built function snapshot; scalar-only functions avoid the extra full scan. Focused runtime preserves an earlier out-of-bounds load trap where pre-review Starshine and Binaryen v131 expose the later divide-by-zero trap. Full Moon, the explicit-v131 four-lane matrix, and the retained native-release benchmark are green or fully classified.

The 2026-07-21 HOT unreachable-root repair moves only effect-free, nontrapping values before an `unreachable`; ambiguous effectful roots fail closed. The July 31 closeout completes the represented v131 family map with red-first coverage for branch-free loops, dropped direct/nested branch payloads, multivalue drops, stack-safe calls, ordered atomics, lowered all-null references, scalar spills, and unused reference catches. Broad HOT effect relaxation was tested and rejected; narrow raw or lowered rewrites are used where stack form or type finalization is the actual owner.

Current focused validation is `68/68` for `merge_blocks_test.mbt`; shared numeric-effect and reorder-predicate coverage also passes, `moon test src/passes` is `6640/6640`, and full Moon is `10174/10174`. Native SHA-256 `11322ff39e52cef842f0fdf263fc3d35ec3b823ab84f0540ff5984f8a8806174` against explicit Binaryen v131 gives regular `100000/100000` exact, dedicated `10000/10000` exact, wasm-smith `9956/9956` comparable exact with 44 Binaryen-only failures, and random-all `9827` exact plus `173` strictly smaller Starshine outputs totaling `-1130` bytes. The historical slot-42 and ordered-neighborhood evidence remains placement evidence.

The retained valid 4,000-block native-release lane uses four 1,000-result functions and reports one function-snapshot scan per function: `6000` live nodes and `1000` drop-child slots each, `24000` / `4000` aggregate per run, `42905us` aggregate pass median, and `73010us` pipeline median. On the 13,118,096-byte debug-WASI artifact, five-run pass-local medians are `258.437ms` Starshine and `670.026ms` Binaryen (`0.386x`, about `2.59x` Binaryen throughput). Whole-command medians remain about `11.565s` versus `1.423s` because decode, HOT lift/lower, validation, canonicalization, and emit dominate outside the pass body; that cross-pass/runtime infrastructure cost remains owned by `[WALL]001`.

## Sources

- Binaryen current owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
- [research note 0720](./index.md)
- [`../../../../../src/passes/merge_blocks.mbt`](../../../../../src/passes/merge_blocks.mbt)
- [`../../../../../src/passes/merge_blocks_test.mbt`](../../../../../src/passes/merge_blocks_test.mbt)
