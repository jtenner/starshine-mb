---
kind: concept
status: supported
last_reviewed: 2026-06-14
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
| One-arm default and parameter-entry merges that must stay canonical | `ssa-nomerge_enable-simd.wast` `$if` missing-else body-local and param cases; `local-graph.cpp` structured merge influence tests | `local_graph_test.mbt` default-entry and param-entry merge-source tests; GenValid labels from `[SSANM-011c]` cover one-arm default and param merges. `[SSANM-005a]` adds public-pipeline tests proving missing-else body-local/default and parameter-entry merge gets stay on the canonical slot with no fresh merge local or predecessor copy, and trace `structured-one-arm-merge-localgraph-plan`. | `[SSANM-005a]` is complete for simple missing-else one-arm entry/default merges. Both-arm, loop/backedge, branch-opcode, and mixed per-write follow-ups are now classified under `[SSANM-005b]` / `[SSANM-005c]`; remaining expansion is broader structured-control / typed-control work. |
| Both-arm, loop-carried, and other multi-source merge gets that must stay canonical | `ssa-nomerge_enable-simd.wast` `$if`, `$if2`, and the merge part of `$nomerge`; `local-graph.cpp` `ObstacleMultiSetIf` plus LocalGraph structured flow | `local_graph_test.mbt` diamond both-arm and loop-carried source tests; `ssa_nomerge_test.mbt` has branch/loop/typed-loop canonical-local guards. `[SSANM-005b1]` adds public-pipeline tests proving simple both-arm `if` writes and a block/`br_if` early-exit merge stay on the original body local with no temp or predecessor-copy local. `[SSANM-005b2]` updates the direct void-loop `br_if 0` backedge fixture to prove LocalGraph canonical preservation instead of legacy scratch/proxy rewriting, while existing typed-loop/value-backedge tests keep their scratch-lowering boundaries. `[SSANM-005b3]` adds fail-closed public-pipeline tests for plain `br` and `br_table` multi-source merge boundaries and keeps full-`ssa` merge materialization documented as sibling `ssa` work. | `[SSANM-005b1]` is complete for simple normal structured-control both-arm and block/`br_if` multi-source merge preservation. `[SSANM-005b2]` is complete for simple void-loop direct `br_if 0` backedge canonical preservation. `[SSANM-005b3]` is complete as a classification slice: plain `br` and `br_table` multi-source merge regions validate and preserve their branch opcodes but do not claim the canonical-only LocalGraph path yet; broader branch/table mutation remains in `[SSANM-006a3]`, and typed-loop/branch-operand ABI shapes remain in `[SSANM-007b*]`. |
| Mixed per-write policy for one original local: early freshenable writes, later merge-feeding canonical writes, and freshenable writes after the merge | `ssa-nomerge_enable-simd.wast` `$nomerge` explicitly marks writes `1` / `2` as untangle, write `3` as merge-feeding, and write `5` as freshenable again before writes `6` / `7` merge | `local_graph_test.mbt` `marks only non-merge-feeding writes freshenable per original local`; GenValid `[SSANM-011c]` `ssa-mixed-fresh-canonical-writes` floor. `[SSANM-005c1]` adds focused planner coverage for one body local with two freshenable writes, two canonical merge-feeding writes, two retargeted gets, and one canonical merge get. `[SSANM-005c2]` adds public-pipeline coverage for a narrow normal `if`/`local.set` family that freshens only the planned non-merge writes and keeps the merge region canonical. `[SSANM-005c3a]` adds the matching narrow `local.tee` coverage and keeps tee admission intentionally small so larger artifact scratch/copy families stay on legacy helpers. `[SSANM-005c3b]` classifies `br_if` early exits as supported by this same normal-control path while plain `br` and `br_table` stay fail-closed. `[SSANM-005c3c]` classifies nested normal `block` / `if` as supported and loop-containing mixed regions as fail-closed. | `[SSANM-005c1]`, `[SSANM-005c2]`, and `[SSANM-005c3a]` through `[SSANM-005c3c]` are complete for the narrow mixed normal-control policy: `local.set`, small `local.tee`, `br_if` early exits, and nested normal `block` / `if` can use `structured-mixed-localgraph-plan`; plain `br`, `br_table`, loops, EH, typed control, and branch operands remain in `[SSANM-006a]` and `[SSANM-007*]` after `[SSANM-005b3]` classified the branch/table multi-source boundary. |
| Normal structured control mutation beyond simple `if`: `block`, `loop`, `br`, `br_if`, and `br_table` | Source contract comes from LocalGraph whole-function flow and `SSAify.cpp` using influenced gets rather than syntactic local pairs; dedicated no-merge WAST is mostly `if` plus calls, not exhaustive branch opcode coverage | `ssa_nomerge_test.mbt` has extensive current raw structured, branch, loop, typed-loop, and `br_table` guards; GenValid `[SSANM-011e]` floors branch-operand and nested-loop-target boundaries. `[SSANM-006a1]` adds value-carrying `br` / `br_table` fail-closed fixtures and maps current supported normal-flow reasons to raw helper ownership before mutation expands. | `[SSANM-006a1]` is complete as classification: supported LocalGraph reasons are narrow missing-else one-arm merges, simple both-arm/block-`br_if` multi-source merges, simple void-loop direct `br_if 0` backedge merges, narrow mixed `local.set` / small `local.tee` / `br_if` early-exit / nested normal `block` / `if` regions, and structured default materialization. Value-carrying `br` / `br_table`, plain `br`, table exits, typed branch operands, EH, and broader loop/nested-target families stay fail-closed for `[SSANM-006a2]`, `[SSANM-006a3a]` through `[SSANM-006a3d]`, and `[SSANM-007*]`. |
| No-merge must not externalize overlay phis through predecessor copies | `SSAify.cpp` returns from merge-local rewriting when `allowMerges` is false; full merge prepends/copies are sibling full-`ssa` behavior, not no-merge | Current `src/ir/ssa_destroy.mbt` and the HOT `ssa-nomerge` path still use predecessor-copy SSA destruction in some families; docs already flag this as the main local strategy mismatch. `[SSANM-007c]` moved full `ssa` merge-local follow-up work into sibling `[O4Z-AUDIT-SSA-FULL]` / `[SSA-FULL-*]` slices. | `[SSANM-006b]` is now child-sliced: `[SSANM-006b1]` inventories remaining copy-producing no-merge paths, `[SSANM-006b2a]` censuses fallback survivors, `[SSANM-006b2b]` locks completed straight-line/default routes, `[SSANM-006b2d]` classifies boundary scratch helpers, `[SSANM-006b2c]` remains open for ordinary structured rerouting, and `[SSANM-006b3]` retires or narrows legacy helper/summaries. Full `ssa` merge materialization is no longer `SSANM` work. |
| Exceptional-edge boundaries: `try`, `try_table`, throws, catches, `delegate`, and no-throw subsets | No dedicated `version_130` no-merge WAST fixture covers EH. The local 2026-06-09 audit is the current source-backed safety note for Starshine's normal-flow-only LocalGraph boundary. | `ssa_nomerge_test.mbt` includes exceptional-flow fail-closed and no-throw `try_table` tests; GenValid `[SSANM-011e]` floors `ssa-exceptional-fail-closed-shape`. | `[SSANM-007a]` is now child-sliced: `[SSANM-007a1]` refreshes EH source and local boundary inventory, `[SSANM-007a2]` locks throwing fail-closed behavior, and `[SSANM-007a3]` classifies no-throw `try_table` / EH-body normal-flow subsets. |
| Typed-control and loop-param/result ABI shapes | Dedicated Binaryen no-merge WAST does not isolate typed loop params/results or branch operand ABI rewrites; those shapes are Starshine-local lowering boundaries over the upstream LocalGraph local-source policy. | `ssa_nomerge_test.mbt` has typed-loop, multi-param/result, `br_table`, and `br_on_*` coverage; GenValid `[SSANM-011e]` floors typed-loop, branch-operand, and nested-loop boundaries. | `[SSANM-007b]` is now child-sliced: `[SSANM-007b1]` refreshes typed-control source and fixture inventory, `[SSANM-007b2]` locks typed loop param/result ABI boundaries, and `[SSANM-007b3]` classifies typed branch operands plus cast/null branch exits. |

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
| `src/passes/pass_manager.mbt:6826` | Raw LocalGraph no-merge helpers. `[SSANM-003a]` made the straight-line `local.set` subset build and consume `SsaNoMergeRewritePlan`; `[SSANM-003b]` extended the same planned path to `local.tee` and removed the old straight-line alias heuristic; `[SSANM-004a]` uses the plan's `MaterializeDefault` get decisions for straight-line defaults and a narrow structured default-read subset before legacy structured rewriting; `[SSANM-004b]` routes no-local-write default reads through the same planned materializer and removes the duplicated raw default-only recursion; `[SSANM-005a]` recognizes simple missing-else one-arm entry/default merge plans as canonical-only and skips legacy structured rewriting with a dedicated trace reason; `[SSANM-005b1]` recognizes simple canonical-only multi-source merge plans for both-arm `if` and block/`br_if` shapes and skips legacy structured rewriting with `structured-multisource-merge-localgraph-plan`; `[SSANM-005b2]` recognizes simple void-loop direct `br_if 0` backedge canonical-only plans before the legacy loop-carried HOT defer and skips mutation with `structured-loop-backedge-merge-localgraph-plan`; `[SSANM-005b3]` keeps plain `br` and `br_table` multi-source merge regions off those planned LocalGraph reasons until branch/table helpers are narrowed; `[SSANM-005c2]` recognizes narrow mixed fresh/canonical normal `if`/`local.set` plans and recursively applies planned freshening/retargeting with `structured-mixed-localgraph-plan` while preserving canonical merge writes and reads; `[SSANM-005c3a]` lets the same structured mixed path handle small `local.tee` write sets while retaining larger tee-heavy artifact families on legacy scratch/copy helpers; `[SSANM-006a1]` records the current boundary map for these helpers, including fail-closed value `br` / `br_table` operands that must stay out of planned LocalGraph reasons until branch-operand helpers are narrowed; `[SSANM-006a2a]` adds the stricter `structured-localgraph-plan` path for ordinary normal `block` / `if` `local.set` freshening when the plan has single-source freshened writes and retargeted gets, while rejecting branches, returns, loops, EH, typed-control, `local.tee`, and trap boundaries; `[SSANM-006a2b]` adds explicit merge-adjacent ordinary `local.set` coverage through the existing `structured-mixed-localgraph-plan`; `[SSANM-006a2c]` narrows the remaining legacy `structured-local-writes` / `structured-local-writes-mutated` ownership to boundary-helper families rather than ordinary no-merge work. |
| `src/passes/pass_manager.mbt:6937` | Raw dispatcher choosing skip, structured, and straight-line paths. |
| `src/passes/pass_manager.mbt:7865` | Raw pass-manager hook for the `ssa-nomerge` special case. |
| `src/passes/pass_manager.mbt:8727` | Lifted HOT dispatch case for `ssa-nomerge`. |
| `src/passes/optimize.mbt:157` | Registry entry for the active pass name. |
| `src/passes/optimize.mbt:267` and `src/passes/optimize.mbt:279` | Preset queue placement in optimize and shrink. |
| `src/passes/optimize.mbt:405` and `src/passes/optimize.mbt:420` | Public preset-pass arrays. |

