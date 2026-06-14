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
| One-arm default and parameter-entry merges that must stay canonical | `ssa-nomerge_enable-simd.wast` `$if` missing-else body-local and param cases; `local-graph.cpp` structured merge influence tests | `local_graph_test.mbt` default-entry and param-entry merge-source tests; GenValid labels from `[SSANM-011c]` cover one-arm default and param merges. `[SSANM-005a]` adds public-pipeline tests proving missing-else body-local/default and parameter-entry merge gets stay on the canonical slot with no fresh merge local or predecessor copy, and trace `structured-one-arm-merge-localgraph-plan`. | `[SSANM-005a]` is complete for simple missing-else one-arm entry/default merges. Both-arm, loop/backedge, branch-opcode, and mixed per-write follow-ups are now classified under `[SSANM-005b]` / `[SSANM-005c]`; remaining expansion is broader structured-control / typed-control work. |
| Both-arm, loop-carried, and other multi-source merge gets that must stay canonical | `ssa-nomerge_enable-simd.wast` `$if`, `$if2`, and the merge part of `$nomerge`; `local-graph.cpp` `ObstacleMultiSetIf` plus LocalGraph structured flow | `local_graph_test.mbt` diamond both-arm and loop-carried source tests; `ssa_nomerge_test.mbt` has branch/loop/typed-loop canonical-local guards. `[SSANM-005b1]` adds public-pipeline tests proving simple both-arm `if` writes and a block/`br_if` early-exit merge stay on the original body local with no temp or predecessor-copy local. `[SSANM-005b2]` updates the direct void-loop `br_if 0` backedge fixture to prove LocalGraph canonical preservation instead of legacy scratch/proxy rewriting, while existing typed-loop/value-backedge tests keep their scratch-lowering boundaries. `[SSANM-005b3]` adds fail-closed public-pipeline tests for plain `br` and `br_table` multi-source merge boundaries and keeps full-`ssa` merge materialization documented as sibling `ssa` work. | `[SSANM-005b1]` is complete for simple normal structured-control both-arm and block/`br_if` multi-source merge preservation. `[SSANM-005b2]` is complete for simple void-loop direct `br_if 0` backedge canonical preservation. `[SSANM-005b3]` is complete as a classification slice: plain `br` and `br_table` multi-source merge regions validate and preserve their branch opcodes but do not claim the canonical-only LocalGraph path yet; broader branch/table mutation remains in `[SSANM-006a3]`, and typed-loop/branch-operand ABI shapes remain in `[SSANM-007b*]`. |
| Mixed per-write policy for one original local: early freshenable writes, later merge-feeding canonical writes, and freshenable writes after the merge | `ssa-nomerge_enable-simd.wast` `$nomerge` explicitly marks writes `1` / `2` as untangle, write `3` as merge-feeding, and write `5` as freshenable again before writes `6` / `7` merge | `local_graph_test.mbt` `marks only non-merge-feeding writes freshenable per original local`; GenValid `[SSANM-011c]` `ssa-mixed-fresh-canonical-writes` floor. `[SSANM-005c1]` adds focused planner coverage for one body local with two freshenable writes, two canonical merge-feeding writes, two retargeted gets, and one canonical merge get. `[SSANM-005c2]` adds public-pipeline coverage for a narrow normal `if`/`local.set` family that freshens only the planned non-merge writes and keeps the merge region canonical. `[SSANM-005c3a]` adds the matching narrow `local.tee` coverage and keeps tee admission intentionally small so larger artifact scratch/copy families stay on legacy helpers. `[SSANM-005c3b]` classifies `br_if` early exits as supported by this same normal-control path while plain `br` and `br_table` stay fail-closed. `[SSANM-005c3c]` classifies nested normal `block` / `if` as supported and loop-containing mixed regions as fail-closed. | `[SSANM-005c1]`, `[SSANM-005c2]`, and `[SSANM-005c3a]` through `[SSANM-005c3c]` are complete for the narrow mixed normal-control policy: `local.set`, small `local.tee`, `br_if` early exits, and nested normal `block` / `if` can use `structured-mixed-localgraph-plan`; plain `br`, `br_table`, loops, EH, typed control, and branch operands remain in `[SSANM-006a]` and `[SSANM-007*]` after `[SSANM-005b3]` classified the branch/table multi-source boundary. |
| Normal structured control mutation beyond simple `if`: `block`, `loop`, `br`, `br_if`, and `br_table` | Source contract comes from LocalGraph whole-function flow and `SSAify.cpp` using influenced gets rather than syntactic local pairs; dedicated no-merge WAST is mostly `if` plus calls, not exhaustive branch opcode coverage | `ssa_nomerge_test.mbt` has extensive current raw structured, branch, loop, typed-loop, and `br_table` guards; GenValid `[SSANM-011e]` floors branch-operand and nested-loop-target boundaries. `[SSANM-006a1]` adds value-carrying `br` / `br_table` fail-closed fixtures and maps current supported normal-flow reasons to raw helper ownership before mutation expands. | `[SSANM-006a1]` is complete as classification: supported LocalGraph reasons are narrow missing-else one-arm merges, simple both-arm/block-`br_if` multi-source merges, simple void-loop direct `br_if 0` backedge merges, narrow mixed `local.set` / small `local.tee` / `br_if` early-exit / nested normal `block` / `if` regions, and structured default materialization. Value-carrying `br` / `br_table`, plain `br`, table exits, typed branch operands, EH, and broader loop/nested-target families stay fail-closed for `[SSANM-006a2]`, `[SSANM-006a3a]` through `[SSANM-006a3d]`, and `[SSANM-007*]`. |
| No-merge must not externalize overlay phis through predecessor copies | `SSAify.cpp` returns from merge-local rewriting when `allowMerges` is false; full merge prepends/copies are sibling full-`ssa` behavior, not no-merge | Current `src/ir/ssa_destroy.mbt` and the HOT `ssa-nomerge` path still use predecessor-copy SSA destruction in some families; docs already flag this as the main local strategy mismatch. `[SSANM-007c]` moved full `ssa` merge-local follow-up work into sibling `[O4Z-AUDIT-SSA-FULL]` / `[SSA-FULL-*]` slices. | `[SSANM-006b]` is now child-sliced: `[SSANM-006b1]` inventories remaining copy-producing no-merge paths, `[SSANM-006b2a]` through `[SSANM-006b2d]` census and reroute ordinary LocalGraph-supported fallback survivors, and `[SSANM-006b3]` retires or narrows legacy helper/summaries. Full `ssa` merge materialization is no longer `SSANM` work. |
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

