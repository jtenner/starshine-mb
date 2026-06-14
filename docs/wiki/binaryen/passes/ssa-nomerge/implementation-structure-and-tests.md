---
kind: concept
status: supported
last_reviewed: 2026-06-13
sources:
  - ../../../raw/binaryen/2026-06-13-ssa-nomerge-version-130-source-refresh.md
  - ../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md
  - ../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md
  - ../../../raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md
  - ../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md
  - ../../../raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/ir/ssa_destroy.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/ssa_nomerge_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./merge-shapes-and-canonical-slots.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../ssa/implementation-structure-and-tests.md
---

# `ssa-nomerge` implementation structure and tests

## Why this page exists

`ssa-nomerge` already had a strong algorithm page and a Starshine strategy page, but it was missing the standard owner-file / proof-surface map used by many neighboring pass dossiers.

Use this page when you need to answer:

- which Binaryen files implement the upstream pass;
- which upstream tests prove no-merge behavior instead of full `--ssa` behavior;
- which local MoonBit files implement Starshine's current strategy;
- which local tests prove the active Starshine pass and which tests are only parity/signoff evidence.

## Upstream owner-file map

| Binaryen file | What it proves |
| --- | --- |
| `src/passes/SSAify.cpp` | Single implementation owner for both `ssa` and `ssa-nomerge`; the `allowMerges` flag selects full merge materialization versus no-merge behavior. It also owns fresh-local allocation, get/default rewrites, full-SSA phi helpers, prepends, and the narrow `ReFinalize` trigger. |
| `src/ir/local-graph.h` | Public helper contract used by `SSAify`: `getSets`, `getSetInfluences`, `computeSetInfluences`, `computeSSAIndexes`, and the `nullptr` entry/default-source convention. |
| `src/ir/LocalGraph.cpp` | The control-flow flower that computes reaching local sets and influenced gets across structured control. This is why upstream `ssa-nomerge` is whole-function flow reasoning, not a syntactic set/get peephole. |
| `src/ir/ReFinalize.cpp` | Type-repair dependency used after default reference replacement can sharpen expression types. It is not a second rewrite engine. |
| `src/passes/pass.cpp` | Public pass registration plus default-function-pipeline scheduling. It registers both `ssa` and `ssa-nomerge` and places `ssa-nomerge` early in optimize/shrink function optimization. |
| `src/passes/passes.h` | Factory declarations for `createSSAifyPass()` and `createSSAifyNoMergePass()`. |