The important local-vs-upstream lesson is the same as in [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md): Starshine can lower overlay phis through explicit predecessor copies, while Binaryen `ssa-nomerge` deliberately avoids merge materialization.

## `[SSANM-006a1]` normal structured-control ownership map

`[SSANM-006a1]` is a classification slice, not a mutation expansion. The current source/test review maps normal structured-control families this way:

| Family | Current owner / decision | Evidence |
| --- | --- | --- |
| Structured default reads with legal body-local defaults | Keep planned LocalGraph materializer; it can recurse through normal `block` / `loop` / `if` but still rejects `try_table`, `br_table`, `br_on_*`, and cast branches. | `run_hot_pipeline_raw_ssa_nomerge_default_materialize_supported_control(...)`; `[SSANM-004a]` / `[SSANM-004b]` tests. |
| Missing-else one-arm entry/default merges | Keep canonical-only LocalGraph reason `structured-one-arm-merge-localgraph-plan`; no mutation and no predecessor-copy merge local. | `[SSANM-005a]` tests. |
| Both-arm `if` and block/`br_if` multi-source merges | Keep canonical-only LocalGraph reason `structured-multisource-merge-localgraph-plan`; broader plain `br` / table branches stay excluded. | `[SSANM-005b1]` and `[SSANM-005b3]` tests. |
| Simple void-loop direct `br_if 0` backedge merge | Keep canonical-only LocalGraph reason `structured-loop-backedge-merge-localgraph-plan`; typed loops and nested/control-value backedges stay on typed-control helpers. | `[SSANM-005b2]` tests plus existing typed-loop guards. |
| Narrow mixed normal `local.set`, small `local.tee`, `br_if`, and nested normal `block` / `if` | Keep `structured-mixed-localgraph-plan`; it applies planned freshening/retargeting only in already-classified normal-flow shapes. | `[SSANM-005c2]` through `[SSANM-005c3c]` tests. |
| Value-carrying `br` and `br_table` operands | Fail closed from planned LocalGraph reasons; owned by branch-operand / typed-control narrowing before mutation can broaden. | `[SSANM-006a1]` tests `ssa-nomerge keeps value br operands off LocalGraph path` and `ssa-nomerge keeps value br_table operands off LocalGraph path`. |
| Plain `br`, `br_table`, nested branch targets, EH, `br_on_*`, and cast branches | Keep out of ordinary planned structured mutation until `[SSANM-006a3a]` through `[SSANM-006a3d]`, `[SSANM-007a*]`, or `[SSANM-007b*]` proves a narrower helper safe. | `[SSANM-005b3]`, `[SSANM-005c3b]`, `[SSANM-006a3]` child backlog, `[SSANM-007a*]`, and `[SSANM-007b*]` backlog/docs. |

## `[SSANM-006a2c]` legacy structured local-write helper ownership

`[SSANM-006a2c]` is a source/test ownership narrowing pass, not a behavior change. After the LocalGraph-planned paths from `[SSANM-003a]` through `[SSANM-006a2b]`, the generic legacy `structured-local-writes` / `structured-local-writes-mutated` trace reasons should no longer be read as ordinary Binaryen-style no-merge work for straight-line, default, simple canonical-merge, mixed normal-control, or ordinary block/if `local.set` traffic.

| Legacy family | Current meaning after planned rewrites | Owner / next action |
| --- | --- | --- |
| Ordinary single-source `local.set` / `local.tee`, default-entry reads, simple canonical merges, mixed normal `block` / `if` / `br_if`, and merge-adjacent ordinary `local.set`s | Should use `straight-line-local-writes-localgraph-plan`, `default-local-reads-localgraph-plan`, `structured-default-local-reads-localgraph-plan`, `structured-one-arm-merge-localgraph-plan`, `structured-multisource-merge-localgraph-plan`, `structured-loop-backedge-merge-localgraph-plan`, `structured-mixed-localgraph-plan`, or `structured-localgraph-plan`; these are no longer legacy-helper ownership. | Completed `[SSANM-003a]` through `[SSANM-006a2b]`; regressions should add focused public-pipeline fixtures before broadening legacy helpers. |
| Plain `br`, `br_if` outside the already-supported mixed/loop-backedge subsets, `br_table`, nested branch targets, and value-carrying branch operands | Still boundary territory because branch-alias copies, table scratch/proxy lowering, and branch-operand ABI repair can be needed. | `[SSANM-006a3a]` through `[SSANM-006a3d]` decide which branch/table families can move to planned LocalGraph mutation and which remain explicit helper/fail-closed owners. |
| Typed loop params/results, value-producing blocks/loops, `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` | Still typed-control lowering territory, not ordinary local-source no-merge freshening. Scratch/proxy locals here are ABI repairs rather than predecessor-copy merge locals. | `[SSANM-007b1]` through `[SSANM-007b3]`. |
| `try_table`, throwing/catching/delegating EH containers, and no-throw EH-body candidates | Remain exceptional-edge boundary work because the current LocalGraph no-merge path is normal-flow-only. | `[SSANM-007a1]` through `[SSANM-007a3]`. |
| Large structured functions hitting `large-structured-local-writes ...` | Still guarded for artifact/performance classification, not evidence that ordinary planned LocalGraph policy is unavailable. | `[SSANM-008a]` through `[SSANM-008d]`. |
| `structured-local-writes-mutated` for branch-table merge-copy shapes | Still a branch/table-specific mutation summary for raw helper output; do not classify it as Binaryen-style no-merge predecessor-copy behavior without inspecting the shape. | `[SSANM-006a3c]` / `[SSANM-007b3]`, plus artifact replay slices when the shape comes from debug-WASI. |