## `[SSANM-006b1]` predecessor-copy-producing path inventory

`[SSANM-006b1]` is a source/test inventory, not a mutation change. It separates three categories that future slices must not conflate:

| Category | Current path | Copy/proxy risk | Current owner |
| --- | --- | --- | --- |
| Ordinary LocalGraph-supported no-merge rewrites | Straight-line `straight-line-local-writes-localgraph-plan`, default materialization, canonical-only one-arm/multi-source/loop-backedge merge preservation, mixed normal-control `structured-mixed-localgraph-plan`, `[SSANM-006a2a]` ordinary `structured-localgraph-plan`, and `[SSANM-006a2b]` merge-adjacent ordinary `local.set` coverage | No predecessor-copy merge locals; fresh locals are planned per explicit write, merge reads stay canonical, and canonical-only paths return unchanged. | Completed `[SSANM-003a]` through `[SSANM-006a2b]`; `[SSANM-006a2c]` narrows the remaining legacy structured-helper ownership without changing behavior. |
| Fallback HOT SSA destruction | `src/passes/ssa_nomerge.mbt` still delegates to `@ir.ssa_destroy_into_hot(...)` after requiring CFG and local SSA when the raw dispatcher returns `None`. `src/ir/ssa_destroy.mbt` builds `copies_by_predecessor` and inserts predecessor-copy nodes. | This is the real predecessor-copy-producing path and remains inconsistent with Binaryen no-merge for any ordinary family that reaches it. | `[SSANM-006b2a]` first censuses ordinary fallback survivors, `[SSANM-006b2b]` locks straight-line/default families off the fallback, `[SSANM-006b2c]` reroutes any structured ordinary survivors, and `[SSANM-006b3]` should narrow summaries/helpers after rerouting. |
| Raw branch / typed-control scratch helpers | Branch-alias copies, br_table scratch/proxy branches, loop-param store/proxy lowerings, cast/null branch copy blocks, and branch-heavy scratch freshening in `src/passes/pass_manager.mbt`. | These allocate scratch/proxy locals or branch-local alias copies, but they are currently intentional Starshine boundary lowerings rather than ordinary no-merge predecessor-copy materialization. | `[SSANM-006b2d]` documents this boundary from the predecessor-copy-retirement perspective, while `[SSANM-006a3a]` through `[SSANM-006a3d]`, `[SSANM-007a*]`, `[SSANM-007b*]`, and huge/artifact slices decide which stay, move to typed/EH helpers, or become fail-closed. |