Primary `version_129` URLs are captured in [`../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md`](../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md). A 2026-06-13 refresh against local `wasm-opt version 130 (version_130)` is captured in [`../../../raw/binaryen/2026-06-13-ssa-nomerge-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-13-ssa-nomerge-version-130-source-refresh.md): `SSAify.cpp`, `local-graph.h`, `LocalGraph.cpp`, the dedicated no-merge fixture/golden, shared `ssa.wast`, and `local-graph.cpp` gtests are byte-identical between `version_129` and `version_130`; `ReFinalize.cpp`, `pass.cpp`, and `passes.h` have no no-merge behavior-contract drift.

## Upstream algorithm ownership in one pass through the file

`SSAify.cpp` runs each function in this order:

1. build `LocalGraph`;
2. compute set influences;
3. compute already-SSA indexes;
4. create fresh indexes for eligible sets;
5. compute get rewrites and, only for full `ssa`, phi-like merge rewrites;
6. add any function-entry prepends;
7. run `ReFinalize` only if default reference replacement requires type repair.

For `ssa-nomerge`, the decisive rule is still per-set: if any get influenced by a set has multiple reaching sets, that set is left on the canonical local slot. Full merge-local creation lives next to the no-merge code, but it is selected only by the full `ssa` pass.

## Upstream test map

| Test surface | Why it matters |
| --- | --- |
| `test/passes/ssa-nomerge_enable-simd.wast` | Dedicated no-merge input fixture. It is the strongest compact upstream example set for straight-line untangling, default materialization, SIMD defaults, and merge bailouts. |
| `test/passes/ssa-nomerge_enable-simd.txt` | Golden output for the dedicated no-merge fixture. Use it to distinguish no-merge canonical-slot behavior from full `ssa` merge-local behavior. |
| `test/lit/passes/ssa.wast` | Shared full-SSA helper surface. It is useful for understanding default/ref/tuple helper behavior, but do not treat full-`ssa` merge materialization there as `ssa-nomerge` behavior. |
| `test/gtest/local-graph.cpp` | Helper-level proof surface for LocalGraph flow assumptions: reaching sets, obstacles, structured control, unreachable-code looseness, and multi-set cases. |

## SSANM fixture baseline matrix

`[SSANM-001b]` converts the refreshed Binaryen `version_130` source/test surface into slice owners for the LocalGraph no-merge rewrite. Evidence reviewed for this matrix: local `wasm-opt --version` reports `wasm-opt version 130 (version_130)`; `ssa-nomerge_enable-simd.wast` still has only `$basics`, `$if`, `$if2`, `$nomerge`, and `$simd-zero`; `test/gtest/local-graph.cpp` still has the eight `Obstacle*` helper tests; and `SSAify.cpp` still makes `createSSAifyNoMergePass()` return `SSAify(false)` with the `!graph.isSSA(set->index) && (allowMerges || !hasMerges(set, graph))` fresh-local gate.

| Fixture / behavior family | Binaryen source or test anchor | Current Starshine proof surface | SSANM owner |
| --- | --- | --- | --- |
| Planner-only LocalGraph decision table: entry sources, explicit write sources, single-source gets, merge gets, already-SSA locals, and per-write freshening eligibility | `SSAify.cpp` `createNewIndexes`, `hasMerges`, `computeGetsAndPhis`; `local-graph.h` / `LocalGraph.cpp`; `local-graph.cpp` `ObstacleBasics`, `ObstacleMultiGet`, `ObstacleMultiSet`, `ObstacleMultiSetIndexes` | `src/ir/local_graph_test.mbt` covers param/default entries, single-source/merge gets, write facts, already-SSA classification, and no-merge eligibility. `src/passes/ssa_nomerge_test.mbt` now has `[SSANM-002b]` shadow helpers that compare plan counts against current observable pass output for reduced already-SSA, overwritten-tee, body-default, and branch-local already-SSA fixtures. | `[SSANM-002a]` builds the rewrite planner. `[SSANM-002b]` shadows it against current behavior; `[SSANM-003a]` consumes it for straight-line `local.set`; `[SSANM-003b]` consumes it for straight-line `local.tee`; `[SSANM-004a]` consumes planned default gets in straight-line and narrow structured default-read subsets. Later mutation slices still own merge preservation, broader structured control, and boundaries. |
| Straight-line `local.set` freshening, repeated gets after one set, param overwrite, already-SSA locals, and no-read/dead writes | `ssa-nomerge_enable-simd.wast` `$basics`; `$nomerge` early untangle calls; `local-graph.cpp` `ObstacleMultiSet` | Existing `ssa_nomerge_test.mbt` straight-line/canonical-local tests plus `local_graph_test.mbt` overwrite, no-read/dead-write, and already-SSA tests. `[SSANM-003a]` adds public-pipeline trace/output tests proving the raw straight-line `local.set` path now consumes the LocalGraph plan for live parameter overwrite canonical preservation and overwritten body-local freshening/retargeting. | `[SSANM-003a]` is complete for straight-line `local.set`; structured control remains in later slices. |
| `local.tee` write influence and stack-result preservation | Binaryen `LocalGraph` treats `local.tee` as a set; `local-graph.cpp` `ObstacleStructSet` uses a tee under a GC child expression. The dedicated no-merge WAST has no standalone tee golden. | `local_graph_test.mbt` has tee-defined already-SSA and write-kind coverage; `ssa_nomerge_test.mbt` has local.tee artifact/regression coverage; GenValid labels from `[SSANM-011d]` floor tee freshen, merge-feeding, child-expression, and dead-tee shapes. `[SSANM-003b]` adds public-pipeline trace/output tests proving the raw straight-line path consumes the LocalGraph plan for overwritten root `local.tee`, preserves the stack result, retargets the final get, and handles folded/effectful WAT tee operands as one call plus one retargeted tee. | `[SSANM-003b]` is complete for straight-line `local.tee` where WAT/HOT lowering presents flat raw tee instructions. Structured-control tee mutation and boundary classification remain in `[SSANM-006a]` / `[SSANM-007*]`. |
| Body-local default-entry materialization for numeric, SIMD, nullable/exact refs, and parent type repair | `ssa-nomerge_enable-simd.wast` `$basics` default scalar gets and `$simd-zero`; shared `ssa.wast` `refine-to-null` and `null-tuple`; `SSAify.cpp` default rewrite plus `ReFinalize` trigger | `local_graph_test.mbt` defaultability facts; `ssa_nomerge_test.mbt` default numeric, branchy default, dropped-unreachable, and default-ref repair guards. `[SSANM-004a]` adds public-pipeline LocalGraph-planned coverage for numeric and `v128` defaults in functions that also have writes, branchy structured default reads, exact nullable ref defaults under parent result blocks, and parameter-entry canonical reads. `[SSANM-004b]` proves no-local-write defaults now use the same LocalGraph plan and that dropped-unreachable-debris cleanup remains a separate no-write fast path. | `[SSANM-004a]` is complete for straight-line defaults and a narrow normal structured-control subset where a body-local default read has no explicit writes and HOT LocalGraph lifting is supported. `[SSANM-004b]` is complete: the duplicated legacy raw default-only rewriter is removed, while the no-local-write debris cleanup fast path remains. Starshine has no separate Binaryen tuple local type, so tuple-only upstream examples should remain documented as full-SSA/shared-helper context unless a local representation appears. |
| One-arm default and parameter-entry merges that must stay canonical | `ssa-nomerge_enable-simd.wast` `$if` missing-else body-local and param cases; `local-graph.cpp` structured merge influence tests | `local_graph_test.mbt` default-entry and param-entry merge-source tests; GenValid labels from `[SSANM-011c]` cover one-arm default and param merges. | `[SSANM-005a]` preserves canonical one-arm default/param merges and proves no fresh merge local/predecessor copy is introduced. |
| Both-arm, loop-carried, and other multi-source merge gets that must stay canonical | `ssa-nomerge_enable-simd.wast` `$if`, `$if2`, and the merge part of `$nomerge`; `local-graph.cpp` `ObstacleMultiSetIf` plus LocalGraph structured flow | `local_graph_test.mbt` diamond both-arm and loop-carried source tests; `ssa_nomerge_test.mbt` has branch/loop/typed-loop canonical-local guards. | `[SSANM-005b]` owns both-arm, loop/backedge, `br` / `br_if` / `br_table` merge-read preservation. |
| Mixed per-write policy for one original local: early freshenable writes, later merge-feeding canonical writes, and freshenable writes after the merge | `ssa-nomerge_enable-simd.wast` `$nomerge` explicitly marks writes `1` / `2` as untangle, write `3` as merge-feeding, and write `5` as freshenable again before writes `6` / `7` merge | `local_graph_test.mbt` `marks only non-merge-feeding writes freshenable per original local`; GenValid `[SSANM-011c]` `ssa-mixed-fresh-canonical-writes` floor. | `[SSANM-005c]` implements the per-write rule inside broader merge regions. |
| Normal structured control mutation beyond simple `if`: `block`, `loop`, `br`, `br_if`, and `br_table` | Source contract comes from LocalGraph whole-function flow and `SSAify.cpp` using influenced gets rather than syntactic local pairs; dedicated no-merge WAST is mostly `if` plus calls, not exhaustive branch opcode coverage | `ssa_nomerge_test.mbt` has extensive current raw structured, branch, loop, typed-loop, and `br_table` guards; GenValid `[SSANM-011e]` floors branch-operand and nested-loop-target boundaries. | `[SSANM-006a]` drives ordinary normal-flow structured mutation from the LocalGraph plan and deletes raw helper families where they become redundant. |
| No-merge must not externalize overlay phis through predecessor copies | `SSAify.cpp` returns from merge-local rewriting when `allowMerges` is false; full merge prepends/copies are sibling full-`ssa` behavior, not no-merge | Current `src/ir/ssa_destroy.mbt` and the HOT `ssa-nomerge` path still use predecessor-copy SSA destruction in some families; docs already flag this as the main local strategy mismatch. | `[SSANM-006b]` retires predecessor-copy behavior from no-merge paths and moves any remaining full-`ssa` helper work out of SSANM. |
| Exceptional-edge boundaries: `try`, `try_table`, throws, catches, `delegate`, and no-throw subsets | No dedicated `version_130` no-merge WAST fixture covers EH. The local 2026-06-09 audit is the current source-backed safety note for Starshine's normal-flow-only LocalGraph boundary. | `ssa_nomerge_test.mbt` includes exceptional-flow fail-closed and no-throw `try_table` tests; GenValid `[SSANM-011e]` floors `ssa-exceptional-fail-closed-shape`. | `[SSANM-007a]` keeps EH boundaries explicit, adds source-backed positive tests only for no-exception normal-flow subsets, and documents tooling debt versus intentional no-mutation boundaries. |
| Typed-control and loop-param/result ABI shapes | Dedicated Binaryen no-merge WAST does not isolate typed loop params/results or branch operand ABI rewrites; those shapes are Starshine-local lowering boundaries over the upstream LocalGraph local-source policy. | `ssa_nomerge_test.mbt` has typed-loop, multi-param/result, `br_table`, and `br_on_*` coverage; GenValid `[SSANM-011e]` floors typed-loop, branch-operand, and nested-loop boundaries. | `[SSANM-007b]` classifies each typed-control shape as LocalGraph local rewrite, typed-control lowering work, or deliberate fail-closed boundary. |

The explicit coverage gap after this matrix is not a missing upstream source refresh: the `version_130` owner/test surfaces did not drift. The remaining gaps are implementation planning gaps where Starshine must consume LocalGraph facts instead of the current HOT/raw heuristics for merge and broader structured-control families, plus local representation boundaries (structured `local.tee`, EH, typed control, and Binaryen tuple locals) that need either focused micro-replays or documented fail-closed evidence in their owning slices.

## Starshine implementation map

Starshine implements an active pass with the same public goal, but the owner split is very different from Binaryen.

| Local file | Current role |
| --- | --- |
| `src/passes/ssa_nomerge.mbt:2` | `ssa_nomerge_descriptor()` declares the active HOT pass name, required analyses, and invalidation contract. |
| `src/passes/ssa_nomerge.mbt:15` | Summary/help text; currently says the pass untangles locals and lowers overlay phis through predecessor copies. |
| `src/passes/ssa_nomerge.mbt:20` | `[SSANM-002a]` analysis-only `SsaNoMergeRewritePlan`: consumes `HotLocalGraph` to classify freshen/keep write decisions and retarget/default/keep get decisions without mutating the function. |
| `src/passes/ssa_nomerge.mbt:151` | Cheap local-write gate. |
| `src/passes/ssa_nomerge.mbt:34` | Rewrite-needed check over overlay phis and concrete local write defs. |
| `src/passes/ssa_nomerge.mbt:49` | Main HOT pass wrapper; requires CFG and local SSA, then delegates to `@ir.ssa_destroy_into_hot(...)`. |
| `src/ir/ssa_destroy.mbt:33` | `HotSsaDestroyPolicy`; current policy surface exposes `ReusePhiLocals`. |
| `src/ir/ssa_destroy.mbt:157` | Builds explicit predecessor-copy HOT nodes. |
| `src/ir/ssa_destroy.mbt:455` | Inserts predecessor copies at predecessor-block boundaries. |
| `src/ir/ssa_destroy.mbt:527` | `ssa_destroy_into_hot(...)`, the real lifted HOT SSA-destruction bridge used by the pass. |
| `src/passes/pass_manager.mbt:5768` | Raw default/local-read materialization helper. |
| `src/passes/pass_manager.mbt:5915` | Raw initialized-local seed logic. |
| `src/passes/pass_manager.mbt:6788` | Structured raw `ssa-nomerge` rewrite path. |
| `src/passes/pass_manager.mbt:6826` | Raw LocalGraph no-merge helpers. `[SSANM-003a]` made the straight-line `local.set` subset build and consume `SsaNoMergeRewritePlan`; `[SSANM-003b]` extended the same planned path to `local.tee` and removed the old straight-line alias heuristic; `[SSANM-004a]` uses the plan's `MaterializeDefault` get decisions for straight-line defaults and a narrow structured default-read subset before legacy structured rewriting; `[SSANM-004b]` routes no-local-write default reads through the same planned materializer and removes the duplicated raw default-only recursion. |
| `src/passes/pass_manager.mbt:6937` | Raw dispatcher choosing skip, structured, and straight-line paths. |
| `src/passes/pass_manager.mbt:7865` | Raw pass-manager hook for the `ssa-nomerge` special case. |
| `src/passes/pass_manager.mbt:8727` | Lifted HOT dispatch case for `ssa-nomerge`. |
| `src/passes/optimize.mbt:157` | Registry entry for the active pass name. |
| `src/passes/optimize.mbt:267` and `src/passes/optimize.mbt:279` | Preset queue placement in optimize and shrink. |
| `src/passes/optimize.mbt:405` and `src/passes/optimize.mbt:420` | Public preset-pass arrays. |

The important local-vs-upstream lesson is the same as in [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md): Starshine can lower overlay phis through explicit predecessor copies, while Binaryen `ssa-nomerge` deliberately avoids merge materialization.

## Starshine test map

| Local test surface | What it proves |
| --- | --- |
| `src/passes/ssa_nomerge_test.mbt:235` | `[SSANM-002a]` planner fixtures cover already-SSA straight-line locals, overwritten freshenable writes, parameter-entry and body-default reads, one-arm branch merges, loop-carried merges, no-read dead `local.set`, and dead `local.tee`. `[SSANM-002b]` adjacent test-only shadow helpers summarize planner freshen/retarget/default/keep counts and current output body-local/local-get shape for reduced fixtures, without changing pass mutation. |
| `src/passes/ssa_nomerge_test.mbt:48` | Straight-line local traffic can stay canonical; `[SSANM-003a]` public-pipeline trace/output fixtures prove the raw `local.set` subset consumes the LocalGraph plan for live parameter overwrites and overwritten body-local writes; `[SSANM-003b]` adds LocalGraph-planned `local.tee` freshening, stack-result preservation, final-get retargeting, and folded effectful tee operand coverage. |
| `src/passes/ssa_nomerge_test.mbt:68` | Latest straight-line alias stays live. |
| `src/passes/ssa_nomerge_test.mbt:99` and `:119` | Dead param set/tee rewrites spill through fresh locals. |
| `src/passes/ssa_nomerge_test.mbt:140` | Structured param writes can remain canonical. |
| `src/passes/ssa_nomerge_test.mbt:189` | Branch joins lower through explicit predecessor copies. |
| `src/passes/ssa_nomerge_test.mbt:243` | Loop-carried locals lower before the backedge. |
| `src/passes/ssa_nomerge_test.mbt:304` | Root loop headers avoid synthetic entry copies. |
| `src/passes/ssa_nomerge_test.mbt:358`, `:405`, and `:469` | Raw structured early-return and block-target branch families preserve canonical locals. |
| `src/passes/ssa_nomerge_test.mbt:526` and `:596` | Result-typed `if` merge families remain valid in the raw path. |
| `src/passes/ssa_nomerge_test.mbt:642` and `:685` | Reduced `Func 523` / unreachable carrier followups remain covered. |
| `src/cmd/cmd_wbtest.mbt:1915` | CLI adapter applies `--ssa-nomerge` to wasm inputs. |
| `src/cmd/cmd_wbtest.mbt:2394` | Debug-artifact replay validates under `--ssa-nomerge`. |
| `src/cmd/cmd_wbtest.mbt:2434` | Extracted `Func 523` replay avoids the older writeback type-mismatch skip. |

## Validation guidance

For upstream comparison work:

- use `wasm-opt --ssa-nomerge --enable-simd -S` on reduced local-traffic fixtures;
- compare against the dedicated no-merge golden output before consulting full `--ssa` fixtures;
- keep merge-local or incoming-`tee` output classified as full `ssa`, not `ssa-nomerge`.

For Starshine signoff:

- run focused `src/passes/ssa_nomerge_test.mbt` tests when changing local rewrite logic;
- keep CLI debug-artifact replay in the loop because local writeback/validation guards are part of the actual pass boundary;
- use [`./parity.md`](./parity.md) for the current fuzz/debug-artifact evidence level;
- do not claim exact raw-byte parity unless a fresh artifact skip census and canonical wasm comparison support it.

## Caveats

- This page is an implementation map, not a new behavior contract.
- The upstream source contract remains the reviewed `version_129` dossier, now refreshed against local Binaryen `version_130` for the pass-surface files listed above.
- The `version_130` refresh does not claim global Binaryen optimizer equivalence; it only says the `ssa-nomerge` owner, LocalGraph, registration/scheduling, and fixture surfaces did not drift in a way that changes SSANM implementation planning.
- Local line numbers are current as of 2026-05-01 and should be refreshed if future code motion touches the cited files.

## Sources

- [`../../../raw/binaryen/2026-06-13-ssa-nomerge-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-13-ssa-nomerge-version-130-source-refresh.md)
- [`../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md`](../../../raw/binaryen/2026-05-01-ssa-nomerge-implementation-primary-sources.md)
- [`../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md`](../../../raw/research/0431-2026-05-01-ssa-nomerge-implementation-structure.md)
- [`../../../raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md`](../../../raw/binaryen/2026-04-21-ssa-nomerge-primary-sources.md)
- [`../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md`](../../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md)
- [`../../../raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md`](../../../raw/research/0240-2026-04-21-ssa-nomerge-starshine-strategy-followup.md)
- [`../../../../../src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt)
- [`../../../../../src/ir/ssa_destroy.mbt`](../../../../../src/ir/ssa_destroy.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/ssa_nomerge_test.mbt`](../../../../../src/passes/ssa_nomerge_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