Trace summary implication: keeping the string `structured-local-writes` is acceptable while the boundary helpers remain, but new ordinary no-merge coverage should prefer a named LocalGraph reason. If a future test sees `structured-local-writes` for one of the completed ordinary families above, treat it as a rerouting regression or a missing narrow owner.

## `[SSANM-006a3a]` ordinary branch-exit helper ownership inventory

`[SSANM-006a3a]` is a source/test inventory before branch mutation expands. It does not decide the final admission policy for every branch family; it identifies who owns each current helper so later slices can add red-first fixtures without accidentally routing typed-control, EH, or table scratch lowerings through the ordinary LocalGraph local-source path.

| Branch-exit family | Current helper / reason owner | Current proof surface | Next slice |
| --- | --- | --- | --- |
| Mixed normal `br_if` early exits with no branch value | `run_hot_pipeline_raw_ssa_nomerge_mixed_structured_supported_control(...)` permits `br_if` while still rejecting plain `br`, `br_table`, loops, EH, and typed branch opcodes; successful mutations trace `structured-mixed-localgraph-plan`. | `ssa-nomerge LocalGraph freshens mixed br_if early-exit writes` proves planned non-merge writes freshen and canonical merge traffic stays canonical. | Completed under `[SSANM-005c3b]`; keep as supported unless `[SSANM-006a3b]` finds a narrower branch-alias regression. |
| Simple void-loop direct `br_if 0` backedge merges | `run_hot_pipeline_raw_ssa_nomerge_loop_backedge_merge_supported_control(...)` recognizes only direct void-loop `br_if 0` backedges and returns unchanged with `structured-loop-backedge-merge-localgraph-plan` when the plan is canonical-only. | `[SSANM-005b2]` loop/backedge fixture; existing typed-loop/value-backedge guards stay separate. | Completed for the simple void-loop subset; broader nested/typed loops stay in `[SSANM-006a3d]` / `[SSANM-007b2]`. |
| Ordinary `block` / `if` single-source `local.set` regions that contain `br` or `br_if` | `run_hot_pipeline_raw_ssa_nomerge_ordinary_set_supported_control(...)` rejects both `br` and `br_if`; if the mixed/canonical-only gates do not take the function, the legacy structured raw helper or fallback owns it. | `[SSANM-006a2a]` positive ordinary block/if fixtures deliberately exclude branches; `[SSANM-005c3b]` covers the already-supported mixed `br_if` subset. | `[SSANM-006a3b]` decides whether additional plain `br` / `br_if` local-source regions can use a planned LocalGraph path or should stay fail-closed. |
| Plain `br` multi-source or mixed regions | `run_hot_pipeline_raw_ssa_nomerge_multisource_merge_supported_control(...)` rejects `br`; `run_hot_pipeline_raw_rewrite_instrs(...)` handles `@lib.Br` by appending needed alias/result copies before the branch. Trace stays off canonical-only/mixed LocalGraph reasons. | `ssa-nomerge keeps plain br multi-source merges off LocalGraph path` and `ssa-nomerge keeps mixed plain br regions off LocalGraph path` validate and preserve `br` without claiming planned reasons. | `[SSANM-006a3b]`. |
| Value-carrying `br` operands / typed block exits | Branch operands require stack/control-value ABI handling. Current tests keep them outside ordinary LocalGraph reasons; raw `@lib.Br` handling can append result scratch/copies via `run_hot_pipeline_raw_append_alias_merge_copies_for_needed(...)`. | `ssa-nomerge keeps value br operands off LocalGraph path`. | `[SSANM-007b3]` for typed branch operands; `[SSANM-006a3b]` should avoid admitting these as ordinary local-source rewrites. |
| `br_table` exits and table-target mixes | `run_hot_pipeline_raw_ssa_nomerge_multisource_merge_supported_control(...)` rejects `br_table`; raw `@lib.BrTable` handling owns table alias-copy/scratch/proxy lowerings (`run_hot_pipeline_raw_br_table_alias_copies`, mixed loop-param proxy/store helpers, and branch-table merge-copy trace classification). | `ssa-nomerge keeps br_table multi-source merges off LocalGraph path`, `ssa-nomerge keeps mixed br_table regions off LocalGraph path`, and `ssa-nomerge keeps value br_table operands off LocalGraph path`. | `[SSANM-006a3c]` for ordinary table exits; `[SSANM-007b3]` for typed/value table operands. |
| Nested normal `block` / `if` targets without loop/typed/EH boundaries | Existing mixed LocalGraph gate supports nested normal `block` / `if`; loop-containing mixed regions stay excluded. | `[SSANM-005c3c]` nested normal positive and loop fail-closed tests. | `[SSANM-006a3d]` expands only source-backed nested target subsets not already covered. |
| `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` | Typed-control/ref-branch helpers own these paths (`run_hot_pipeline_raw_rewrite_br_on_*`, cast branch helpers, loop-param proxy/store helpers); ordinary LocalGraph gates reject them. | Existing branch/ref/cast tests plus `[SSANM-006a1]` value-branch boundary docs; GenValid `[SSANM-011e]` floors branch-operand boundaries. | `[SSANM-007b3]`. |
| EH-containing branch regions | `try_table` / throwing flow stays outside normal-flow LocalGraph mutation unless a later no-throw subset is explicitly admitted. | EH fail-closed tests and source note from the 2026-06-09 exceptional-edge audit. | `[SSANM-007a1]` through `[SSANM-007a3]`. |

Inventory conclusion: the only already-supported ordinary branch-exit LocalGraph mutation is the narrow mixed `br_if` early-exit family, plus the simple void-loop direct `br_if 0` canonical-only backedge family. Plain `br`, `br_table`, value branch operands, typed ref/cast branches, EH, and broader nested/loop target combinations remain explicit boundary owners until their child slices add focused red-first coverage or documented fail-closed decisions.

## `[SSANM-006a3b]` plain `br` and `br_if` ordinary local-source classification

`[SSANM-006a3b]` locks the current v0.1.0 policy for ordinary void branch exits that have only local-source traffic but do not belong to the already-supported mixed `br_if` or simple loop-backedge subsets. These fixtures are deliberately fail-closed from the planned structured LocalGraph mutation path rather than new mutation wins.

| Family | Classification | Focused proof |
| --- | --- | --- |
| Ordinary void `br` exit after a single-source local write | Keep off `structured-localgraph-plan` and `structured-mixed-localgraph-plan`; preserve the branch and leave ownership with branch-alias/raw structured helpers until `[SSANM-006a3d]` / later narrowing proves more nested-target safety. | `ssa-nomerge keeps ordinary plain br local-source regions off planned structured path`. |
| Ordinary void `br_if` exit after a single-source local write, with no mixed merge traffic | Keep off `structured-localgraph-plan`, `structured-mixed-localgraph-plan`, and `structured-loop-backedge-merge-localgraph-plan`; preserve the branch and treat it as outside the supported mixed early-exit / simple backedge subsets. | `ssa-nomerge keeps ordinary br_if local-source regions off planned structured path`. |
| Mixed `br_if` early exits and simple void-loop direct `br_if 0` backedges | Still supported by their prior named reasons; `[SSANM-006a3b]` does not revoke those completed slices. | `[SSANM-005c3b]` and `[SSANM-005b2]` tests. |

Because this is a fail-closed classification of existing routing, direct compare was not required. If a later slice admits plain `br` or additional `br_if` subsets to a planned LocalGraph rewrite, it should add red-first positive fixtures and run the ordinary direct `--pass ssa-nomerge` compare lane.

## `[SSANM-006a3c]` ordinary `br_table` local-source classification

`[SSANM-006a3c]` gives ordinary table exits the same conservative boundary status as the earlier table multi-source, mixed, and value-operand fixtures. The newly locked fixture has no typed/value branch operand and no table-local merge writes, but it still contains a normal `br_table` target mesh. Starshine keeps that shape off planned structured LocalGraph mutation until table-target alias/scratch ownership is narrowed.