The inventory means the remaining predecessor-copy retirement work is not to delete all local allocation in `ssa-nomerge`; it is to prevent ordinary LocalGraph-supported local-source traffic from reaching HOT SSA destruction or branch/typed scratch helpers when Binaryen `SSAify(false)` would freshen single-source writes or preserve canonical merge reads directly. The 2026-06-14 split keeps that work in four smaller review units: fallback census, straight-line/default regression proof, structured ordinary rerouting, and boundary classification for scratch/proxy helpers.

## Starshine test map

| Local test surface | What it proves |
| --- | --- |
| `src/passes/ssa_nomerge_test.mbt:235` | `[SSANM-002a]` planner fixtures cover already-SSA straight-line locals, overwritten freshenable writes, parameter-entry and body-default reads, one-arm branch merges, loop-carried merges, no-read dead `local.set`, and dead `local.tee`. `[SSANM-002b]` adjacent test-only shadow helpers summarize planner freshen/retarget/default/keep counts and current output body-local/local-get shape for reduced fixtures, without changing pass mutation. `[SSANM-005c1]` adds a mixed-region planner summary fixture proving one original local can have freshened writes before/after a canonical merge region. `[SSANM-005a]` public-pipeline fixtures prove missing-else body-local/default and parameter-entry merges keep canonical slots without fresh merge locals or predecessor copies. `[SSANM-005b1]` public-pipeline fixtures prove simple both-arm and block/`br_if` multi-source merge gets keep the original body-local slot and trace the LocalGraph canonical-only merge path. `[SSANM-005b2]` public-pipeline coverage proves a simple void-loop `br_if 0` backedge merge stays canonical and traces `structured-loop-backedge-merge-localgraph-plan`. `[SSANM-005b3]` fail-closed public-pipeline fixtures prove plain `br` and `br_table` multi-source merge regions preserve their branch opcodes but do not claim the canonical-only or mixed LocalGraph path yet. `[SSANM-006a1]` adds fail-closed public-pipeline fixtures for value-carrying `br` and `br_table` operands, preserving their branch/table opcodes and keeping them off the canonical-only/mixed LocalGraph reasons. `[SSANM-005c2]` public-pipeline coverage proves a narrow mixed normal `if`/`local.set` region traces `structured-mixed-localgraph-plan`, freshens only the planned non-merge writes, and introduces no predecessor-copy merge local. `[SSANM-005c3a]` adds public-pipeline coverage proving the same mixed path retargets small `local.tee` freshenable writes while preserving tee stack results and canonical merge-feeding sets. |
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