| Family | Classification | Focused proof |
| --- | --- | --- |
| Ordinary void `br_table` exit after a single-source local write | Keep off `structured-localgraph-plan`, `structured-mixed-localgraph-plan`, `structured-multisource-merge-localgraph-plan`, and the loop-backedge reason; preserve the table branch and leave ownership with branch-table raw helpers. | `ssa-nomerge keeps ordinary br_table local-source regions off planned structured path`. |
| Mixed and multi-source `br_table` regions | Still fail-closed from mixed/canonical LocalGraph reasons; table-target and branch-operand helper ownership remains explicit. | `ssa-nomerge keeps mixed br_table regions off LocalGraph path` and `ssa-nomerge keeps br_table multi-source merges off LocalGraph path`. |
| Value-carrying `br_table` operands | Still typed-control / branch-operand boundary work, not ordinary local-source freshening. | `ssa-nomerge keeps value br_table operands off LocalGraph path`; owned by `[SSANM-007b3]`. |

Because this is another fail-closed classification of existing routing, direct compare was not required. If a later slice admits any table subset to planned LocalGraph mutation, it should add red-first positive fixtures, prove no table-target alias/proxy lowering is bypassed, and run the ordinary direct `--pass ssa-nomerge` compare lane.

## `[SSANM-006a3d]` nested normal branch-target classification

`[SSANM-006a3d]` closes the first normal structured-control expansion pass by separating nested normal `block` / `if` shapes that are already supported from nested branch-target and loop-containing shapes that still need explicit boundary ownership. It does not admit a new mutation family; the new executable coverage is deliberately fail-closed.

| Nested target family | Classification | Focused proof / next owner |
| --- | --- | --- |
| Nested normal `block` / `if` regions with ordinary `local.set` traffic and no branch exits | Supported by the ordinary `structured-localgraph-plan` path when the plan has single-source freshening/retargeting and no rejected opcode. | `[SSANM-006a2a]` ordinary nested `block` / `if` fixtures. |
| Nested normal `block` / `if` mixed fresh/canonical regions without plain branch/table exits | Supported by `structured-mixed-localgraph-plan`; planned non-merge writes freshen and canonical merge writes/reads stay on the original local. | `[SSANM-005c3c]` test `ssa-nomerge LocalGraph freshens nested mixed block if writes`. |
| Mixed `br_if` early exits and simple void-loop direct `br_if 0` canonical backedges | Supported only by their narrow existing gates. Nested-target closeout does not broaden them. | `[SSANM-005c3b]` mixed `br_if` early-exit fixture and `[SSANM-005b2]` simple direct void-loop backedge fixture. |
| Nested `br_if` targeting an enclosing block, with only local-source traffic | Fail closed from `structured-localgraph-plan`, `structured-mixed-localgraph-plan`, `structured-multisource-merge-localgraph-plan`, and `structured-loop-backedge-merge-localgraph-plan`; preserve the branch until branch-target alias ownership is narrowed. | `[SSANM-006a3d2]` test `ssa-nomerge keeps nested br_if to outer block off planned structured path`. |
| Loop-containing nested exits that are not the simple direct void-loop `br_if 0` backedge | Fail closed from ordinary planned LocalGraph reasons. These can interact with loop-entry values, typed loop params/results, or later branch-helper repair. | `[SSANM-006a3d2]` test `ssa-nomerge keeps nested loop-exit br_if off planned structured path`; typed loop/result follow-up remains `[SSANM-007b2]`. |
| Plain `br`, `br_table`, value branch operands, typed ref/cast branches, and EH inside nested targets | Still branch/table, typed-control, or EH boundary work, not ordinary nested LocalGraph mutation. | `[SSANM-006a3b]`, `[SSANM-006a3c]`, `[SSANM-007a*]`, and `[SSANM-007b*]`. |

The retained raw structured helpers therefore remain necessary for branch/table target repair and typed/EH boundaries. If a later slice wants to admit more nested branch targets, it should add red-first positive fixtures, prove the shape does not need branch-alias/table/typed/EH scratch repair, and run the ordinary direct `--pass ssa-nomerge` compare lane.

## `[SSANM-006b1]` predecessor-copy-producing path inventory

`[SSANM-006b1]` is a source/test inventory, not a mutation change. It separates three categories that future slices must not conflate:

| Category | Current path | Copy/proxy risk | Current owner |
| --- | --- | --- | --- |
| Ordinary LocalGraph-supported no-merge rewrites | Straight-line `straight-line-local-writes-localgraph-plan`, default materialization, canonical-only one-arm/multi-source/loop-backedge merge preservation, mixed normal-control `structured-mixed-localgraph-plan`, `[SSANM-006a2a]` ordinary `structured-localgraph-plan`, and `[SSANM-006a2b]` merge-adjacent ordinary `local.set` coverage | No predecessor-copy merge locals; fresh locals are planned per explicit write, merge reads stay canonical, and canonical-only paths return unchanged. | Completed `[SSANM-003a]` through `[SSANM-006a2b]`; `[SSANM-006a2c]` narrows the remaining legacy structured-helper ownership without changing behavior. |
| Fallback HOT SSA destruction | `src/passes/ssa_nomerge.mbt` still delegates to `@ir.ssa_destroy_into_hot(...)` after requiring CFG and local SSA when the raw dispatcher returns `None`. `src/ir/ssa_destroy.mbt` builds `copies_by_predecessor` and inserts predecessor-copy nodes. | This is the real predecessor-copy-producing path and remains inconsistent with Binaryen no-merge for any ordinary family that reaches it. | `[SSANM-006b2a]` first censuses ordinary fallback survivors, `[SSANM-006b2b]` locks straight-line/default families off the fallback, `[SSANM-006b2c]` reroutes any structured ordinary survivors, and `[SSANM-006b3]` should narrow summaries/helpers after rerouting. |
| Raw branch / typed-control scratch helpers | Branch-alias copies, br_table scratch/proxy branches, loop-param store/proxy lowerings, cast/null branch copy blocks, and branch-heavy scratch freshening in `src/passes/pass_manager.mbt`. | These allocate scratch/proxy locals or branch-local alias copies, but they are intentional Starshine boundary lowerings rather than ordinary no-merge predecessor-copy materialization. | Completed `[SSANM-006b2d]` documents this boundary from the predecessor-copy-retirement perspective, while `[SSANM-006a3d]`, `[SSANM-007a*]`, `[SSANM-007b*]`, and huge/artifact slices decide which stay, narrow further, or become fail-closed. |

The inventory means the remaining predecessor-copy retirement work is not to delete all local allocation in `ssa-nomerge`; it is to prevent ordinary LocalGraph-supported local-source traffic from reaching HOT SSA destruction or branch/typed scratch helpers when Binaryen `SSAify(false)` would freshen single-source writes or preserve canonical merge reads directly. The 2026-06-14 split keeps that work in four smaller review units: fallback census, straight-line/default regression proof, structured ordinary rerouting, and boundary classification for scratch/proxy helpers.

## `[SSANM-006b2a]` fallback HOT SSA-destruction survivor census

`[SSANM-006b2a]` is a source/test census of when the raw `ssa-nomerge` dispatcher can still return `None` and fall through to the lifted HOT pass (`ssa_nomerge_run(...)`, then `@ir.ssa_destroy_into_hot(...)`). It does not change mutation policy.

| Dispatcher family | Does it fall into HOT SSA destruction? | Census classification / next owner |
| --- | --- | --- |
| No-local-write functions, including default-entry reads and dropped-unreachable debris | No. The raw dispatcher returns `no-local-writes`, `default-local-reads-localgraph-plan`, or debris cleanup reasons. | Lock against regression in `[SSANM-006b2b]`. |
| Straight-line functions with `local.set` / `local.tee` writes | No. The raw dispatcher always builds `SsaNoMergeRewritePlan` and returns `straight-line-local-writes-localgraph-plan`. | Lock against regression in `[SSANM-006b2b]`. |
| Completed ordinary normal-control families: one-arm/default merges, both-arm/block-`br_if` multi-source merges, simple void-loop direct `br_if 0` backedge merges, mixed normal `local.set` / small `local.tee` / nested `block` / `if` / supported `br_if`, and ordinary block/if single-source `local.set` rewrites | No for their supported shapes. They return named LocalGraph reasons before legacy helper fallback. | Keep covered by completed `[SSANM-005a]` through `[SSANM-006a2b]`; add regression locks in `[SSANM-006b2b]` / `[SSANM-006b2c]` only where needed. |
| Loop-carried `br_if` shapes not admitted by the simple direct void-loop canonical-only gate | Yes: `run_hot_pipeline_raw_ssa_nomerge_should_defer_loop_carried_br_if_to_hot(...)` can deliberately return `None`. | Candidate list for `[SSANM-006b2c]` only if a reduced shape is ordinary LocalGraph-supported; typed/value loop cases remain `[SSANM-007b2]`. |
| Legacy structured helper failures (`run_hot_pipeline_raw_ssa_nomerge_structured(...)` returns `None`) and invalid-escape-carrier rejections when no default materialization changed the function | Yes. With no raw result to return, the dispatcher falls through to lifted HOT SSA destruction. | Candidate list for `[SSANM-006b2c]`; classify reduced examples as ordinary rerouting gaps versus branch/table/typed/EH/huge boundaries. |
| Branch-table, value branch operand, typed-control, EH, and branch-alias scratch/proxy helpers | Usually no ordinary fallback claim: they either stay fail-closed/no-op, use raw helper lowerings, or may fall through only as an explicit boundary. | Completed `[SSANM-006b2d]` keeps them out of ordinary predecessor-copy work and cross-links them to `[SSANM-006a3c]`, `[SSANM-007a*]`, and `[SSANM-007b*]`. |
| Huge structured functions over raw instruction/local thresholds | No HOT fallback from the raw guard; the dispatcher returns `large-structured-local-writes ...` unchanged. | Huge-function policy stays in `[SSANM-008a]` through `[SSANM-008d]`. |

Census conclusion: no completed straight-line/default/ordinary block-if LocalGraph family is expected to reach `ssa_destroy_into_hot`. The remaining true fallback-risk candidates are non-simple loop-carried branch shapes and legacy structured helper rejection paths. Those should be reduced in `[SSANM-006b2c]` before any behavior change; branch-table, typed-control, EH, and huge-function cases should stay boundary-classified unless their owning slice proves a narrow ordinary local-source subset.

## `[SSANM-006b2b]` straight-line/default fallback regression locks

`[SSANM-006b2b]` adds executable regression locks for the census families that should never reach lifted HOT SSA destruction. The fixtures do not admit new mutation behavior; they require the public pipeline to return the already-owned raw/no-write exits and assert that no lifted-HOT mutation or invalid-lower fallback is reported.

| Family | Required trace reason | Regression proof |
| --- | --- | --- |
| Straight-line overwritten `local.set` and `local.tee` writes | `straight-line-local-writes-localgraph-plan` | `ssa-nomerge locks straight-line writes off HOT fallback` checks planned fresh locals, retargeted final gets, tee retargeting, no `pass[ssa-nomerge]:mutated`, and no `skip-invalid-lower`. |
| Plain no-write functions | `no-local-writes` | `ssa-nomerge locks no-write default families off HOT fallback` keeps a no-write constant function on the no-write raw exit. |
| No-write default-entry reads through branchy control | `default-local-reads-localgraph-plan` | The same fallback-lock test reuses the branchy `br_table` default-read shape and checks that the final body-local read becomes an explicit `i32.const 0`. |
| No-write dropped-unreachable debris cleanup | `no-local-writes-unreachable-debris` | The same fallback-lock test verifies the debris block/drop shape is removed while the hard `unreachable` remains. |

Because these tests only lock current routing and do not change pass behavior, direct compare was not required. `[SSANM-006b2c]` remains the first behavior-changing predecessor-copy reroute candidate if a reduced ordinary structured fallback survivor is found.

## `[SSANM-006b2d]` branch/table/typed/EH scratch-helper boundary classification

`[SSANM-006b2d]` closes the predecessor-copy-retirement classification for local allocations that are still visible in `ssa-nomerge` output but are not ordinary no-merge predecessor-copy materialization. These helpers repair branch, table, typed-control, or EH/lowering ABI shapes around Starshine's raw structured representation. They should not be counted as Binaryen `SSAify(false)` merge locals, and they should not be rerouted by `[SSANM-006b2c]` unless a later owner proves a narrower ordinary LocalGraph local-source subset.

| Scratch / copy-like family | Source owner | Current classification | Proof surface / next owner |
| --- | --- | --- | --- |
| Branch-alias copies for plain `br` / `br_if` and result-bearing label exits | `run_hot_pipeline_raw_append_alias_merge_copies_for_needed(...)`, `run_hot_pipeline_raw_rewrite_br_if(...)`, and branch label-target `needed_alias_copies` propagation in `src/passes/pass_manager.mbt` | Boundary helper. It restores canonical aliases at explicit branch exits or preserves branch result operands; it is not full-SSA phi/predecessor-copy insertion for ordinary no-merge merges. | `[SSANM-006a3b]` keeps ordinary plain `br` / extra `br_if` local-source regions off planned structured LocalGraph mutation; value branches remain typed-control work for `[SSANM-007b3]`. Existing branch-copy tests around `ssa_test_assert_raw_ref_branch_copy_lowering(...)` guard observable copy lowerings. |
| Ordinary `br_table` aliases plus mixed table scratch/proxy lowerings | `run_hot_pipeline_raw_br_table_alias_copies(...)`, `run_hot_pipeline_raw_rewrite_mixed_loop_param_store_br_table(...)`, and `run_hot_pipeline_raw_rewrite_mixed_loop_param_proxy_br_table(...)` | Table-target boundary. Selector locals, result scratches, and proxy/store branches repair table-target ABI and mixed loop-param targets; they are not ordinary LocalGraph no-merge predecessor copies. | `[SSANM-006a3c]` locks ordinary no-value `br_table` local-source exits as fail-closed from planned structured paths; typed/value table operands stay with `[SSANM-007b3]`. Existing `ssa-nomerge rewrites ... br_table ...` tests guard table proxy/store shapes. |
| Typed loop param/result backedges | `run_hot_pipeline_raw_loop_param_proxy_label_target(...)`, `run_hot_pipeline_raw_loop_param_store_label_target(...)`, and `run_hot_pipeline_raw_append_loop_param_store_backedge(...)` plus scalar/reference branch-specific store helpers | Typed-control ABI helper. Scratch locals hold loop params/results across stack-control rewrites and branch-specific copies; this is separate from no-merge local-source freshening. | `[SSANM-007b2]` owns typed loop param/result boundary locks. Existing typed-loop tests such as scalar, multi-param, single-result, nested-loop, and reference backedge rewrites prove the helper families validate and remain explicit. |
| Ref/null/cast branch operand spills and inverse cast blocks | `run_hot_pipeline_raw_spill_trailing_ref_branch_input(...)`, `run_hot_pipeline_raw_rewrite_loop_param_store_br_on_null(...)`, `...br_on_non_null(...)`, and `...cast_branch(...)` | Typed branch-operand helper. Scratch refs preserve branch payload/fallthrough values and subtype/cast ABI; not an ordinary predecessor-copy merge-local path. | `[SSANM-007b3]` owns branch operands, `br_on_*`, and cast/null exit classification. Existing `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` regression families guard both rewrite and fail-closed subfamilies. |
| EH / `try_table` containers and exceptional-flow functions | `run_hot_pipeline_raw_try_table_body_has_exceptional_edge(...)`, `run_hot_pipeline_raw_instrs_only_direct_loop_param_backedges_through_try_table(...)`, plus the HOT `ssa_nomerge` exceptional-flow fail-closed guard | EH boundary. No-throw `try_table` helper rewrites may repair normal typed-loop control through a container, while real exceptional edges remain fail-closed because local SSA v1 has no exceptional successors. | `[SSANM-007a1]` through `[SSANM-007a3]` own EH source refresh and subset classification. Existing tests `ssa-nomerge rewrites no-throw try_table local writes`, `ssa-nomerge does not mutate unsupported exceptional-flow functions`, and `ssa-nomerge preserves try-table local writes across exceptional exits` guard the current split. |

This classification leaves `[SSANM-006b2c]` focused on genuine ordinary fallback survivors only: non-simple loop-carried branch shapes or legacy structured helper rejection paths that the census can reduce to Binaryen no-merge local-source traffic. It also leaves `[SSANM-006b3]` free to update the pass summary and narrow legacy wording after ordinary rerouting, without deleting branch/table/typed/EH safety helpers that still have explicit owners.

Because this is a source/test classification of existing helper ownership and changes no executable behavior, direct compare was not required. Focused `ssa_nomerge_test.mbt` coverage remains the appropriate regression proof for the named boundary families until a later slice admits a new mutation subset.

## `[SSANM-007a1]` EH source and local boundary inventory

`[SSANM-007a1]` refreshes the exceptional-edge owner map after the normal structured-control and predecessor-copy slices. There is still no dedicated Binaryen `ssa-nomerge` EH fixture in the refreshed `version_130` no-merge WAST surface; the relevant upstream contract remains the general `SSAify(false)` LocalGraph policy. Starshine's local SSA v1, however, is documented and implemented as normal-flow-only, so real exceptional successors are a local representation boundary rather than ordinary LocalGraph local-source work.

| EH family | Current Starshine owner / decision | Proof surface / next owner |
| --- | --- | --- |
| Real `try_table` body exceptional exits via `throw` or `throw_ref`, including catch and catch-all targets | Fail closed from HOT SSA destruction and planned structured LocalGraph mutation. `src/passes/ssa_nomerge.mbt` `ssa_nomerge_has_exceptional_flow(...)` treats `Try`, `TryTable`, `Throw`, `ThrowRef`, `Rethrow`, `Delegate`, `Catch`, and `CatchAll` as an unchanged HOT boundary because liveness/dominance/phi/destroy do not model exceptional predecessors. Raw `try_table` helpers additionally use `run_hot_pipeline_raw_try_table_body_has_exceptional_edge(...)` to reject throwing/call-bearing try bodies in helper paths that otherwise admit normal branches. | Corruption regression `ssa-nomerge does not mutate unsupported exceptional-flow functions`, preservation tests for `try_table` writes/defaults, `[SSANM-007a2a]` direct/conditional catch-target locks, and `[SSANM-007a2b1]` direct HOT `throw_ref` no-revision lock. |
| Legacy `try` / `catch` / `rethrow` and `delegate` shapes | Fail closed at the HOT boundary. Some legacy WAT forms do not survive the current public lift/lower roundtrip, so direct HOT fixtures are valid boundary proof when public WAT cannot represent the reduced shape. | `[SSANM-007a2b2]` strengthens `ssa-nomerge preserves legacy rethrow shapes without hot local corruption` with public-pipeline trace assertions against planned structured LocalGraph reasons and `pass[ssa-nomerge]:mutated`; `[SSANM-007a2b3]` keeps `ssa-nomerge preserves delegate shapes without hot local corruption` as the direct HOT delegate no-revision proof. |
| No-throw `try_table` containers with ordinary local writes and no exceptional body edge | Classified/currently supported normal-flow subset. The public raw path can rewrite no-throw `try_table` local writes through the existing raw structured helper; this is not evidence that real exceptional edges are modeled. | `ssa-nomerge rewrites no-throw try_table local writes`; `[SSANM-007a3]` keeps this admitted only when the body has no throw/call-bearing edge. |
| No-throw `try_table` containers around typed-loop backedges or store/proxy models | Typed-control helper territory, not ordinary EH mutation. These shapes may pass through `run_hot_pipeline_raw_instrs_only_direct_loop_param_backedges_through_try_table(...)` only when `run_hot_pipeline_raw_try_table_body_has_exceptional_edge(...)` is false. | Existing no-throw `try_table` scalar proxy, multi-param typed loop, single-result typed loop, catch-relabeling, and store-model tests; `[SSANM-007a3]` classifies their no-throw container boundary, while broader typed-control ABI ownership stays with `[SSANM-007b2]`. |
| Throwing/call-bearing `try_table` around typed-loop helpers | Boundary unless a specific typed-control helper proves a safe lowering without relying on exceptional-edge SSA. | Existing throwing typed-loop try-table tests guard legacy helper behavior, but they do not broaden ordinary planned LocalGraph mutation. `[SSANM-007a2c]` should summarize the retained exception for closeout. |

Inventory conclusion: `[SSANM-007a1]` does not add a new mutation rule. It records that Starshine has two distinct EH categories: (1) real exceptional-flow functions are fail-closed from normal LocalGraph/SSA mutation, and (2) no-throw `try_table` containers can sometimes host normal-flow raw helper rewrites. `[SSANM-007a2*]` locks the first category; `[SSANM-007a3]` keeps the second category admitted only for already-proven no-throw local-write and typed-control helper subsets.

## `[SSANM-007a2a]` throwing `try_table` catch-target locks

`[SSANM-007a2a]` adds focused public-pipeline locks for the real exceptional-flow category above. These are deliberately fail-closed boundary tests, not new behavior admissions.

| Throwing EH shape | Classification | Focused proof |
| --- | --- | --- |
| Direct `throw` inside a `try_table` body to a typed `catch` target after a body-local write | Keep off `structured-localgraph-plan`, `structured-mixed-localgraph-plan`, `structured-multisource-merge-localgraph-plan`, and `structured-loop-backedge-merge-localgraph-plan`; preserve both the local write and `throw`; do not report lifted HOT mutation. | `ssa-nomerge keeps throwing try_table catch exits off planned structured path`. |
| Conditional `throw` inside a `try_table (catch_all ...)` body after a local write | Same fail-closed classification. The normal fallthrough arm does not make the exceptional catch edge safe for ordinary LocalGraph no-merge mutation. | `ssa-nomerge keeps conditional catch_all throws off planned structured path`. |

Because these tests only lock existing fail-closed routing and admit no mutation family, direct `--pass ssa-nomerge` compare was not required. If a future slice wants to mutate real throwing EH shapes, it must first model exceptional successors in local SSA/LocalGraph or implement a separate EH-aware repair helper, then add red-first positive fixtures and direct compare evidence.

## `[SSANM-007a2b]` legacy exceptional terminator locks

`[SSANM-007a2b]` closes the remaining throwing/legacy terminator regression locks after the `try_table` catch-target fixtures. These locks are intentionally fail-closed: they prove the pass preserves local traffic and does not run lifted HOT SSA destruction for exceptional terminators, not that Starshine can rewrite real EH local-source flow.

| Exceptional terminator shape | Classification | Focused proof |
| --- | --- | --- |
| Direct HOT `throw_ref` root with an `exnref` operand and nearby `local.set` | Fail closed at the HOT boundary; `throw_ref` is an exceptional exit and local SSA v1 does not model its exceptional successor/reaching-set effects. | `ssa-nomerge preserves throw_ref shapes without hot local corruption` builds the HOT shape directly, verifies local traffic remains present, and asserts the HOT revision is unchanged. |
| Legacy `try` / `catch` / `rethrow` WAT | Fail closed from planned structured LocalGraph reasons and lifted HOT mutation. Current public lift/lower can normalize the rethrow surface, so the lock asserts preserved local/throw traffic plus trace behavior instead of exact legacy text shape. | `ssa-nomerge preserves legacy rethrow shapes without hot local corruption` first checks the HOT-only path preserves local traffic, then runs the public pipeline with trace assertions against `structured-localgraph-plan`, `structured-mixed-localgraph-plan`, `structured-multisource-merge-localgraph-plan`, `structured-loop-backedge-merge-localgraph-plan`, and `pass[ssa-nomerge]:mutated`. |
| Direct HOT `delegate` terminator | Fail closed at the HOT boundary; delegate targets are exceptional-control targets and are not part of the ordinary LocalGraph no-merge local-source policy. | `ssa-nomerge preserves delegate shapes without hot local corruption` builds the delegate directly because nested legacy delegate WAT does not currently survive lift/lower, then verifies local traffic remains present and the HOT revision is unchanged. |

Because `[SSANM-007a2b]` adds only fail-closed regression locks and admits no new mutation family, direct compare was not required.

## `[SSANM-007a2c]` throwing EH fail-closed closeout

`[SSANM-007a2c]` closes the throwing exceptional-flow subtrack for v0.1.0. The locked fail-closed families are:

- `try_table` bodies with direct `throw` to typed `catch` targets;
- `try_table` bodies with conditional `throw` to `catch_all` targets;
- direct HOT `throw_ref` roots;
- legacy `try` / `catch` / `rethrow` public-pipeline shapes;
- direct HOT `delegate` terminators.

The retained candidate surface was the no-throw EH-body category: no-throw `try_table` containers with ordinary local writes or typed-loop helper traffic can still be normal-flow work when `run_hot_pipeline_raw_try_table_body_has_exceptional_edge(...)` rejects any exceptional/call-bearing body edge. `[SSANM-007a3]` later classified those no-throw subsets and kept them narrow.

Reopening real throwing EH mutation requires at least one of these missing capabilities:

1. local SSA / LocalGraph facts that model exceptional successors and catch/delegate reaching-set edges;
2. an EH-aware repair helper that can rewrite local traffic while preserving catch-stack/delegate semantics;
3. red-first positive fixtures plus direct `--pass ssa-nomerge` compare evidence proving a narrow throwing EH subset is valid and Binaryen-compatible.

Direct compare was not run for `[SSANM-007a2c]` because the closeout is documentation plus fail-closed regression locks; no pass behavior mutation or newly admitted mutation family was introduced.

## `[SSANM-007a3]` no-throw `try_table` normal-flow subset classification

`[SSANM-007a3]` keeps the existing no-throw `try_table` subset admitted, but narrows the claim: these are normal-flow local-write or typed-control helper rewrites through a container whose body has no helper-visible exceptional edge. They are not evidence that Starshine's local SSA / LocalGraph can model real EH successors.

| No-throw EH-body family | Current owner / decision | Focused proof |
| --- | --- | --- |
| Ordinary `try_table` body with local writes and no throw/call-bearing edge | Keep admitted through the existing raw structured local-write path. The body is treated as normal-flow work only because `run_hot_pipeline_raw_try_table_body_has_exceptional_edge(...)` returns false. | `ssa-nomerge rewrites no-throw try_table local writes` now also asserts the `structured-local-writes` trace reason and the exact fresh-local output shape. |
| `try_table` body that contains `call`, `call_indirect`, `call_ref`, `return_call*`, `throw`, or `throw_ref` | Fail closed from the no-throw local-write rewrite. Calls are conservatively treated as exceptional-edge risks by `run_hot_pipeline_raw_try_table_body_has_exceptional_edge(...)`, just like explicit throw-family opcodes. | `ssa-nomerge keeps call-bearing try_table bodies off no-throw local rewrite` proves a call-bearing body does not take `structured-local-writes`, does not report `pass[ssa-nomerge]:mutated`, and preserves call/local traffic. Throwing catch/catch-all cases are covered by `[SSANM-007a2a]`. |
| No-throw `try_table` around scalar or reference loop-param proxy backedges | Keep as typed-control helper work, not ordinary EH SSA. These rewrites repair loop-param stack/control ABI through a container after the helper has rejected exceptional body edges. | `ssa-nomerge rewrites no-throw try_table scalar proxy backedges` now records trace/validation and still asserts the scalar loop-param proxy shape. Related scalar/reference typed-loop proxy tests remain under `[SSANM-007b2]` ownership for the broader typed-loop ABI decision. |
| No-throw `try_table` around multi-param/no-result and single-result typed-loop store models, catch relabeling, and `br_table` variants | Keep as typed-control / table-helper territory. Catch relabeling is a structural repair for the inserted wrapper blocks, not evidence of exceptional-edge SSA support. | Existing tests `ssa-nomerge rewrites no-throw try_table multi-param typed loop br backedges`, `ssa-nomerge rewrites no-throw try_table single-result typed loop br backedges`, `ssa-nomerge rewrites try_table scalar proxy br_if catch-relabeling`, `ssa-nomerge rewrites try_table scalar proxy br_table catch-relabeling`, `ssa-nomerge rewrites try_table single-result fallthrough store model`, and `ssa-nomerge rewrites try_table single-result br_table fallthrough store model`. |

Classification conclusion: keep no-throw `try_table` bodies admitted only in the already-proven normal-flow categories above. Reopen real EH mutation only with exceptional successor/reaching-set support or an EH-aware repair helper, then add red-first positive tests plus direct `--pass ssa-nomerge` compare evidence. Because `[SSANM-007a3]` only added/strengthened regression locks and source/test documentation around existing behavior, direct compare was not rerun.

## `[SSANM-007b1]` typed-control source and fixture inventory

`[SSANM-007b1]` is an inventory and ownership split, not a mutation change. The refreshed Binaryen `version_130` no-merge source/test surface still has no dedicated typed loop-param/result or typed branch-operand fixtures beyond the general `SSAify(false)` LocalGraph policy. Starshine's current typed-control rewrites are therefore local raw-helper ABI repairs around stack/control values, not evidence that ordinary LocalGraph local-source mutation should silently own those shapes.

### `[SSANM-007b1a]` typed loop param/result helper owners

| Typed loop/result family | Current Starshine owner / decision | Proof surface / next owner |
| --- | --- | --- |
| Scalar typed loop params with direct `br` / `br_if` backedges | Typed-control proxy helper. Single-param scalar loops can lower through a proxy value block or direct branch rewrite while preserving the loop-param stack ABI; this is separate from ordinary no-merge freshening. | `run_hot_pipeline_raw_loop_param_proxy_label_target(...)`, `run_hot_pipeline_raw_append_loop_param_store_backedge(...)`, and tests such as `ssa-nomerge rewrites direct scalar typed loop-param br backedge`, `ssa-nomerge rewrites no-copy scalar typed loop-param br_if backedge`, and the i64/f32/f64/nested scalar variants. `[SSANM-007b2]` owns executable boundary locks. |
| Copy-needing scalar and reference typed loop params | Typed-control proxy/helper with branch-local alias copy repair. Copy-like locals here preserve overwritten canonical aliases at loop backedges; they are not no-merge predecessor-copy merge locals. | `run_hot_pipeline_raw_append_alias_merge_copies_for_needed(...)` plus scalar/reference copy-needing tests: `copy-needing scalar typed loop-param br_if`, nullable/non-null reference typed loop-param variants, and copy-needing nullable/non-null reference variants. `[SSANM-007b2]` should keep this boundary explicit. |
| Multi-param typed loop backedges with no result | Store-model helper. The helper spills loop payload values into per-param scratches, runs branch-local alias copies when needed, and reloads scratches as loop params. | `run_hot_pipeline_raw_loop_param_store_label_target(...)`, `run_hot_pipeline_raw_append_loop_param_store_backedge(...)`, `run_hot_pipeline_raw_rewrite_loop_param_store_br_if(...)`, and tests `multi-param typed loop direct br backedges`, `multi-param typed loop br_if backedges`, and `multi-param typed loop br_table backedges`. |
| Single-result / multi-param single-result typed loops | Store-model helper with result ABI repair. The result type is part of the control ABI and can require scratch locals or block result reconstruction; it is not ordinary local-source no-merge policy. | `run_hot_pipeline_raw_loop_param_and_result_types(...)`, `run_hot_pipeline_raw_single_result_block_type(...)`, store-model helpers, and tests `single-result typed loop direct br backedges`, `single-result typed loop br_if backedges`, `multi-param single-result typed loop br_table backedges`, and `multi-result typed loop-param direct br`. |
| `br_table` targets that are all current-loop, mixed current-loop/enclosing-label, or non-current/nested typed-loop targets | Table/typed-control helper territory. Selector locals and synthetic branch ladders repair table target ABI and loop-param scratches. | `run_hot_pipeline_raw_br_table_loop_param_store_target(...)`, `run_hot_pipeline_raw_br_table_mixed_loop_param_store_target(...)`, `run_hot_pipeline_raw_br_table_mixed_loop_param_proxy_target(...)`, `run_hot_pipeline_raw_rewrite_mixed_loop_param_store_br_table(...)`, and tests covering scalar, copy-needing scalar, multi-param, mixed-target, non-current, and nested typed-loop `br_table` shapes. `[SSANM-007b3]` owns the branch-table operand side; `[SSANM-007b2]` owns loop-param/result ABI. |
| Nested loop targets under typed loop params | Typed-control boundary. Nested void self-loop branches may be allowed only when `run_hot_pipeline_raw_instrs_only_direct_loop_param_backedges_with_void_self(...)` can prove they stay local to the nested loop or still target the enclosing typed loop safely; non-void or other-label forms remain later boundary work. | Nested tests `nested-loop multi-param typed loop br backedges`, `nested-loop multi-param single-result typed loop br_if backedges`, `nested-loop multi-param typed loop br_on_null backedges`, and `nested self-loop ... typed loop ... backedges`; `[SSANM-007b2]` should add/strengthen trace locks without treating these as ordinary structured LocalGraph mutation. |
| No-copy typed-loop-param fixtures with no overwrite or edge-copy need | Boundary/no-mutation helper. These are intentionally accepted no-op cases proving the pass does not allocate scratches when there is no loop-carried overwrite or edge repair to perform. | `ssa_test_no_copy_typed_loop_param_module_no_mutation(...)` / `ssa_test_no_copy_typed_loop_param_pipeline_no_mutation(...)`; `[SSANM-007b2]` should keep no-copy cases explicit as contrast with proxy/store helpers. |

### `[SSANM-007b1b]` typed branch operand and cast/null exit owners

| Typed branch family | Current Starshine owner / decision | Proof surface / next owner |
| --- | --- | --- |
| Value-carrying `br` / `br_if` exits to typed blocks or loops | Branch-alias / typed-control ABI helper or fail-closed boundary. Value operands are stack/control payloads and should not be admitted to ordinary LocalGraph local-source rewrites without a branch-operand repair proof. | `run_hot_pipeline_raw_rewrite_br_if(...)`, `run_hot_pipeline_raw_append_alias_merge_copies_for_needed(...)`, and `[SSANM-006a1]` / `[SSANM-006a3b]` value/plain branch fail-closed tests. `[SSANM-007b3]` owns any additional positive or fail-closed locks. |
| Value-carrying `br_table` exits and table mixes | Table-target ABI helper or fail-closed boundary. Selector locals, scratch branches, and target relabeling preserve branch payloads and mixed table targets. | `run_hot_pipeline_raw_br_table_alias_copies(...)`, mixed table proxy/store helpers, and tests `ssa-nomerge keeps value br_table operands off LocalGraph path`, `ssa-nomerge rewrites ... typed loop br_table ...`, and non-current/mixed-target `br_table` families. |
| `br_on_null` / `br_on_non_null` with loop-param targets | Typed branch helper. The helpers spill/test nullable or non-null reference payloads, run branch-local copies only on the taken edge, and reload prefix/loop-param scratches on fallthrough as needed. | `run_hot_pipeline_raw_rewrite_loop_param_store_br_on_null(...)`, `run_hot_pipeline_raw_rewrite_loop_param_store_br_on_non_null(...)`, `run_hot_pipeline_raw_rewrite_br_on_null(...)`, `run_hot_pipeline_raw_rewrite_br_on_non_null(...)`, and scalar/multi-param/no-copy/copy-needing `br_on_null` and `br_on_non_null` typed-loop tests. |
| Prefix-payload, tested-producer, and store-model ref branch inputs | Typed branch operand spill model. Supported trailing producers (`local.get`, `local.tee`, `ref.null`, `ref.cast`, conversions, `ref.i31`, `ref.func`, struct/array constructors, and selected calls) are evaluated once and spilled before the branch rewrite; unsupported producer scans stay fail-closed. | `run_hot_pipeline_raw_spill_trailing_ref_branch_input(...)`, `run_hot_pipeline_raw_trailing_ref_branch_input_needs_single_spill_for_non_null(...)`, and tests for ref-null/ref-cast/ref-i31/ref-func/struct/array/new-data/new-elem/local-tee/direct-call/call_ref/call_indirect branch inputs. |
| `br_on_cast` / `br_on_cast_fail` loop-param backedges | Typed cast-branch helper. Cast branches lower through source/fallthrough scratches and inverse cast blocks so branch-local alias copies run only on the semantically taken edge. | `run_hot_pipeline_raw_rewrite_loop_param_store_cast_branch(...)`, `run_hot_pipeline_raw_rewrite_loop_param_store_br_on_cast(...)`, `run_hot_pipeline_raw_rewrite_loop_param_store_br_on_cast_fail(...)`, loop-param proxy cast-copy helpers, and tests `multi-param typed loop br_on_cast backedges`, `copy-needing ... br_on_cast ...`, and `copy-needing ... br_on_cast_fail ...`. |
| No-throw `try_table` wrappers around typed branch/loop helpers | Typed-control helper through an EH container, not real EH SSA and not ordinary LocalGraph local-source mutation. | `[SSANM-007a3]` no-throw `try_table` table plus typed-loop `try_table` tests. `[SSANM-007b2]` / `[SSANM-007b3]` should classify the typed ABI behavior; real EH remains closed by `[SSANM-007a]`. |

### `[SSANM-007b1c]` closeout / handoff to boundary locks

Inventory conclusion: the current typed-control surface is already broad, but it is intentionally broad as raw ABI repair around typed stack/control constructs. `[SSANM-007b2]` should now lock loop-param/result behavior with focused trace/output assertions that distinguish proxy/store/no-copy cases from ordinary LocalGraph local-source rewrites. `[SSANM-007b3]` should do the same for typed branch operands, `br_table`, `br_on_*`, and cast/null exits. Any future admission of a typed-control family to ordinary planned LocalGraph mutation needs red-first positive fixtures plus direct `--pass ssa-nomerge` compare evidence; this inventory changed no executable behavior, so direct compare was not required.

## Starshine test map

| Local test surface | What it proves |
| --- | --- |
| `src/passes/ssa_nomerge_test.mbt:235` | `[SSANM-002a]` planner fixtures cover already-SSA straight-line locals, overwritten freshenable writes, parameter-entry and body-default reads, one-arm branch merges, loop-carried merges, no-read dead `local.set`, and dead `local.tee`. `[SSANM-002b]` adjacent test-only shadow helpers summarize planner freshen/retarget/default/keep counts and current output body-local/local-get shape for reduced fixtures, without changing pass mutation. `[SSANM-005c1]` adds a mixed-region planner summary fixture proving one original local can have freshened writes before/after a canonical merge region. `[SSANM-005a]` public-pipeline fixtures prove missing-else body-local/default and parameter-entry merges keep canonical slots without fresh merge locals or predecessor copies. `[SSANM-005b1]` public-pipeline fixtures prove simple both-arm and block/`br_if` multi-source merge gets keep the original body-local slot and trace the LocalGraph canonical-only merge path. `[SSANM-005b2]` public-pipeline coverage proves a simple void-loop `br_if 0` backedge merge stays canonical and traces `structured-loop-backedge-merge-localgraph-plan`. `[SSANM-005b3]` fail-closed public-pipeline fixtures prove plain `br` and `br_table` multi-source merge regions preserve their branch opcodes but do not claim the canonical-only or mixed LocalGraph path yet. `[SSANM-006a1]` adds fail-closed public-pipeline fixtures for value-carrying `br` and `br_table` operands, preserving their branch/table opcodes and keeping them off the canonical-only/mixed LocalGraph reasons. `[SSANM-005c2]` public-pipeline coverage proves a narrow mixed normal `if`/`local.set` region traces `structured-mixed-localgraph-plan`, freshens only the planned non-merge writes, and introduces no predecessor-copy merge local. `[SSANM-005c3a]` adds public-pipeline coverage proving the same mixed path retargets small `local.tee` freshenable writes while preserving tee stack results and canonical merge-feeding sets. `[SSANM-006a3b]` through `[SSANM-006a3d]` add fail-closed public-pipeline coverage for ordinary plain branches, ordinary `br_table`, nested outer-target `br_if`, and nested loop-exit `br_if` shapes that validate and preserve the branch/table opcode without claiming ordinary planned LocalGraph reasons. `[SSANM-007a2a]` adds throwing `try_table` catch/catch-all fail-closed locks that preserve local writes and `throw` while avoiding ordinary planned structured LocalGraph reasons and lifted HOT mutation. `[SSANM-007a2b]` locks direct HOT `throw_ref`, public legacy catch/rethrow, and direct HOT delegate terminators as no-mutation boundaries. `[SSANM-007a3]` strengthens no-throw `try_table` ordinary local-write and scalar proxy fixtures, and adds the call-bearing `try_table` fail-closed contrast. |
| `src/passes/ssa_nomerge_test.mbt:48` | Straight-line local traffic can stay canonical; `[SSANM-003a]` public-pipeline trace/output fixtures prove the raw `local.set` subset consumes the LocalGraph plan for live parameter overwrites and overwritten body-local writes; `[SSANM-003b]` adds LocalGraph-planned `local.tee` freshening, stack-result preservation, final-get retargeting, and folded effectful tee operand coverage; `[SSANM-006b2b]` adds trace-lock coverage proving straight-line `local.set` / `local.tee`, plain no-write, no-write default-read, and no-write unreachable-debris families exit through named raw/no-write reasons rather than lifted HOT fallback. |
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
