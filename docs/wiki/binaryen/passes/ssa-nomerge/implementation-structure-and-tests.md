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
| `src/passes/ssa_nomerge.mbt:15` | Summary/help text. `[SSANM-006b3b]` now describes Binaryen-style no-merge behavior (`Freshen single-source locals and materialize defaults while preserving merge traffic.`) instead of advertising predecessor-copy lowering as normal `ssa-nomerge` behavior. |
| `src/passes/ssa_nomerge.mbt:20` | `[SSANM-002a]` analysis-only `SsaNoMergeRewritePlan`: consumes `HotLocalGraph` to classify freshen/keep write decisions and retarget/default/keep get decisions without mutating the function. |
| `src/passes/ssa_nomerge.mbt:151` | Cheap local-write gate. |
| `src/passes/ssa_nomerge.mbt:34` | Rewrite-needed check over overlay phis and concrete local write defs. |
| `src/passes/ssa_nomerge.mbt:49` | Retained lifted HOT fallback wrapper; requires CFG and local SSA, then delegates to `@ir.ssa_destroy_into_hot(...)` only after the raw dispatcher does not return a handled result. `[SSANM-006b2*]` rerouted the ordinary completed no-merge families away from this predecessor-copy-producing bridge. |
| `src/ir/ssa_destroy.mbt:33` | `HotSsaDestroyPolicy`; current policy surface exposes `ReusePhiLocals`. |
| `src/ir/ssa_destroy.mbt:157` | Builds explicit predecessor-copy HOT nodes. |
| `src/ir/ssa_destroy.mbt:455` | Inserts predecessor copies at predecessor-block boundaries. |
| `src/ir/ssa_destroy.mbt:527` | `ssa_destroy_into_hot(...)`, the real lifted HOT SSA-destruction bridge used by the pass. |
| `src/passes/pass_manager.mbt:5768` | Raw default/local-read materialization helper. |
| `src/passes/pass_manager.mbt:5915` | Raw initialized-local seed logic. |
| `src/passes/pass_manager.mbt:6788` | Structured raw `ssa-nomerge` rewrite path. |
| `src/passes/pass_manager.mbt:6826` | Raw LocalGraph no-merge helpers. `[SSANM-003a]` made the straight-line `local.set` subset build and consume `SsaNoMergeRewritePlan`; `[SSANM-003b]` extended the same planned path to `local.tee` and removed the old straight-line alias heuristic; `[SSANM-004a]` uses the plan's `MaterializeDefault` get decisions for straight-line defaults and a narrow structured default-read subset before legacy structured rewriting; `[SSANM-004b]` routes no-local-write default reads through the same planned materializer and removes the duplicated raw default-only recursion; `[SSANM-005a]` recognizes simple missing-else one-arm entry/default merge plans as canonical-only and skips legacy structured rewriting with a dedicated trace reason; `[SSANM-005b1]` recognizes simple canonical-only multi-source merge plans for both-arm `if` and block/`br_if` shapes and skips legacy structured rewriting with `structured-multisource-merge-localgraph-plan`; `[SSANM-005b2]` recognizes simple void-loop direct `br_if 0` backedge canonical-only plans before the legacy loop-carried HOT defer and skips mutation with `structured-loop-backedge-merge-localgraph-plan`; `[SSANM-005b3]` keeps plain `br` and `br_table` multi-source merge regions off those planned LocalGraph reasons until branch/table helpers are narrowed; `[SSANM-005c2]` recognizes narrow mixed fresh/canonical normal `if`/`local.set` plans and recursively applies planned freshening/retargeting with `structured-mixed-localgraph-plan` while preserving canonical merge writes and reads; `[SSANM-005c3a]` lets the same structured mixed path handle small `local.tee` write sets while retaining larger tee-heavy artifact families on legacy scratch/copy helpers; `[SSANM-006a1]` records the current boundary map for these helpers, including fail-closed value `br` / `br_table` operands that must stay out of planned LocalGraph reasons until branch-operand helpers are narrowed; `[SSANM-006a2a]` adds the stricter `structured-localgraph-plan` path for ordinary normal `block` / `if` `local.set` freshening when the plan has single-source freshened writes and retargeted gets, while rejecting branches, returns, loops, EH, typed-control, `local.tee`, and trap boundaries; `[SSANM-006a2b]` adds explicit merge-adjacent ordinary `local.set` coverage through the existing `structured-mixed-localgraph-plan`; `[SSANM-006a2c]` narrows the remaining legacy `structured-local-writes` / `structured-local-writes-mutated` ownership to boundary-helper families rather than ordinary no-merge work; `[SSANM-006b2c3]` adds the explicit `structured-loop-backedge-boundary-noop` retained branch/table decoration boundary so those shapes also avoid lifted HOT predecessor-copy fallback. |
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

## `[SSANM-006b2c1]` / `[SSANM-006b2c2]` decorated loop-backedge fallback reroute

`[SSANM-006b2c1]` reduced one non-simple loop-carried fallback candidate to an ordinary void-loop `br_if 0` canonical merge whose loop body contains a branch-free `block` decoration before the backedge. The old simple direct-loop gate rejected the block, then `run_hot_pipeline_raw_ssa_nomerge_should_defer_loop_carried_br_if_to_hot(...)` returned `None`, so the public pass fell through to lifted HOT SSA destruction and created predecessor-copy-style extra locals. That shape is still Binaryen no-merge LocalGraph work: every merge read must stay on the original local, and no fresh merge local is needed.

`[SSANM-006b2c2]` admits only the narrow branch-free decoration subset. `run_hot_pipeline_raw_ssa_nomerge_loop_backedge_body_supported_control(...)` now tolerates branch-free block decorations via a dedicated decoration scan, but the scan still rejects nested branches, nested blocks, nested loops, `br_table`, typed ref/cast branches, and `try_table`. The existing canonical-only plan check is still required before the dispatcher returns `structured-loop-backedge-merge-localgraph-plan`, so the change reroutes only ordinary canonical merge preservation away from HOT SSA destruction; it does not introduce a new freshening or branch-helper mutation family.

| Reduced survivor | Classification | Proof / evidence |
| --- | --- | --- |
| Void-loop `br_if 0` canonical merge with branch-free block decoration before the backedge | Ordinary LocalGraph-supported no-merge work. The pass should return unchanged with `structured-loop-backedge-merge-localgraph-plan`, keeping entry/backedge writes and reads on the canonical local. | New red-first public-pipeline fixture `ssa-nomerge LocalGraph preserves decorated loop-carried br_if merge canonical`; it failed before implementation with three i32 locals, then passed with one local and no `pass[ssa-nomerge]:mutated` trace. Direct compare `.tmp/pass-fuzz-ssa-nomerge-006b2c-10000` requested 10000 cases, compared 9977, and had 9977 normalized matches with 0 mismatches; the 23 command failures were Binaryen/tool failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1). |
| Legacy structured helper rejection with branch/table, typed-control, or EH content | Retained boundary until `[SSANM-006b2c3]`: these shapes can require branch-alias, table, typed-control, or EH repair and should not be pulled into the ordinary loop-backedge decoration gate. | Covered by the existing branch/table/typed/EH boundary owners in `[SSANM-006a3*]`, `[SSANM-007a*]`, and `[SSANM-007b*]`; add fail-closed locks in `[SSANM-006b2c3]` only for reduced survivors that still risk HOT fallback. |
| Invalid-escape-carrier rejection when no default materialization changed the function | Retained fallback-risk boundary for `[SSANM-006b2c3]`. This slice did not broaden it because invalid lowered carriers are writeback/lowering safety failures, not ordinary LocalGraph local-source proof. | Existing skip-invalid-lower guards remain the safety net; a later slice should add a reduced trace lock or source-backed no-op reason before closing `[SSANM-006b2c]`. |

## `[SSANM-006b2c3]` / `[SSANM-006b2c4]` retained fallback boundary closeout

`[SSANM-006b2c3a]` closes the branch/table side of the retained structured fallback boundary. The branch-free decorated loop-backedge positive from `[SSANM-006b2c1]` / `[SSANM-006b2c2]` deliberately did not admit branch or table repair. Two reduced public-pipeline fixtures now lock that boundary: a decorated void-loop backedge whose decoration block contains a nested `br_if`, and the same family with nested `br_table` decoration. Both were red first: before the fix they rejected the canonical loop-backedge LocalGraph gate, reached lifted HOT SSA destruction, and reported `pass[ssa-nomerge]:mutated`. The dispatcher now recognizes these loop-carried branch/table decoration survivors and returns the original function unchanged with `structured-loop-backedge-boundary-noop`; the tests also reject `structured-localgraph-plan`, `structured-mixed-localgraph-plan`, `structured-multisource-merge-localgraph-plan`, and `structured-loop-backedge-merge-localgraph-plan` so the no-op cannot be confused with an ordinary LocalGraph success.

`[SSANM-006b2c3b]` keeps invalid lowered carriers as a source-backed lowering/writeback safety boundary. In `src/passes/pass_manager.mbt`, the raw structured route checks `run_hot_pipeline_precompute_lowered_func_has_invalid_escape_carrier(...)` after rewriting: if default materialization already made a safe change, the pass can return that default-only rewrite; otherwise it returns `None`. The generic `ssa-nomerge` writeback skip guard checks the same invalid-carrier predicate again before validation. That path is intentionally not classified as ordinary Binaryen no-merge local-source traffic because the detector matches lowered block/carrier structure and prevents unsafe writeback, not a stable source-WAT family that should be rerouted through LocalGraph mutation.

`[SSANM-006b2c4]` closes the structured fallback reroute subtrack with this policy:

| Retained / admitted family | Current decision | Reopening criteria |
| --- | --- | --- |
| Branch-free decorated void-loop `br_if 0` canonical merges | Admitted as ordinary canonical no-merge work with `structured-loop-backedge-merge-localgraph-plan`; no predecessor-copy HOT fallback. | Reopen only if a reduced fixture shows a different ordinary branch-free decoration still falls to HOT SSA destruction or creates merge locals. |
| Branch/table-decorated loop-carried boundary shapes | Preserve unchanged with `structured-loop-backedge-boundary-noop`; they are branch/table helper boundary owners, not ordinary planned LocalGraph successes. | Admit a narrower branch/table mutation only with red-first positive tests proving no branch-alias/table-target repair is bypassed, then run direct `--pass ssa-nomerge` compare. |
| Typed-control, ref/cast branch, EH, and no-throw typed-helper containers | Stay under `[SSANM-007a*]` / `[SSANM-007b*]` boundary ownership and existing focused locks. | Reopen through those owners with source-backed ABI proof, validation, and direct compare if behavior changes. |
| Invalid lowered escape carriers | Retained as writeback/lowering safety boundaries rather than ordinary no-merge predecessor-copy materialization. | Add a stable reduced lowered-HOT or source-WAT fixture if one appears; do not route through ordinary LocalGraph gates without proving the lowered carrier validates after rewrite. |

The closeout unblocks `[SSANM-006b3]`: remaining predecessor-copy retirement should now inventory and narrow wording/helper surfaces, not continue treating structured ordinary fallback survivors as open unless a new reduced ordinary family is found. Behavior-changing boundary reroutes require the ordinary 10000-case direct `--pass ssa-nomerge` compare lane.

Validation for the behavior change: focused `ssa_nomerge_test.mbt` failed red-first on both branch/table decorated-loop boundary fixtures with `pass[ssa-nomerge]:mutated`; after implementation, focused `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt` passed `425/425`, `moon test src/passes` passed `2455/2455`, full `moon test` passed `5760/5760`, native `src/cmd` build passed, and direct compare `.tmp/pass-fuzz-ssa-nomerge-006b2c-boundary-final-10000` requested 10000 cases with `--jobs auto` and the prebuilt native Starshine binary, compared 9977, had 9977 normalized matches, 0 mismatches, and 23 Binaryen/tool command failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1).

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

## `[SSANM-006b3]` predecessor-copy wording and helper reachability closeout

`[SSANM-006b3a]` inventoried the remaining predecessor-copy surfaces after ordinary structured fallback rerouting. The conclusion is that the phrase still belongs to the shared HOT SSA destruction implementation and full-`ssa` sibling work, but it should no longer be advertised as normal public `ssa-nomerge` behavior.

| Surface | Current reachability / meaning | Decision |
| --- | --- | --- |
| `ssa_nomerge_summary()` / registry help text | Public summary still described lowering overlay phis through predecessor copies even after the ordinary no-merge families were rerouted to LocalGraph-planned reasons or explicit boundaries. | `[SSANM-006b3b]` rewrites the summary to describe the intended no-merge behavior: freshen single-source locals, materialize defaults, and preserve merge traffic. A registry test locks the new wording. |
| Retained lifted HOT fallback (`ssa_nomerge_run(...)` -> `ssa_destroy_into_hot(...)`) | Source-reachable only after the raw dispatcher does not return a handled no-merge result and after HOT boundary guards allow the function. It remains the predecessor-copy-producing implementation, but `[SSANM-006b2*]` moved completed ordinary straight-line/default/structured families away from it. | Keep as a retained fallback risk / sibling-SSA implementation surface for now; do not call it ordinary `ssa-nomerge` behavior. Any new ordinary fallback survivor should be reduced under the appropriate SSANM slice before admission. |
| `src/ir/ssa_destroy.mbt` predecessor-copy helpers | Shared local-SSA destruction machinery used by the retained HOT bridge and by sibling full-`ssa` planning. | Keep the helpers; they are not removed by predecessor-copy retirement because they are still valid outside ordinary no-merge LocalGraph work. |
| Raw branch/table/typed/EH copy-like helpers | Branch aliases, `br_table` scratches/proxies, typed loop-param/result stores, null/cast branch spills, and no-throw `try_table` repairs remain explicitly classified in `[SSANM-006b2d]`, `[SSANM-007a*]`, and `[SSANM-007b*]`. | Keep names/traces such as `structured-local-writes-mutated` for these boundary helpers, but document them as branch/table/typed/EH ABI repair rather than Binaryen no-merge predecessor-copy materialization. |
| Stale wiki wording on the HOT-IR strategy page | The 2026-05 text accurately described the old implementation strategy but became misleading as a current public behavior summary after the LocalGraph reroutes. | `[SSANM-006b3c]` refreshes the page to mark the HOT bridge as retained fallback/history and links this implementation map as the current owner table. |

Validation: the red-first registry test in `src/passes/registry_test.mbt` failed while `ssa_nomerge_summary()` still returned `Untangle hot locals into semi-SSA form and lower overlay phis through predecessor copies.` After the summary change, focused `moon test --package jtenner/starshine/passes --file registry_test.mbt` passed `6/6`. Direct compare was not run for this closeout because it changes registry/help wording and docs only; no pass mutation, trace routing, or wasm output changed.

Reopening criteria: reopen `[SSANM-006b]` only if an ordinary LocalGraph-supported family again reaches lifted HOT SSA destruction, if public docs/help reintroduce predecessor copies as normal no-merge behavior, or if a retained boundary helper is broadened without a red-first fixture and direct `--pass ssa-nomerge` compare evidence.

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
| Value-carrying `br` / `br_if` exits to typed blocks or loops | Branch-alias / typed-control ABI helper or fail-closed boundary. Value operands are stack/control payloads and should not be admitted to ordinary LocalGraph local-source rewrites without a branch-operand repair proof. | `run_hot_pipeline_raw_rewrite_br_if(...)`, `run_hot_pipeline_raw_append_alias_merge_copies_for_needed(...)`, and `[SSANM-006a1]` / `[SSANM-006a3b]` value/plain branch fail-closed tests. `[SSANM-007b3a]` now locks direct `br` and conditional `br_if` value operands with validation plus trace rejection of ordinary planned structured LocalGraph reasons. |
| Value-carrying `br_table` exits and table mixes | Table-target ABI helper or fail-closed boundary. Selector locals, scratch branches, and target relabeling preserve branch payloads and mixed table targets. | `run_hot_pipeline_raw_br_table_alias_copies(...)`, mixed table proxy/store helpers, and tests `ssa-nomerge keeps value br_table operands off LocalGraph path`, `ssa-nomerge keeps mixed-target value br_table operands off LocalGraph path`, `ssa-nomerge rewrites ... typed loop br_table ...`, and non-current/mixed-target `br_table` families. `[SSANM-007b3b]` locks value table operands that are separate from typed-loop table helpers. |
| `br_on_null` / `br_on_non_null` with loop-param targets | Typed branch helper. The helpers spill/test nullable or non-null reference payloads, run branch-local copies only on the taken edge, and reload prefix/loop-param scratches on fallthrough as needed. | `run_hot_pipeline_raw_rewrite_loop_param_store_br_on_null(...)`, `run_hot_pipeline_raw_rewrite_loop_param_store_br_on_non_null(...)`, `run_hot_pipeline_raw_rewrite_br_on_null(...)`, `run_hot_pipeline_raw_rewrite_br_on_non_null(...)`, and scalar/multi-param/no-copy/copy-needing `br_on_null` and `br_on_non_null` typed-loop tests. `[SSANM-007b3c]` now locks representative no-copy, copy-needing/prefix, and non-null raw-path cases with validation plus ordinary planned structured LocalGraph reason rejection. |
| Prefix-payload, tested-producer, and store-model ref branch inputs | Typed branch operand spill model. Supported trailing producers (`local.get`, `local.tee`, `ref.null`, `ref.cast`, conversions, `ref.i31`, `ref.func`, struct/array constructors, and selected calls) are evaluated once and spilled before the branch rewrite; unsupported producer scans stay fail-closed. | `run_hot_pipeline_raw_spill_trailing_ref_branch_input(...)`, `run_hot_pipeline_raw_trailing_ref_branch_input_needs_single_spill_for_non_null(...)`, and tests for ref-null/ref-cast/ref-i31/ref-func/struct/array/new-data/new-elem/local-tee/direct-call/call_ref/call_indirect branch inputs. `[SSANM-007b3c]` strengthens local-tee tested producer coverage through the same null-branch boundary helper. |
| `br_on_cast` / `br_on_cast_fail` loop-param backedges | Typed cast-branch helper. Cast branches lower through source/fallthrough scratches and inverse cast blocks so branch-local alias copies run only on the semantically taken edge. | `run_hot_pipeline_raw_rewrite_loop_param_store_cast_branch(...)`, `run_hot_pipeline_raw_rewrite_loop_param_store_br_on_cast(...)`, `run_hot_pipeline_raw_rewrite_loop_param_store_br_on_cast_fail(...)`, loop-param proxy cast-copy helpers, and tests `multi-param typed loop br_on_cast backedges`, `copy-needing ... br_on_cast ...`, and `copy-needing ... br_on_cast_fail ...`. `[SSANM-007b3d]` now locks representative no-copy, divergent-alias, multi-result, and typed-loop cast/fail exits with validation plus ordinary planned structured LocalGraph reason rejection. |
| No-throw `try_table` wrappers around typed branch/loop helpers | Typed-control helper through an EH container, not real EH SSA and not ordinary LocalGraph local-source mutation. | `[SSANM-007a3]` no-throw `try_table` table plus typed-loop `try_table` tests. `[SSANM-007b2]` / `[SSANM-007b3]` should classify the typed ABI behavior; real EH remains closed by `[SSANM-007a]`. |

### `[SSANM-007b1c]` closeout / handoff to boundary locks

Inventory conclusion: the current typed-control surface is already broad, but it is intentionally broad as raw ABI repair around typed stack/control constructs. `[SSANM-007b2]` should now lock loop-param/result behavior with focused trace/output assertions that distinguish proxy/store/no-copy cases from ordinary LocalGraph local-source rewrites. `[SSANM-007b3]` should do the same for typed branch operands, `br_table`, `br_on_*`, and cast/null exits. Any future admission of a typed-control family to ordinary planned LocalGraph mutation needs red-first positive fixtures plus direct `--pass ssa-nomerge` compare evidence; this inventory changed no executable behavior, so direct compare was not required.

## `[SSANM-007b2]` typed loop/result executable boundary locks

`[SSANM-007b2a]` through `[SSANM-007b2d]` strengthened existing executable locks without changing pass behavior. The shared trace assertions in `src/passes/ssa_nomerge_test.mbt` require typed loop-param proxy/store-model/table/nested-target rewrites to report `structured-local-writes-mutated`, while no-copy typed-loop-param fixtures must avoid both mutation and the legacy structured local-write raw reasons. That keeps copy/proxy/store/table scratches classified as typed-control ABI repair, not ordinary planned LocalGraph local-source mutation and not no-merge predecessor-copy materialization.

| Boundary family | Locked behavior | Proof surface |
| --- | --- | --- |
| Scalar typed loop params with direct `br`, scalar `br_if`, numeric variants, nested scalar `br_if`, and copy-needing scalar/reference `br_if` | The scalar proxy helper remains the owner when a loop-carried overwrite or edge copy is required. The trace/output lock requires the typed-control raw-helper reason plus the scalar proxy shape. | `ssa_test_expect_scalar_loop_param_branch_proxy(...)` now captures trace and validates `structured-local-writes-mutated`; tests such as `ssa-nomerge rewrites direct scalar typed loop-param br backedge`, `ssa-nomerge rewrites no-copy scalar typed loop-param br_if backedge`, numeric variants, nested scalar, copy-needing scalar, nullable reference, non-null reference, and copy-needing reference variants consume it. |
| No-copy typed-loop-param fixtures | No scratch/proxy allocation is allowed when there is no overwrite or edge-copy need. These are explicit no-mutation boundaries, not failed proxy rewrites. | `ssa_test_no_copy_typed_loop_param_module_no_mutation(...)` now also asserts the trace does not report `structured-local-writes` / `structured-local-writes-mutated`, in addition to rejecting `pass[ssa-nomerge]:mutated`. |
| Multi-param no-result loops and single-result loop/result-store models | Store-model and result ABI repair helpers remain typed-control territory. The trace/output lock requires the typed-control raw-helper reason plus the scratch/store backedge shape. | `ssa_test_expect_loop_param_store_model(...)` validates output and `structured-local-writes-mutated` trace for `multi-param typed loop direct br backedges`, `multi-param typed loop br_if backedges`, `single-result typed loop direct br backedges`, `single-result typed loop br_if backedges`, and `multi-param single-result typed loop br_table backedges`. |
| Typed-loop `br_table` and nested-target boundaries | Table selector/scratch/proxy helpers and nested loop-target gates remain typed-control/table ABI repair. Current-loop, mixed current/enclosing, non-current/nested, copy-needing, single-result, reference, no-throw `try_table`, and nested-loop target shapes must trace the typed-control raw-helper reason before asserting the table/proxy/store output shape. | `ssa_test_expect_typed_loop_boundary_output(...)`, `ssa_test_expect_typed_loop_module_boundary_output(...)`, and `ssa_test_expect_loop_param_br_table_proxy(...)` validate output and `structured-local-writes-mutated` trace for scalar/copy-needing/multi-param typed-loop `br_table`, mixed-target and non-current table targets, no-throw `try_table` table variants, reference table params, mixed scalar table+`br_if`, and nested loop target fixtures. |

These locks are regression/classification coverage over existing behavior. They did not admit a new mutation family, so direct compare was not rerun for `[SSANM-007b2a]` through `[SSANM-007b2d]`. Reopen typed loop/result mutation only with red-first behavior fixtures plus direct `--pass ssa-nomerge` compare evidence if a later slice admits a new table/nested-target mutation family. `[SSANM-007b3]` remains open for typed branch operand, `br_on_*`, and cast/null exit classification.

## `[SSANM-007b3a]` / `[SSANM-007b3b]` typed branch operand executable locks

`[SSANM-007b3a]` and `[SSANM-007b3b]` strengthen the existing value-branch boundary tests without changing pass behavior. The shared `ssa_test_expect_value_branch_boundary_output(...)` helper runs the public pipeline with trace capture, validates the rewritten module, rejects all ordinary planned structured LocalGraph reasons, and returns the first function body for opcode-shape assertions. These branch operands remain typed-control / branch-table ABI surfaces, not ordinary LocalGraph local-source no-merge mutation.

| Boundary family | Locked behavior | Proof surface |
| --- | --- | --- |
| Direct value-carrying `br` to a result block | The branch payload and local writes validate while the public pipeline stays off `structured-localgraph-plan`, `structured-mixed-localgraph-plan`, `structured-multisource-merge-localgraph-plan`, and `structured-loop-backedge-merge-localgraph-plan`. | `ssa-nomerge keeps value br operands off LocalGraph path` now uses the shared trace/validation helper and preserves the `br` opcode. |
| Conditional value-carrying `br_if` | The stack payload plus condition stay on the branch-operand boundary rather than the ordinary planned LocalGraph paths. | `ssa-nomerge keeps value br_if operands off LocalGraph path` validates the conditional value branch and preserves `br_if`. |
| Value-carrying `br_table` with selector payload | Selector/result ABI repair remains table-helper territory and is not counted as ordinary no-merge freshening. | `ssa-nomerge keeps value br_table operands off LocalGraph path` now uses the shared trace/validation helper and preserves `br_table`. |
| Mixed-target value-carrying `br_table` | Multiple result labels plus a selector remain fail-closed from ordinary planned structured LocalGraph mutation until table scratch ownership is narrowed. | `ssa-nomerge keeps mixed-target value br_table operands off LocalGraph path` validates the mixed-target value table and preserves `br_table`. |

These are regression/classification locks over existing fail-closed routing. Direct compare was not rerun because no pass behavior changed and no new mutation family was admitted. `[SSANM-007b3c]` later locked `br_on_null` / `br_on_non_null`; `[SSANM-007b3d]` later locked cast-branch exits and closed typed branch classification.

## `[SSANM-007b3c]` null/non-null typed-exit executable locks

`[SSANM-007b3c1]` through `[SSANM-007b3c4]` strengthen representative `br_on_null` / `br_on_non_null` fixtures without changing pass behavior. The shared `ssa_test_expect_null_branch_boundary_module_output(...)` helper runs the public pipeline with trace capture, validates the output module, rejects ordinary planned structured LocalGraph reasons, and returns the requested defined function body for typed-branch shape assertions.

| Boundary family | Locked behavior | Proof surface |
| --- | --- | --- |
| No-copy nullable reference `br_on_null` loop-param backedge | The typed loop-param null proxy remains the owner, validates, preserves the null branch opcode where no scratch branch rewrite is needed, and stays off ordinary planned structured LocalGraph reasons. | `ssa-nomerge rewrites no-copy br_on_null typed loop-param backedge` now uses the shared null-branch helper and asserts the loop-param null proxy plus `br_on_null` opcode shape. |
| Prefix/copy-needing nullable reference `br_on_null` backedge | Prefix locals and taken-edge branch copies stay typed-control ABI repair, not generic LocalGraph local-source freshening. | `ssa-nomerge rewrites copy-needing br_on_null typed loop-param backedge` now validates through the shared helper, rejects planned structured LocalGraph reasons, and keeps the null-taken copy / `ref.as_non_null` repair shape. |
| Non-null reference `br_on_non_null` raw-path boundary | The raw structured helper may allocate the existing temp-local repair shape, but it does not claim `structured-localgraph-plan`, `structured-mixed-localgraph-plan`, `structured-multisource-merge-localgraph-plan`, or the loop-backedge LocalGraph reason. | `ssa-nomerge preserves no-copy br_on_non_null on raw path` now validates the module, rejects planned structured LocalGraph reasons, and preserves the `br_on_non_null` opcode while checking the temp-local writes. |
| Tested local-tee reference producers | Supported local-tee tested producers remain typed branch-producer handling through the null/non-null store model rather than ordinary LocalGraph mutation. | `ssa-nomerge rewrites local-tee-tested multi-param typed loop br_on_null backedges` and `... br_on_non_null backedges` now use the shared helper before asserting the store-backedge output shape. |

These locks are regression/classification coverage over existing typed branch behavior. Direct compare was not rerun because no pass behavior changed and no new mutation family was admitted. `[SSANM-007b3d]` later closed `br_on_cast` / `br_on_cast_fail` classification and typed-branch closeout.

## `[SSANM-007b3d]` cast-branch typed-exit executable locks

`[SSANM-007b3d1]` through `[SSANM-007b3d4]` strengthen representative `br_on_cast` / `br_on_cast_fail` fixtures without changing pass behavior. The new `ssa_test_expect_cast_branch_boundary_module_output(...)` helper runs the public pipeline with trace capture, validates the output module, rejects ordinary planned structured LocalGraph reasons, rejects `hot-lift-error`, and returns the requested defined function body plus trace for mutation/no-mutation assertions.

| Boundary family | Locked behavior | Proof surface |
| --- | --- | --- |
| No-copy raw-path `br_on_cast` and `br_on_cast_fail` exits | The cast branch opcodes and existing temp-local repair shape validate while staying off `structured-localgraph-plan`, `structured-mixed-localgraph-plan`, `structured-multisource-merge-localgraph-plan`, and `structured-loop-backedge-merge-localgraph-plan`. | `ssa-nomerge preserves no-copy br_on_cast on raw path` and `ssa-nomerge preserves no-copy br_on_cast_fail on raw path` now use the shared cast-branch helper before asserting opcode/temp-local shape. |
| Divergent-alias and multi-result cast exits | Taken-edge scratch copy blocks remain typed branch ABI repair so canonical alias copies run only on the semantic cast/fail edge. | `ssa-nomerge rewrites br_on_cast taken-edge copies after divergent aliases`, `ssa-nomerge rewrites multi-result br_on_cast taken-edge copies`, and their `br_on_cast_fail` variants validate through the shared helper, require mutation, reject ordinary planned structured reasons, and keep the inverse-cast copy block shape. |
| Typed-loop cast/fail backedges | Multi-param store-model, no-copy loop-target proxy, and copy-needing loop-target repairs remain typed-control loop ABI surfaces rather than ordinary LocalGraph local-source mutation. | The multi-param typed-loop cast/fail fixtures now use the shared helper before asserting store-backedge/copy-block shapes; no-copy loop-target cast/fail fixtures validate, reject planned structured reasons, require no pass mutation, and preserve loop-param cast proxy shape; copy-needing loop-target fixtures require mutation and preserve the branch-copy block shape. |

These locks are regression/classification coverage over existing typed branch behavior. Direct compare was not rerun because no pass behavior changed and no new mutation family was admitted. Reopen cast branch mutation only with red-first behavior fixtures plus direct `--pass ssa-nomerge` compare evidence if a later slice admits a new cast-branch mutation family.

## `[SSANM-008a]` huge-function replay anchor refresh

`[SSANM-008a]` is an anchor/source replay slice, not a policy change. It refreshes the checked-in debug-WASI direct `ssa-nomerge` trace before any LocalGraph-planner or threshold work in `[SSANM-008b]` through `[SSANM-008d]`.

Direct traced replay command:

```sh
target/native/release/build/cmd/cmd.exe --debug-serial-passes --tracing pass --ssa-nomerge \
  --out .tmp/ssa-nomerge-huge-anchor-refresh-20260614/starshine.wasm \
  tests/node/dist/starshine-debug-wasi.wasm
```

The command exited `0`, and `wasm-tools validate --features all .tmp/ssa-nomerge-huge-anchor-refresh-20260614/starshine.wasm` passed. The trace had `0` `skip-invalid-lower` lines. It now has six `large-structured-local-writes` skips, not the nine older anchors recorded before the 2026-06-14 refresh:

| Prior anchor | Extracted function name | Current full-artifact status | Extracted replay status | Next owner |
| --- | --- | --- | --- | --- |
| `Func 265` | `_M0FP37jtenner9starshine6passes22dae__run__core_2einner` | No longer appears as `large-structured-local-writes` in the full trace. | Validates under `.tmp/ssanm008a-huge-functions-20260614/func265`; traces `multiparam-value-if-branch-carrier-noop`, not the huge guard. | Keep as a drifted non-huge boundary for `[SSANM-008b]` planner/boundary classification only if needed. |
| `Func 3518` | `_M0FP37jtenner9starshine4wast17wt__lower__module` | No longer appears as `large-structured-local-writes` in the full trace. | Validates under `.tmp/ssanm008a-huge-functions-20260614/func3518`; traces `branch-heavy-void-loop-exit-mesh-noop`, not the huge guard. | Keep as a drifted non-huge boundary for `[SSANM-008b]` planner/boundary classification only if needed. |
| `Func 3536` | `_M0FP37jtenner9starshine4wast18wt__instr__to__lib` | Still huge: `instrs=16195`, `locals=2871`. | Validates under `.tmp/ssanm008a-huge-functions-20260614/func3536`; extracted root still hits `large-structured-local-writes` (`Func 168`, `16604` instrs / `3059` locals). | `[SSANM-008b]` LocalGraph plan counts, then `[SSANM-008c]` admission/narrowing decision. |
| `Func 3781` | `_M0FP37jtenner9starshine6binary32decode__instruction__with__depth` | Still huge: `instrs=39283`, `locals=6634`. | Validates under `.tmp/ssanm008a-huge-functions-20260614/func3781`; extracted root still hits `large-structured-local-writes` (`Func 610`, `40703` instrs / `7344` locals). | `[SSANM-008b]` / `[SSANM-008c]`. |
| `Func 3885` | `_M0IP37jtenner9starshine3lib11InstructionP37jtenner9starshine6binary6Encode6encode` | Still huge: `instrs=26350`, `locals=3879`. | Validates under `.tmp/ssanm008a-huge-functions-20260614/func3885`; extracted root still hits `large-structured-local-writes` (`Func 42`, `26478` instrs / `4056` locals). | `[SSANM-008b]` / `[SSANM-008c]`. |
| `Func 4119` | `_M0IP37jtenner9starshine3lib11InstructionP37jtenner9starshine8validate9Typecheck9typecheck` | Still huge: `instrs=9458`, `locals=1332`. | Validates under `.tmp/ssanm008a-huge-functions-20260614/func4119`; extracted root still hits `large-structured-local-writes` (`Func 125`, `9673` instrs / `1437` locals). | `[SSANM-008b]` / `[SSANM-008c]`. |
| `Func 4522` | `_M0IP37jtenner9starshine3lib11InstructionPB4Show6output` | No longer appears as `large-structured-local-writes` in the full trace. | Validates under `.tmp/ssanm008a-huge-functions-20260614/func4522`; traces `branch-heavy-void-loop-exit-mesh-noop`, not the huge guard. | Keep as a drifted non-huge boundary for `[SSANM-008b]` planner/boundary classification only if needed. |
| `Func 5417` | `_M0IP37jtenner9starshine3lib11InstructionPC15debug5Debug8to__repr` | Still huge: `instrs=19507`, `locals=3524`. | Validates under `.tmp/ssanm008a-huge-functions-20260614/func5417`; extracted root still hits `large-structured-local-writes` (`Func 39`, `19787` instrs / `3664` locals). | `[SSANM-008b]` / `[SSANM-008c]`. |
| `Func 5419` | `_M0IP37jtenner9starshine3lib11InstructionPB2Eq5equal` | Still huge: `instrs=15300`, `locals=2313`. | Validates under `.tmp/ssanm008a-huge-functions-20260614/func5419`; extracted root still hits `large-structured-local-writes` (`Func 35`, `16162` instrs / `2744` locals). | `[SSANM-008b]` / `[SSANM-008c]`. |

Self-compare artifact replay also refreshed the current first-diff anchor:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-huge-anchor-refresh-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge
```

It validated both outputs, remained non-equal, and now first-diffs at `defined=108 abs=135`. Starshine output was smaller (`3155453` bytes versus Binaryen `3155990`), pass-local timing was reported as Starshine `0.225ms` versus Binaryen `375.105ms`, and whole-command Starshine runtime remained slower. This is not a behavior-parity or scheduling closeout; it only refreshes the replay anchors. Direct `--pass ssa-nomerge` compare was not rerun because no pass mutation, dispatch policy, trace reason, or wasm output implementation changed in this slice.

## `[SSANM-008b]` huge-function LocalGraph plan classification

`[SSANM-008b]` is a no-mutation classification slice. It used the refreshed extracted-function anchors from `[SSANM-008a]`, built a temporary native debug helper to append LocalGraph no-merge plan counts to the existing trace reasons, replayed each extracted module, validated every rewritten output, and then removed the helper before committing. The resulting evidence lives under `.tmp/ssanm008b-plan-classification-20260614/plan-trace-lines.txt`.

Command shape for each extracted function:

```sh
target/native/release/build/cmd/cmd.exe --debug-serial-passes --tracing pass --ssa-nomerge \
  --out .tmp/ssanm008b-plan-classification-20260614/funcNNNN.wasm \
  .tmp/ssanm008a-huge-functions-20260614/funcNNNN/extracted.wasm
wasm-tools validate --features all .tmp/ssanm008b-plan-classification-20260614/funcNNNN.wasm
```

| Prior anchor | Boundary / skip reason | Extracted instrs / locals | Planned writes | Freshenable writes | Merge-feeding canonical writes | Other canonical writes | Tee writes / freshenable tees | Planned gets | Retarget gets | Default-entry reads | Param-entry reads | Merge reads | Classification |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `Func 265` | `multiparam-value-if-branch-carrier-noop` | — | 1362 | 469 | 0 | 893 | 434 / 264 | 3608 | 0 | 0 | 117 | 0 | Drifted non-huge typed/value-if boundary; keep out of huge-threshold admission work. |
| `Func 3518` | `branch-heavy-void-loop-exit-mesh-noop` | — | 1703 | 1563 | 0 | 140 | 809 / 776 | 2951 | 0 | 0 | 1 | 0 | Drifted non-huge branch-heavy mesh boundary; planner sees many freshenable writes but the current boundary is control-shape, not local-source policy. |
| `Func 3536` | `large-structured-local-writes` | 16604 / 3059 | 3080 | 2786 | 0 | 294 | 1652 / 1567 | 4980 | 0 | 0 | 1 | 0 | Size-threshold boundary with mostly freshenable write-only/local-source traffic; candidate for `[SSANM-008c]` only after timing and validation replay. |
| `Func 3781` | `large-structured-local-writes` | 40703 / 7344 | 7341 | 7337 | 0 | 4 | 3211 / 3209 | 12871 | 0 | 0 | 5 | 0 | Size-threshold boundary; nearly every write is planner-freshenable, but no threshold/policy change was made. |
| `Func 3885` | `large-structured-local-writes` | 26478 / 4056 | 4054 | 4052 | 0 | 2 | 2352 / 2351 | 7317 | 0 | 0 | 0 | 0 | Size-threshold boundary; almost purely freshenable write traffic. |
| `Func 4119` | `large-structured-local-writes` | 9673 / 1437 | 1436 | 1288 | 0 | 148 | 439 / 395 | 3170 | 0 | 0 | 1 | 0 | Size-threshold boundary with a moderate canonical-write minority. |
| `Func 4522` | `branch-heavy-void-loop-exit-mesh-noop` | — | 1123 | 1091 | 0 | 32 | 411 / 403 | 4433 | 0 | 0 | 1 | 0 | Drifted non-huge branch-heavy mesh boundary; not a huge-threshold candidate unless a later branch-heavy slice narrows the control mesh. |
| `Func 5417` | `large-structured-local-writes` | 19787 / 3664 | 3663 | 2163 | 0 | 1500 | 1270 / 744 | 5783 | 0 | 0 | 1 | 0 | Size-threshold boundary with the largest canonical-write minority; needs extra scrutiny before any admission. |
| `Func 5419` | `large-structured-local-writes` | 16162 / 2744 | 2742 | 2742 | 0 | 0 | 1038 / 1038 | 4753 | 0 | 0 | 1 | 0 | Size-threshold boundary; all writes are planner-freshenable in the extracted replay. |

The planner found no merge-feeding canonical writes and no merge reads in these extracted roots. That means the remaining six huge guards are not blocked by the no-merge decision table itself; they are blocked by the raw structured size/performance guard. `[SSANM-008c]` should therefore decide whether to admit a narrow size-threshold subset, and `[SSANM-008d]` must measure pass-local cost before closing the huge-function family. The three drifted old anchors should stay out of `[SSANM-008c]` threshold admission because their current owners are `multiparam-value-if-branch-carrier-noop` or `branch-heavy-void-loop-exit-mesh-noop`, not `large-structured-local-writes`.

Direct `--pass ssa-nomerge` compare was not rerun for `[SSANM-008b]` because the slice left no pass mutation, no committed trace/dispatch change, and no wasm output change. The native build and extracted replay validation were the relevant proof surface.

## `[SSANM-009b1]` debug-WASI stack-carried tee/default-read fix

`[SSANM-009b1]` reduces and fixes the former checked-in debug-WASI first diff `defined=108 abs=135` from `.tmp/self-ssa-nomerge-debug-wasi-anchor-refresh-20260614`.

The reduced raw stack shape is straight-line:

1. produce a value that remains on the operand stack;
2. run a void, decref-like call;
3. `local.tee` the still-live stack value into a body local;
4. consume that tee value in a later call.

Before this slice, the LocalGraph plan freshened the stack-carried `local.tee`, but the later read of the original tee target could still arrive as `MaterializeDefault`; the raw straight-line rewriter therefore emitted `i32.const 0` before the later decref-like call. Binaryen preserves the value by reading the fresh tee local. Starshine now keeps a straight-line `fresh_aliases` table while consuming the plan: if a later `MaterializeDefault` decision names a local whose latest straight-line write was just freshened, the rewriter emits `local.get` of that fresh local instead of the default. Canonical writes clear the alias.

The focused test is `ssa-nomerge LocalGraph straight-line stack-carried tee keeps later gets live` in `src/passes/ssa_nomerge_test.mbt`. It was red first: focused file test failed `425/426` because the output had `i32.const 0` where the fixture required `local.get 4`. After the fix, focused file tests passed `426/426`.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b-stack-tee-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Self-compare validates both outputs and moves the first artifact diff to `defined=215 abs=242`. Starshine size remains `3155453` bytes versus Binaryen `3155990`; pass-local timing is Starshine `0.210ms` versus Binaryen `378.479ms`. Whole-command runtime is still much slower (`60510.841ms` versus `819.847ms`) and remains `[WALL]001` unless later evidence proves an SSANM-local owner. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1) with persistent-cache hits.

Agent classification: `defined=108 abs=135` was a true straight-line behavior-parity gap and is fixed. The `defined=215 abs=242` first diff later became `[SSANM-009b2]` and is now fixed; the current first diff is `defined=363 abs=390` under `[SSANM-009b3]`.

## `[SSANM-009b2]` debug-WASI unwritten fresh-local carrier fix

`[SSANM-009b2]` reduces and fixes the post-`[SSANM-009b1]` checked-in debug-WASI first diff `defined=215 abs=242` from `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b-20260614`.

The reduced standalone fixture preserves the `run_hot_pipeline::flush_hot_passes` branch/value-carrier shape: a legacy raw structured rewrite freshens branch-carried aliases inside result-typed block/`if` nests, then the artifact path reads an appended fresh local after the carrier block. Before this slice the emitted module validated, but the reduced output read appended locals such as `local 79` and `local 84` that had no corresponding write in the function. That is a true behavior/safety gap, not harmless local-numbering drift.

Starshine now rejects legacy raw structured rewrites that would read an appended local with no write anywhere in the rewritten function. Original parameter/body locals are treated as pre-existing for this guard, so default-entry reads of original locals remain owned by the existing default-materialization paths; the new check only catches fresh alias plans that are internally inconsistent. The value-if scratch freshener was also narrowed to original body locals so it cannot double-freshen fresh aliases introduced earlier by the raw rewrite.

The focused test is `ssa-nomerge artifact value-if carrier does not read unwritten fresh locals` in `src/passes/ssa_nomerge_test.mbt`. It was red first: focused file test failed `426/427` with `local.get 79` of an appended local that had no write in the reduced standalone fixture. After the fix, focused file tests passed `427/427`.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b2-unwritten-fresh-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b2-unwritten-fresh-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Self-compare validates both outputs and moves the first artifact diff to `defined=363 abs=390`. Starshine size remains `3155453` bytes versus Binaryen `3155990`; pass-local timing is Starshine `0.230ms` versus Binaryen `378.026ms`. Whole-command runtime is still much slower (`61149.242ms` versus `813.083ms`) and remains `[WALL]001` unless later evidence proves an SSANM-local owner. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures with persistent-cache hits.

Agent classification: `defined=215 abs=242` was a true structured branch/value-carrier behavior/safety gap and is fixed by rejecting internally inconsistent fresh-alias rewrites. The `defined=363 abs=390` first diff later became `[SSANM-009b3]` and is now fixed; the current first diff is `defined=501 abs=528` under `[SSANM-009b4]`.

## `[SSANM-009b3]` debug-WASI dropped canonical branch-carrier write fix

`[SSANM-009b3]` reduces and fixes the post-`[SSANM-009b2]` checked-in debug-WASI first diff `defined=363 abs=390` from `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b2-unwritten-fresh-20260614`.

The reduced standalone fixture preserves the `dae_instr_has_escaping_branch` tag-dispatch shape. Two value-producing branch arms compute a label index and branch to later outer branch-target checks that still read the shared canonical label local. Before this slice the legacy raw structured rewrite could freshen those branch-arm writes into appended locals while leaving the later outer reads on the original local. The module validated, but the tag arms could pass the canonical local's default value to the branch-target check instead of the carried label value. That is a true behavior-parity/safety gap, not local-numbering drift and not a huge-function guard.

Starshine now rejects raw structured rewrites that both contain plain `br` traffic and drop all writes to a pre-existing local while retaining reads of that local. This is intentionally fail-closed: it prevents committing a malformed branch-carrier alias plan without changing straight-line/default freshening or typed branch helper surfaces. Appended-local unwritten-read detection from `[SSANM-009b2]` remains separate; `[SSANM-009b3]` catches the original-local version where a default read is legal Wasm but semantically wrong.

The focused test is `ssa-nomerge artifact branch carrier keeps canonical merged label writes` in `src/passes/ssa_nomerge_test.mbt`. It was red first: focused file test failed `427/428` because the reduced output had no canonical write to local `11` while later reads of local `11` remained. After the fix, focused file tests passed `428/428`.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b3-branch-carrier-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b3-branch-carrier-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Self-compare validates both outputs and moves the first artifact diff to `defined=501 abs=528`. Starshine size is now `3155194` bytes versus Binaryen `3155990`; pass-local timing is Starshine `0.421ms` versus Binaryen `385.181ms`. Whole-command runtime is still much slower (`61077.071ms` versus `813.138ms`) and remains `[WALL]001` unless later evidence proves an SSANM-local owner. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures with persistent-cache hits.

Agent classification: `defined=363 abs=390` was a true structured branch-carrier behavior/safety gap and is fixed by rejecting raw rewrites that drop all canonical writes while preserving canonical reads in plain-branch functions. The `defined=501 abs=528` first diff later became `[SSANM-009b4]` and is now classified/fixed as a fail-closed loop-carried plain-branch boundary; the current first diff is `defined=538 abs=565` under `[SSANM-009b5]`.

## `[SSANM-009b4]` debug-WASI loop-carried plain-branch boundary fix

`[SSANM-009b4]` reduces and fixes the post-`[SSANM-009b3]` checked-in debug-WASI first diff `defined=501 abs=528` from `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b3-branch-carrier-20260614`.

The first-diff function is `dae_rewrite_dropped_result_calls_instrs`. The inspected diff showed Starshine's legacy raw structured helper freshening a loop-carried index/local through appended locals and synthesized branch/else copies around plain `br` exits. Binaryen kept the loop carrier closer to the canonical no-merge shape for this branch-target family. Because the Starshine shape was larger and depended on branch-target copy materialization rather than a Binaryen-shaped LocalGraph rewrite, this slice treats the family as a fail-closed boundary instead of accepting the copy shape as safe drift.

At `[SSANM-009b4]` completion, Starshine returned unchanged with `loop-carried-plain-br-boundary-noop` for large structured functions (`base_local_count > 128`) containing a void loop with body-local reads, body-local writes, and plain `br` traffic. `[SSANM-009b5]` later lowered the same boundary to source-lowered scanner-sized functions (`base_local_count > 64`) after the next debug-WASI diff proved the same branch/copy risk below the initial large-only gate. The remaining size gate keeps earlier small artifact parity fixtures that intentionally exercise Binaryen-like loop scratch freshening on the existing raw helper path. The focused red-first fixture is `ssa-nomerge keeps loop-carried plain br boundary canonical` in `src/passes/ssa_nomerge_test.mbt`: before the fix it reported `structured-local-writes` and synthesized an extra local for the loop carrier; after the fix it validates, reports `loop-carried-plain-br-boundary-noop`, rejects planned structured LocalGraph reasons, rejects lifted-HOT mutation, and keeps the original large local budget.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b4-loop-plain-br-20260614b \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b4-loop-plain-br-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Self-compare validates both outputs and moves the first artifact diff to `defined=538 abs=565`. Starshine size is now `3154098` bytes versus Binaryen `3155990`; pass-local timing is Starshine `0.410ms` versus Binaryen `380.631ms`. Whole-command runtime is still much slower (`88685.889ms` versus `817.006ms`) and remains `[WALL]001` unless later evidence proves an SSANM-local owner. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures with persistent-cache hits.

Agent classification: `defined=501 abs=528` was a size-losing / parity-risky legacy structured copy boundary around loop-carried plain branches, not a proven Starshine win. The initial fix was intentionally fail-closed for large structured functions; `[SSANM-009b5]` later narrowed that statement by proving a medium-sized source-lowered scanner in the same branch-target family. Broader Binaryen-shaped mutation for this branch-target family remains future structured-control work.

## `[SSANM-009b5]` debug-WASI medium loop-carried scanner boundary fix

`[SSANM-009b5]` reduces and fixes the post-`[SSANM-009b4]` checked-in debug-WASI first diff `defined=538 abs=565` from `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b4-loop-plain-br-20260614b`.

The first-diff function is `dae_scan_local_use_ignoring_instrs`. The inspected diff showed the same loop-carried plain-branch risk below the earlier large-only threshold: Binaryen kept the scanner carrier canonical, while Starshine's legacy structured helper freshened the carrier through appended locals, inserted branch-arm copies back to the canonical slot, and selected a helper carrier around the loop increment. That shape was smaller than the previous huge fixture but still depended on legacy branch/else copy materialization rather than a Binaryen-shaped LocalGraph branch-target rewrite.

Starshine now returns unchanged with `loop-carried-plain-br-boundary-noop` for structured functions with `base_local_count > 64` that contain a void loop with body-local reads, body-local writes, and plain `br` traffic. The focused red-first fixture is `ssa-nomerge keeps medium loop-carried plain br scanner boundary canonical` in `src/passes/ssa_nomerge_test.mbt`: before the fix it failed `429/430`, reporting the old `structured-local-writes` route; after the fix it validates, reports `loop-carried-plain-br-boundary-noop`, rejects planned structured LocalGraph reasons, rejects lifted-HOT mutation, and keeps the original medium local budget.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b5-medium-loop-plain-br-20260614b \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b5-medium-loop-plain-br-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Self-compare validates both outputs and moves the first artifact diff to `defined=651 abs=678`. Starshine size is now `3153526` bytes versus Binaryen `3155990`; pass-local timing is Starshine `0.409ms` versus Binaryen `377.812ms`. Whole-command runtime is still much slower (`62039.304ms` versus `809.562ms`) and remains `[WALL]001` unless later evidence proves an SSANM-local owner. An earlier self-compare attempt to `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b5-medium-loop-plain-br-20260614` timed out after writing partial artifacts; the `...20260614b` directory is the successful run. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures with persistent-cache hits.

Agent classification: `defined=538 abs=565` was a size-losing / parity-risky medium legacy structured branch-copy boundary around a loop-carried scanner, not a proven Starshine win. The fix is intentionally fail-closed for medium-or-larger source-lowered scanner shapes (`base_local_count > 64`) while keeping genuinely small loop scratch fixtures on the existing raw helper path. The `defined=651 abs=678` first diff later became `[SSANM-009b6]` and is now fixed/classified as a typed result-loop carrier boundary.

## `[SSANM-009b6]` debug-WASI typed result-loop carrier boundary fix

`[SSANM-009b6]` reduces and fixes the post-`[SSANM-009b5]` checked-in debug-WASI first diff `defined=651 abs=678` from `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b5-medium-loop-plain-br-20260614b`.

The first-diff function is `dae_instr_is_unreachable_root`. Starshine's pre-pass raw dump shows a source-lowered single-param/single-result typed loop: the loop param is stored into a body local at the top of the loop, and the recursive backedge uses plain `br` traffic to carry the next instruction value. Binaryen leaves that typed loop carrier canonical. Starshine's legacy raw structured helper lowered the same shape through a helper scratch plus a void-loop/result-block wrapper and appended six helper locals. Because that is larger, is not a Binaryen-shaped LocalGraph no-merge rewrite, and has no measured Starshine win, this slice keeps that narrow plain-`br` typed result-loop carrier family fail-closed.

Starshine now returns unchanged with `result-loop-plain-br-boundary-noop` for result-only loops and for single-param/single-result typed loops that start by storing the loop param into a body local, contain body-local read/write traffic, and contain plain `br` but no `br_if`, `br_table`, `br_on_*`, or cast-branch traffic. The non-plain-branch exclusion preserves the existing typed-control ABI helper owners for scalar/reference `br_if`, `br_table`, `br_on_null`, `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` families. The focused fixture is `ssa-nomerge keeps result loop plain br carrier boundary canonical` in `src/passes/ssa_nomerge_test.mbt`; the initial red-first boundary reason test failed while the new reason was absent, and broad probes that also captured reference typed-control loops were narrowed after focused typed-control tests failed.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b6-result-loop-plain-br-20260614g \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b6-result-loop-plain-br-final-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Self-compare validates both outputs and moves the first artifact diff to `defined=987 abs=1014`. Starshine size is now `3153312` bytes versus Binaryen `3155990`; pass-local timing is Starshine `0.396ms` versus Binaryen `394.743ms`. Whole-command runtime is still much slower (`63136.645ms` versus `832.919ms`) and remains `[WALL]001` unless later evidence proves an SSANM-local owner. Earlier self-compare attempts to `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b6-result-loop-plain-br-20260614` and `...20260614b` timed out after writing partial artifacts, and narrower/broader probe dirs through `...20260614f` either retained the same first diff or were superseded by the final predicate. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures with persistent-cache hits.

Agent classification: `defined=651 abs=678` was a size-losing / parity-risky typed result-loop carrier boundary around plain `br`, not a proven Starshine win. Broader typed-control helper policy remains unchanged; branchy/reference/table/cast typed-loop families stay owned by the existing `[SSANM-007b*]` typed-control boundary/helper tests. The `defined=987 abs=1014` first diff later became `[SSANM-009b7]` and is now fixed/classified as a typed loop-param plain-`br` carrier boundary.

## `[SSANM-009b7]` debug-WASI typed loop-param plain-`br` boundary fix

`[SSANM-009b7]` reduces and fixes the post-`[SSANM-009b6]` checked-in debug-WASI first diff `defined=987 abs=1014` from `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b6-result-loop-plain-br-20260614g`.

The first-diff function is `gr_collect_func_global_sets`. Starshine's pre-pass raw dump shows a source-lowered single-param/no-result typed loop: the initial loop value is stored into a body local at the top of the loop, and the recursive backedge uses plain `br` traffic to carry the next root index. Binaryen leaves that typed loop carrier canonical. Starshine's legacy scalar typed-loop proxy helper introduced a helper scratch, and later local freshening could strand the updated backedge value on a different local than the one read at the next loop iteration. That is a true behavior/parity risk, not a measured Starshine win.

Starshine now returns unchanged with `loop-param-plain-br-boundary-noop` for the narrow single-param/no-result typed-loop shape whose body starts with a body-local `local.set`, contains body-local read/write traffic and plain `br`, has no `br_if`, `br_table`, `br_on_*`, or cast-branch traffic, and has no nested block/loop/try-table control inside the loop body. This preserves the existing typed-control helper owners for `local.tee` loop-param backedges, `br_if`, nested/other-label branches, `try_table`-wrapped backedges, `br_table`, and reference/cast loop-target branches. The focused fixture is `ssa-nomerge keeps typed loop-param local.set plain br boundary canonical` in `src/passes/ssa_nomerge_test.mbt`; it was red first while the trace reported `structured-local-writes-mutated`, and early broad probes were narrowed after existing try-table and nested typed-loop helper tests failed.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b7-loop-param-plain-br-20260614c \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b7-loop-param-plain-br-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Self-compare validates both outputs and moves the first artifact diff to `defined=1163 abs=1190`. Starshine size is now `3153265` bytes versus Binaryen `3155990`; pass-local timing is Starshine `0.395ms` versus Binaryen `382.876ms`. Whole-command runtime is still much slower (`60619.765ms` versus `819.107ms`) and remains `[WALL]001` unless later evidence proves an SSANM-local owner. Earlier self-compare attempts to `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b7-loop-param-plain-br-20260614` and `...20260614b` timed out after writing partial artifacts; `...20260614c` is the completed run. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures with persistent-cache hits.

Agent classification: `defined=987 abs=1014` was a true behavior/parity-risky typed loop-param plain-`br` boundary in `gr_collect_func_global_sets`. The new `defined=1163 abs=1190` first diff is open under `[SSANM-009b8]` and still needs reduction/classification.

## `[SSANM-009b8]` debug-WASI branch result-carrier defaulting fix

`[SSANM-009b8]` reduces and fixes the post-`[SSANM-009b7]` checked-in debug-WASI first diff `defined=1163 abs=1190` from `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b7-loop-param-plain-br-20260614c`.

The first-diff function is `ar_rewrite_load_reinterpret_pair`. Its branch arms select a load memarg, store it in a constructor-specific canonical local, and branch to an outer continuation that calls the matching load-constructor helper. Binaryen keeps those continuation reads canonical. Starshine's raw structured helper and the planned structured/default materializers could treat those branch-result continuation reads as body-local entry defaults, so the four constructor calls received `i32.const 0` instead of the selected memarg. That is a true behavior-parity/safety gap, not a measured Starshine win.

Starshine now restricts default materialization to locals that are never written in the raw function. Written branch-carrier locals are treated as initialized for the raw structured helper, and both the standalone LocalGraph default materializer and planned structured rewrite leave written locals canonical even when the LocalGraph get decision says `MaterializeDefault`. The focused fixture is `ssa-nomerge artifact branch result carriers are not defaulted` in `src/passes/ssa_nomerge_test.mbt`; it was red first while the reduced fixture showed `i32.const 0` immediately before the constructor calls.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b8-branch-result-carriers-20260614c \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b8-branch-result-carriers-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Self-compare validates both outputs and moves the first artifact diff to `defined=1286 abs=1313`. Starshine size is now `3153215` bytes versus Binaryen `3155990`; pass-local timing is Starshine `0.465ms` versus Binaryen `373.169ms`. Whole-command runtime is still much slower (`61759.785ms` versus `806.096ms`) and remains `[WALL]001` unless later evidence proves an SSANM-local owner. Earlier self-compare attempts to `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b8-branch-result-carriers-20260614` and `...20260614b` timed out after writing partial artifacts; timing-only `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b8-branch-result-carriers-timing-20260614` confirmed the repaired `abs=1190` constructor calls use `local.get` operands. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures with persistent-cache hits.

Agent classification: `defined=1163 abs=1190` was a true branch result-carrier defaulting behavior/safety gap in `ar_rewrite_load_reinterpret_pair`. The new `defined=1286 abs=1313` first diff moved under `[SSANM-009b9]` for reduction/classification and is addressed below.

## `[SSANM-009b9]` debug-WASI nested typed loop-param boundary fix

`[SSANM-009b9]` reduces and fixes the post-`[SSANM-009b8]` checked-in debug-WASI first diff `defined=1286 abs=1313` from `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b8-branch-result-carriers-20260614c`.

The first-diff function is `run_hot_pipeline_raw_simplify_locals_take_value_suffix`. The raw input nests a source-lowered single-param/no-result typed loop inside an outer void loop. Binaryen keeps the nested loop carrier coherent/canonical. Starshine's legacy structured helper lowered that nested typed loop to a void-loop/block-result carrier mesh, and in the artifact the next-iteration read and the backedge update could be stranded on different helper locals. This is a behavior/parity-risky typed loop-param plain-`br` boundary, not a proven Starshine win.

Starshine now lets the existing typed loop-param plain-`br` boundary scanner recurse through enclosing void loops and blocks while still avoiding typed/result-loop and `try_table` recursion. The focused fixture is `ssa-nomerge keeps nested typed loop-param plain br boundary canonical` in `src/passes/ssa_nomerge_test.mbt`; it was red first while the trace reported `structured-local-writes` instead of `loop-param-plain-br-boundary-noop`.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b9-nested-loop-param-timing-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge --timing-only

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b9-nested-loop-param-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

Timing-only self-compare validates both outputs, keeps Starshine size at `3153215` bytes versus Binaryen `3155990`, and reports pass-local timing as Starshine `0.402ms` versus Binaryen `387.222ms`. Whole-command runtime is still much slower (`61480.739ms` versus `824.839ms`) and remains `[WALL]001` unless later evidence proves an SSANM-local owner. Full normal self-compare attempts to `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b9-nested-loop-param-20260614` and `...20260614b` timed out after writing partial artifacts, so `[SSANM-009b10]` owns refreshing the next completed first-diff tuple. Local extraction from the timing replay confirms `defined=1286 abs=1313` now uses one coherent carrier (`local 59`) in the formerly divergent nested loop; the remaining inspected diff against Binaryen is temp-local allocation/count drift with fewer Starshine temp locals. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures with persistent-cache hits.

Agent classification: `defined=1286 abs=1313` was a behavior/parity-risky nested typed loop-param plain-`br` boundary in `run_hot_pipeline_raw_simplify_locals_take_value_suffix`. The next first-diff tuple is not yet known because full artifact comparison timed out locally after the fix; `[SSANM-009b10]` owns that refresh before further artifact-specific code.

## `[SSANM-009b10]` debug-WASI parameter-tee branch-carrier fix

`[SSANM-009b10]` refreshed the post-`[SSANM-009b9]` partial artifact comparison from `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b9-nested-loop-param-20260614b`. The completed `result.json` was unavailable because normal self-compare timed out locally, but the saved normalized WAT pair exposed a lightweight alpha first diff at `defined=3 abs=30`, `tlsf/addMemory`.

The reduced shape has a condition that writes an aligned pointer back to parameter local `1` with `local.tee`; the taken branch may then overwrite that same parameter before later reads. Binaryen keeps the parameter tee canonical. Starshine's structured scratch freshener treated the parameter tee like allocator scratch and moved it to an appended body local, so the not-taken path could read the stale original parameter instead of the aligned pointer. This is a true behavior-parity/safety gap, not representation drift.

Starshine now preserves parameter `local.tee` writes when the root structured function has at most one call, a preceding parameter tee is followed by an `if` arm that writes the same parameter, and a later read of that parameter occurs before the next write. The rest of the structured scratch freshener can still freshen the body-local allocator temporaries; existing split-memory and malloc/grow temporary parity tests stay active. The focused fixture is `ssa-nomerge preserves branch-carried parameter tee boundary canonical` in `src/passes/ssa_nomerge_test.mbt`; it was red first with seven i32 locals instead of the expected preserved-parameter shape.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b10-param-tee-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b10-param-tee-timing-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge --timing-only

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b10-param-tee-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

The normal self-compare attempt still timed out after writing wasm/text artifacts. Timing-only self-compare validates both outputs, keeps Starshine size at `3153215` bytes versus Binaryen `3155990`, and reports pass-local timing as Starshine `0.392ms` versus Binaryen `374.836ms`; whole-command runtime remains `[WALL]001` (`61860.847ms` versus `809.741ms`). Local extraction from the timing replay shows `defined=3 abs=30` now preserves the parameter `local.tee 1`; remaining inspected differences in that function are temp-local allocation/count drift. A lightweight alpha comparison over the post-fix normal self-compare artifacts advances the next candidate diff to `defined=154 abs=181`; `[SSANM-009b11]` owns refreshing or classifying that family with stronger canonical evidence. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures with persistent-cache hits.

Agent classification: `defined=3 abs=30` was a true parameter-tee branch-carrier behavior/safety gap in `tlsf/addMemory`; it is fixed without disabling the structured scratch freshener wholesale.

## `[SSANM-009b11]` debug-WASI loop-header alias-copy fix

`[SSANM-009b11]` turns the post-`[SSANM-009b10]` lightweight alpha candidate into an actionable reduced fixture. The saved post-fix artifact pair under `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b10-param-tee-20260614` first differed at `defined=154 abs=181`, `_M0FP37jtenner9starshine3cmd19parse__olevel__text`.

The actionable shape was a loop whose header reads locals written before the loop before any loop-local write. Binaryen keeps those header-read locals canonical. Starshine's legacy structured local-write path freshened them, then inserted extra canonical alias copies before plain loop backedges. That was size-losing local-allocation drift and not a proven Starshine win.

The reduced fixture is `ssa-nomerge avoids loop-backedge alias copies for header-read locals`. It was red first with eight i32 locals instead of the expected six. The fix makes later-read and later-write scans descend through `loop` and `try_table` containers, so root writes whose later reads live in nested loop headers are seen by the existing canonical-preservation predicate.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b11-loop-header-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b11-loop-header-timing-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge --timing-only

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b11-loop-header-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

The normal self-compare timed out after writing wasm/text artifacts. Timing-only self-compare validates both outputs, reports Starshine size `3152912` bytes versus Binaryen `3155990`, and pass-local timing as Starshine `0.401ms` versus Binaryen `386.187ms`; whole-command runtime remains `[WALL]001` (`62113.944ms` versus `877.110ms`). Local extraction confirms `defined=154 abs=181` no longer has the backedge alias-copy alpha diff, and a lightweight alpha scan over the post-fix artifacts advances the next candidate to `defined=300 abs=327`. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1) with persistent-cache hits.

Agent classification: `defined=154 abs=181` was a size-losing / behavior-parity local-allocation gap in `parse__olevel__text`; it is fixed by making the existing future-use scans see nested loop/try-table containers instead of adding another artifact-specific no-op guard.

## `[SSANM-009b12]` debug-WASI branch-exit store-suffix carrier fix

`[SSANM-009b12]` turns the post-`[SSANM-009b11]` lightweight alpha candidate into an actionable reduced fixture. The saved post-fix artifact pair under `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b11-loop-header-20260614` first differed at `defined=300 abs=327`, `_M0FP37jtenner9starshine6passes55dae__try__unwrap__func313__suffix__staging__block__once`.

The actionable shape was a branch-carrier mesh where arms push multiple values, run adjacent `local.set`s, then plain-branch to an outer merge. Binaryen keeps the post-merge carriers canonical without Starshine's extra store-suffix alias locals. Starshine only recognized an immediately following `br`, so earlier stores in a stack-to-local suffix were freshened and then repaired with extra alias copies.

The reduced fixture is `ssa-nomerge keeps branch-exit store suffix carriers canonical`. It was red first with four body locals instead of the expected two. The fix makes the branch-exit canonical-alias scanner look through adjacent `local.set` suffixes before a plain `br`, stopping if the same local is overwritten.

Artifact and fuzz evidence:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b12-branch-suffix-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge

bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-ssa-nomerge-debug-wasi-ssanm009b12-branch-suffix-timing-20260614 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --ssa-nomerge --timing-only

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass ssa-nomerge \
  --out-dir .tmp/pass-fuzz-ssa-nomerge-ssanm009b12-branch-suffix-10000 \
  --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
```

The normal self-compare timed out after writing wasm/text artifacts. Timing-only self-compare validates both outputs, reports Starshine size `3152718` bytes versus Binaryen `3155990`, and pass-local timing as Starshine `0.367ms` versus Binaryen `376.258ms`; whole-command runtime remains `[WALL]001` (`61223.853ms` versus `814.902ms`). Local extraction confirms `defined=300 abs=327` now has `259` i32 locals on both Starshine and Binaryen instead of Starshine's prior `261`, and a lightweight alpha scan over the post-fix artifacts advances the next candidate to `defined=1413 abs=1440`. Direct compare requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures (`binaryen-rec-group-zero` 22, `binaryen-bad-section-size` 1) with persistent-cache hits.

Agent classification: `defined=300 abs=327` was a behavior-parity / size-losing branch-exit store-suffix local-allocation gap; it is fixed by broadening the existing branch-exit canonical-preservation scanner over adjacent local-store suffixes rather than adding a function-specific guard.

## `[SSANM-009b13]` debug-WASI multi-param typed result-loop classification

`[SSANM-009b13]` classifies the next lightweight alpha candidate from the post-`[SSANM-009b12]` artifact pair under `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b12-branch-suffix-20260614`. The first candidate was `defined=1413 abs=1440`, `_M0FP37jtenner9starshine6passes51optimize__instructions__is__boolean__constant__tree`.

Targeted `--print-func 1440` extraction shows a multi-param single-result typed-loop carrier family rather than a new validation or semantic-safety bug. The input has a three-parameter / one-result typed loop with recursive branch operands. Binaryen represents the loop-carrier update through a tuple/block-shaped result carrier, while Starshine lowers the typed result loop through the current void-loop/store model and spills stack-carried branch operands into helper locals before storing the loop-param scratches. In the extracted artifact, Starshine has `38` body locals (`35` i32 / `3` i64) and Binaryen has `37` (`34` i32 / `3` i64), compared with the input's `20` body locals (`18` i32 / `2` i64). Raw instruction-shape counts also show Starshine slightly above Binaryen for this function (`21` `local.set`s versus `19`, and `79` `local.get`s versus `77`).

A skip-ahead alpha scan found the same repeated family at `defined=1431 abs=1458`: Starshine has `53` body locals (`50` i32 / `3` i64), Binaryen has `51` (`48` i32 / `3` i64), and the input has `27` (`25` i32 / `2` i64). Skipping both functions advances the local lightweight candidate to `defined=1451 abs=1478`, but `[SSANM-009b13]` does not claim that as the next actionable non-family diff.

Agent classification: this is a size-losing / behavior-parity output-shape gap in the typed-control store-model helper, not a proven Starshine win and not a fresh semantic mismatch. It is split to backlog slice `[SSANM-009b13a]`, which should reduce the multi-param typed result-loop branch-carrier shape and either align the store model with Binaryen's lower-local carrier shape or document a measured reason to keep Starshine's helper locals. Direct `--pass ssa-nomerge` compare was not rerun for this classification-only slice because no behavior, trace routing, or generated wasm changed; the preceding `[SSANM-009b12]` direct lane remained normalized-green with `0` mismatches.

## `[SSANM-009b13a]` raw result-loop carrier sub-fix

`[SSANM-009b13a]` first narrowed the reproduction: the standalone `abs=1440` wrapper did not show the final local-count loss until the Starshine raw output was passed through the same `wasm-opt --strip-debug` canonicalizer used by `self-optimize-compare`. That canonicalization reproduces the one-local final loss, so the remaining gap is between Starshine's raw typed-control carrier shape and Binaryen's tuple/block carrier as observed after the shared Binaryen writer.

The first code sub-fix keeps a non-void raw result loop for a narrow subset: GC-free multi-param single-result typed loops whose current-loop backedges are only plain `br` and whose body has no `try_table`. It deliberately leaves `br_if`, `br_table`, reference/cast branches, single-param result loops, and no-throw `try_table` typed-control helpers on the existing store/proxy model.

Evidence: the reduced test `ssa-nomerge preserves result loop carrier for multi-param direct br backedges` in `src/passes/ssa_nomerge_test.mbt` failed red-first (`437/438`) with the old void-loop/result-block wrapper, then passed (`438/438`) after the raw loop carrier was preserved. `moon test src/passes` passed `2468/2468`; `moon fmt`; `moon info` passed with the three pre-existing GenValid warnings; full `moon test` passed `5773/5773`; native `src/cmd` build passed with the pre-existing pass-manager unused-function warnings. Direct compare `.tmp/pass-fuzz-ssa-nomerge-ssanm009b13a-result-carrier-20260614` requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` Binaryen/tool command failures from cached Binaryen failures.

Artifact replay `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b13a-result-carrier-20260614` timed out after writing artifacts. Targeted extraction confirmed the sub-fix changed `abs=1440` Starshine to a final `loop I32` shape instead of the previous raw void-loop/result-block wrapper, but it did not close the artifact first diff by itself: the alpha scan still first-diffed at `defined=1413 abs=1440`, with final canonical locals Starshine `38` body locals versus Binaryen `37` (`abs=1458` Starshine `53` versus Binaryen `51`).

The closing follow-up reclassified the tuple/block direction before committing to it as policy. The reduced test `ssa-nomerge leaves tuple carrier disabled without canonical local proof` failed red-first while Starshine emitted a direct tuple carrier block; a targeted reduced canonicalization probe showed that direct tuple blocks made `wasm-opt --strip-debug` add more helper locals. The final policy disables that tuple-carrier path until it has canonical local-count proof and keeps the source-shaped result-loop boundary for this subset.

Current evidence in `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b13a-disable-tuple-20260614` timed out after writing artifacts, but targeted extraction validates both outputs and turns the repeated family into a measured Starshine local-count win: `abs=1440` has Starshine `29` body locals (`27` i32 / `2` i64) versus Binaryen `37` (`34` i32 / `3` i64), and `abs=1458` has Starshine `39` (`37` i32 / `2` i64) versus Binaryen `51` (`48` i32 / `3` i64). Skipping those repeats advances the local alpha candidate to `defined=1451 abs=1478`; the current full self artifact first-diffs earlier at `defined=540 abs=567`, now owned by `[SSANM-009b14]`.

## `[SSANM-009b14]` branch/table one-shot temp-local classification

`[SSANM-009b14]` is a classification-only slice over the current full self artifact first diff at `defined=540 abs=567`. Targeted `--print-func 567` extraction under `.tmp/ssanm009b13a-next540` shows a branch/table-heavy loop function where Starshine and Binaryen have the same canonical instruction/control skeleton. A token comparison of the `body_raw` streams found equal token counts and only 17 differences, all local-index choices: Binaryen uses fresh one-shot locals `50..66`, while Starshine reuses otherwise-dead existing locals such as `7`, `8`, `13`, `14`, `16`, `17`, `18`, `26`, `27`, `30`, `31`, `32`, `33`, `34`, `35`, and `38`.

Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. The differing locals are one-use `local.tee` targets or branch-local `local.set` carriers with no later reads in the canonical body. No call, memory access, branch/table opcode, label target, constant, or structured-control node differs. Both artifacts validate with `wasm-tools validate --features all`.

Measured deltas: `abs=567` has Starshine `45` body i32 locals versus Binaryen `62`, but both encoded code bodies are `775` bytes (`772` instruction bytes plus `3` local-declaration bytes). So the function-level win is lower local count with no body-size regression, not a byte-size win. The whole canonical artifact remains Starshine-smaller (`3149379` bytes versus Binaryen `3155990` bytes), but that whole-module delta should not be attributed solely to this function.

Evidence: direct compare `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` requested `10000`, compared `9977`, had `9977` normalized matches, `0` mismatches, and `23` cached Binaryen/tool command failures. No code or tests changed in this slice because the inspected family is not an implementation gap. A preliminary `--print-func 568` probe under `.tmp/ssanm009b14-next568` found a likely repeated one-shot temp-local family (`92` Starshine body i32 locals versus `112` Binaryen), now tracked by `[SSANM-009b15]`.

## `[SSANM-009b15]` repeated one-shot temp-local classification at `abs=568`

`[SSANM-009b15]` classifies the next current self-artifact diff, `defined=541 abs=568`, from `.tmp/self-ssa-nomerge-debug-wasi-ssanm009b13a-disable-tuple-20260614`. Targeted `--print-func 568` extraction under `.tmp/ssanm009b14-next568` shows the same broad family as `[SSANM-009b14]`: Starshine and Binaryen have identical canonical instruction/control skeletons, and the `body_raw` token streams differ only in local-index choices.

Local-use analysis found 20 differing one-use `local.tee` temps. Binaryen allocates fresh locals `95..114`; Starshine reuses otherwise-dead existing locals `67`, `40`, `61`, `70`, `43`, `60`, `74`, `73`, `46`, `59`, `77`, `51`, `37`, `38`, `30`, `31`, `23`, `24`, `14`, and `16`. Each differing local appears exactly once as a `local.tee` target on its side. No call, load/store, branch/table opcode, label target, constant, or structured-control token differs.

Measured deltas: `abs=568` has Starshine `92` body i32 locals versus Binaryen `112`, but both encoded code bodies are `1253` bytes (`1250` instruction bytes plus `3` local-declaration bytes). Both full artifacts validate with `wasm-tools validate --features all`, and whole canonical artifacts remain Starshine `3149379` bytes versus Binaryen `3155990` bytes. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap and not a function-byte-size win. No code or executable tests changed; direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane.

## `[SSANM-009b16]` repeated one-shot temp-local classification at `abs=574`

`[SSANM-009b16]` follows the same print-diff chain to `defined=547 abs=574`. Targeted extraction under `.tmp/ssanm009b15-next574` shows equal `body_raw` token lengths and only 9 local-index differences: `5 -> 25`, `9 -> 26`, `8 -> 27`, `7 -> 28`, `12 -> 29`, `16 -> 30`, `22 -> 31`, `18 -> 32`, and `21 -> 33`.

Every differing local appears exactly once as a dead `local.tee` temp, and no control, branch/table, call, memory, label, or constant token differs. Starshine has `23` body i32 locals versus Binaryen `32`, while both encoded code bodies are `371` bytes (`368` instruction bytes plus `3` local-declaration bytes). Agent classification: the same semantic-safe Starshine local-count win / no-regression representation difference as `[SSANM-009b14]` and `[SSANM-009b15]`. No code or executable tests changed; direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane.

## `[SSANM-009b17]` local-slot permutation classification at `abs=575`

`[SSANM-009b17]` follows the same current self-artifact pair to `defined=548 abs=575`, but this diff is not the appended one-shot temp-local family. Targeted `--print-func 575` extraction under `.tmp/ssanm009b16-next575` shows Starshine and Binaryen both have two params, seven body i32 locals, equal canonical `body_raw` token lengths, and the same structured branch/result-carrier skeleton.

The only token differences are local-index choices for branch-local temporaries. The offset-8 load is teed solely for the comparison (`local 6` in Starshine, `local 7` in Binaryen) and is not read later. In the taken arm, the offset-12 load is stored and immediately reread through one temp (`local 8` in Starshine, `local 6` in Binaryen), then teed through a dead stack-preserving temp (`local 7` in Starshine, `local 8` in Binaryen) before both outputs set canonical `local 2`, branch to the same block label, and later call the same continuation with `local.get 2`. No branch/table opcode, call, load/store memarg, constant, label, result type, or structured-control node differs.

Measured deltas: defined function `548` encodes to the same `86` byte code body in both artifacts (`83` instruction bytes plus `3` local-declaration bytes), with the same single local-declaration run of seven i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. Agent classification: semantic-safe neutral representation-only local permutation. It is not a Starshine win because local count and body size are equal, and it is not a parity gap because the inspected dataflow and control skeleton are identical. No code or executable tests changed, so direct compare was not rerun beyond `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614`.

## `[SSANM-009b18]` repeated one-shot temp-local classification at `abs=576`

`[SSANM-009b18]` follows the same current self-artifact pair to `defined=549 abs=576`. Targeted `--print-func 576` extraction under `.tmp/ssanm009b17-next576` shows Starshine and Binaryen have the same canonical instruction/control skeleton and equal `body_raw` token length once local indexes are masked. The only token differences are 15 `local.tee` target choices: Starshine reuses locals `14`, `15`, `31`, `56`, `10`, `11`, `12`, `27`, `29`, `30`, `40`, `24`, `25`, `37`, and `22`, while Binaryen allocates fresh locals `61..75`.

Local-use analysis shows every differing local appears exactly once as a dead stack-preserving `local.tee` target on its side; none of those Starshine reused slots or Binaryen fresh slots is later read. No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs. The Starshine trace for abs `576` reports `call-heavy-memory-structured-noop`, so this remains artifact representation classification rather than a new SSANM mutation owner.

Measured deltas: defined function `549` encodes to the same `714` byte code body in both artifacts (`711` instruction bytes plus `3` local-declaration bytes). Starshine has `59` body i32 locals versus Binaryen `74`; the function body is therefore local-count reducing and byte-size neutral, not size-losing. Both full artifacts validate with `wasm-tools validate --features all`. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614`.

## `[SSANM-009b19]` typed-local group renumbering classification at `abs=579`

`[SSANM-009b19]` follows the same current self-artifact pair to `defined=552 abs=579`. Targeted `--print-func 579` extraction under `.tmp/ssanm009b18-next579` shows equal canonical `body_raw` token length: `2563` tokens and `209` local operations on both sides (`129` `local.get`, `54` `local.set`, and `26` `local.tee`). Once local indexes are masked, the token streams are identical, including calls, loads/stores, branches, labels, constants, result types, and structured-control tokens.

The visible local-declaration type/count difference comes from Binaryen declaring seven extra i32 one-shot temps before the typed local groups. Binaryen uses fresh one-use i32 `local.tee` targets `61..67`, while Starshine reuses existing one-use i32 locals `45..51`. The remaining local-token differences are a type-preserving live-carrier renumbering caused by that insertion: `f64` carriers are Starshine `61..67` versus Binaryen `68..74`; `f32` carriers are Starshine `68..74` versus Binaryen `75..81`; and `i64` carriers are Starshine `75..81` versus Binaryen `82..88`. The seven direct i32 differences are dead stack-preserving tee targets; the typed carrier differences are a bijective same-type shift, not different dataflow.

Measured deltas: defined function `552` encodes to the same `832` byte code body in both artifacts (`823` instruction bytes plus `9` local-declaration bytes). Starshine local declarations are `(59 i32, 7 f64, 7 f32, 7 i64)`, while Binaryen declarations are `(66 i32, 7 f64, 7 f32, 7 i64)`. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `579` reports `call-heavy-memory-structured-noop`, so this is artifact representation classification rather than a new SSANM mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, function-body byte-size neutral. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b20]` repeated one-shot temp-local classification at `abs=580`

`[SSANM-009b20]` follows the same current self-artifact pair to `defined=553 abs=580`. Targeted `--print-func 580` extraction under `.tmp/ssanm009b19-next580` shows equal canonical `body_raw` token length: `1532` tokens and `111` local operations on both sides (`77` `local.get`, `22` `local.set`, and `12` `local.tee`). Once local indexes are masked, the token streams are identical, including calls, loads/stores, branches, labels, constants, result types, and structured-control tokens.

The only token differences are four dead stack-preserving `local.tee` target choices. Starshine reuses one-use locals `19`, `14`, `24`, and `25`, while Binaryen allocates fresh one-use locals `40`, `41`, `42`, and `43`. Local-use analysis shows none of these differing temp locals is read later on its side.

Measured deltas: defined function `553` encodes to the same `476` byte code body in both artifacts (`473` instruction bytes plus `3` local-declaration bytes). Starshine has `34` body i32 locals versus Binaryen `38`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `580` reports `call-heavy-memory-structured-noop`, so this is not a new SSANM mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b21]` repeated one-shot temp-local classification at `abs=581`

`[SSANM-009b21]` follows the same current self-artifact pair to `defined=554 abs=581`. Targeted `--print-func 581` extraction under `.tmp/ssanm009b20-next581` shows identical canonical `body_raw` strings once local indexes are masked, with `175` local operations on both sides (`119` `local.get`, `31` `local.set`, and `25` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 15 dead stack-preserving `local.tee` target choices. Starshine reuses one-use locals `16`, `12`, `13`, `17`, `18`, `26`, `24`, `19`, `29`, `28`, `30`, `31`, `38`, `41`, and `42`, while Binaryen allocates fresh one-use locals `61..75`. Local-use analysis shows every differing local appears exactly once as a `local.tee` target on its side.

Measured deltas: defined function `554` encodes to the same `756` byte code body in both artifacts (`753` instruction bytes plus `3` local-declaration bytes). Starshine has `56` body i32 locals versus Binaryen `71`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `581` reports `call-heavy-memory-structured-noop`, so this is not a new SSANM mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b22]` local-slot permutation classification at `abs=584`

`[SSANM-009b22]` follows the same current self-artifact pair to `defined=557 abs=584`. Targeted `--print-func 584` extraction under `.tmp/ssanm009b21-next584` shows identical canonical `body_raw` strings once local indexes are masked, with the same 14 local operations on both sides (`8` `local.get`, `2` `local.set`, and `4` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only differences are a same-type branch-local permutation. Starshine uses `7` and `8` as dead `local.tee` targets and uses local `9` for the loaded value's set/get pair; Binaryen uses `8` and `9` as dead `local.tee` targets and uses local `7` for the same loaded value's set/get pair. The local count and local types are the same on both sides, so this is not a measured Starshine local-count win.

Measured deltas: defined function `557` encodes to the same `65` byte code body in both artifacts (`62` instruction bytes plus `3` local-declaration bytes), with the same eight body i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `584` reports `structured-local-writes`, so this remains artifact representation classification rather than a new behavior mutation. Agent classification: semantic-safe neutral representation-only local permutation. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b23]` repeated one-shot temp-local classification at `abs=585`

`[SSANM-009b23]` follows the same current self-artifact pair to `defined=558 abs=585`. Targeted `--print-func 585` extraction under `.tmp/ssanm009b22-next585` shows identical canonical `body_raw` token streams once local indexes are masked, with `378` local operations on both sides (`259` `local.get`, `77` `local.set`, and `42` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 20 dead stack-preserving `local.tee` target choices. Starshine reuses one-use locals `6`, `7`, `46`, `47`, `49`, `50`, `52`, `86`, `83`, `37`, `100`, `71`, `62`, `58`, `32`, `67`, `91`, `73`, `75`, and `79`, while Binaryen allocates fresh one-use locals `121..140`. Local-use analysis shows every differing local appears exactly once as a `local.tee` target on its side.

Measured deltas: defined function `558` encodes to a smaller Starshine code body: `1626` bytes (`1623` instruction bytes plus `3` local-declaration bytes) versus Binaryen `1640` bytes (`1636` instruction bytes plus `4` local-declaration bytes). Starshine has `119` body i32 locals versus Binaryen `139`; the byte win comes from the smaller local-declaration count and avoiding the wider local-index LEB encodings for Binaryen locals `128..140`. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `585` reports `call-heavy-memory-structured-noop`, so this is not a new SSANM mutation owner. Agent classification: semantic-safe Starshine local-count and encoded-body-size win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b24]` repeated temp-local plus i64 group classification at `abs=587`

`[SSANM-009b24]` follows the same current self-artifact pair to `defined=560 abs=587` after `defined=559 abs=586` matched in the whole-print scan. Targeted `--print-func 587` extraction under `.tmp/ssanm009b23-next587` shows identical canonical `body_raw` token streams once local indexes are masked, with `135` local operations on both sides (`90` `local.get`, `21` `local.set`, and `24` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The direct differing local tokens are one-use `local.tee` temps plus type-preserving i64 carrier renumbering. Starshine reuses i32 one-use locals `6`, `10`, `11`, `19`, `22`, `23`, `28`, `29`, `35`, `36`, `38`, `39`, `40`, and `43` where Binaryen uses fresh i32 one-use locals `46..59`; Starshine uses live i64 carrier locals `46` and `47`, while Binaryen shifts the corresponding live i64 carrier locals to `60` and `62` after its extra i32 temps and adds one extra one-use i64 tee local `61`.

Measured deltas: defined function `560` encodes to the same `677` byte code body in both artifacts (`672` instruction bytes plus `5` local-declaration bytes). Starshine declares `(42 i32, 2 i64)` body locals versus Binaryen `(56 i32, 3 i64)`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `587` reports `call-heavy-memory-structured-noop`, so this remains artifact representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference with type-group renumbering. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b25]` repeated one-shot temp-local classification at `abs=589`

`[SSANM-009b25]` follows the same current self-artifact pair to `defined=562 abs=589`. Targeted `--print-func 589` extraction under `.tmp/ssanm009b24-next589` shows identical canonical `body_raw` token streams once local indexes are masked, with `371` local operations on both sides (`211` `local.get`, `70` `local.set`, and `90` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 37 dead stack-preserving `local.tee` target choices. Starshine reuses one-use locals `14`, `15`, `97`, `9`, `11`, `96`, `24`, `25`, `99`, `98`, `34`, `35`, `101`, `100`, `47`, `48`, `103`, `44`, `102`, `75`, `76`, `109`, `72`, `107`, `106`, `105`, `104`, `108`, `123`, `93`, `94`, `95`, `114`, `90`, `112`, `111`, and `113`, while Binaryen allocates fresh one-use locals `153..189`. Local-use analysis shows every differing local appears exactly once as a `local.tee` target on its side.

Measured deltas: defined function `562` encodes to a smaller Starshine code body: `1803` bytes (`1799` instruction bytes plus `4` local-declaration bytes) versus Binaryen `1840` bytes (`1836` instruction bytes plus `4` local-declaration bytes). Starshine has `151` body i32 locals versus Binaryen `188`; the byte win comes from avoiding the wider local-index LEB encodings for Binaryen locals `153..189`. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `589` reports `call-heavy-memory-structured-noop`, so this is not a new SSANM mutation owner. Agent classification: semantic-safe Starshine local-count and encoded-body-size win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b26]` repeated one-shot temp-local classification at `abs=593`

`[SSANM-009b26]` follows the same current self-artifact pair to `defined=566 abs=593` after `defined=563..565 abs=590..592` matched in the whole-print scan. Targeted `--print-func 593` extraction under `.tmp/ssanm009b25-next593` shows identical canonical `body_raw` token streams once local indexes are masked, with `99` local operations on both sides (`68` `local.get`, `19` `local.set`, and `12` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are seven dead stack-preserving `local.tee` target choices. Starshine reuses one-use locals `32`, `13`, `14`, `17`, `26`, `24`, and `29`, while Binaryen allocates fresh one-use locals `38..44`. Local-use analysis shows every differing local appears exactly once as a `local.tee` target on its side.

Measured deltas: defined function `566` encodes to the same `428` byte code body in both artifacts (`425` instruction bytes plus `3` local-declaration bytes). Starshine has `31` body i32 locals versus Binaryen `38`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `593` reports `call-heavy-memory-structured-noop`, so this remains artifact representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b27]` repeated one-shot temp-local and i64 group classification at `abs=594`

`[SSANM-009b27]` follows the same current self-artifact pair to `defined=567 abs=594`. Targeted `--print-func 594` extraction under `.tmp/ssanm009b26-next594` shows identical canonical `body_raw` token streams once local indexes are masked, with `496` local operations on both sides (`342` `local.get`, `95` `local.set`, and `59` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The local-token differences are 40 one-use write-target choices: 33 stack-preserving `local.tee` targets plus seven dead `local.set` targets. Every differing local appears exactly once as a same-typed write target on its side. Starshine reuses 37 one-use i32 slots and three one-use i64 slots, while Binaryen allocates fresh corresponding i32 locals `159..195` and fresh i64 locals `199..201`; the extra Binaryen i32 temps shift the live i64 group but do not change the masked instruction/control skeleton.

Measured deltas: defined function `567` encodes to a smaller Starshine code body: `2439` bytes (`2433` instruction bytes plus `6` local-declaration bytes) versus Binaryen `2473` bytes (`2467` instruction bytes plus `6` local-declaration bytes). Starshine declares `(151 i32, 3 i64)` body locals versus Binaryen `(188 i32, 6 i64)`, so this is a local-count and encoded-body-size win. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `594` reports `call-heavy-memory-structured-noop`, so this is not a new SSANM mutation owner. Agent classification: semantic-safe Starshine local-count and encoded-body-size win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b28]` repeated one-shot temp-local classification at `abs=595`

`[SSANM-009b28]` follows the same current self-artifact pair to `defined=568 abs=595`. Targeted `--print-func 595` extraction under `.tmp/ssanm009b27-next595` shows identical canonical `body_raw` token streams once local indexes are masked, with `43` local operations on both sides (`31` `local.get`, `10` `local.set`, and `2` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token difference is one dead stack-preserving `local.tee` target choice. Starshine reuses one-use i32 local `12`, while Binaryen allocates fresh one-use i32 local `14`; local-use analysis shows each differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `568` encodes to the same `191` byte code body in both artifacts (`188` instruction bytes plus `3` local-declaration bytes). Starshine has `12` body i32 locals versus Binaryen `13`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all` from the `[SSANM-009b27]` validation. The Starshine trace for abs `595` reports `multiparam-value-if-branch-carrier-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b29]` neutral local-slot permutation at `abs=597`

`[SSANM-009b29]` follows the same current self-artifact pair to `defined=570 abs=597` after `defined=569 abs=596` matched in the whole-print scan. Targeted `--print-func 597` extraction under `.tmp/ssanm009b28-next597` shows identical canonical `body_raw` token streams once local indexes are masked, with `48` local operations on both sides (`32` `local.get`, `10` `local.set`, and `6` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are a same-type permutation among five i32 local slots. Starshine uses `18` and `19` as one-use `local.tee` targets, `22` as a set/get pair, `20` as a set-only slot, and `21` as a one-use `local.tee` target; Binaryen uses the corresponding slots `19`, `20`, `18`, `21`, and `22`. The local-use table is otherwise identical, so this is a self-contained local-slot permutation rather than a branch, memory, call, control, or typed-carrier change.

Measured deltas: defined function `570` encodes to the same `239` byte code body in both artifacts (`236` instruction bytes plus `3` local-declaration bytes). Both sides declare the same 20 body i32 locals, so there is no local-count or encoded-size win to claim. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `597` reports `structured-local-writes`, so this remains artifact representation classification rather than a new mutation owner. Agent classification: semantic-safe neutral representation-only local permutation, not a measured Starshine win and not an implementation gap. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b30]` structured scratch-local local-count gap at `abs=598`

`[SSANM-009b30]` follows the current self-artifact pair to `defined=571 abs=598`. Targeted `--print-func 598` extraction under `.tmp/ssanm009b29-next598` shows identical canonical `body_raw` token streams once local indexes are masked, with `16` local operations on both sides (`9` `local.get`, `4` `local.set`, and `3` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are two i32 set/get pairs. Starshine stores the first offset-8 load in appended local `9` and rereads `9`, while Binaryen uses body local `1`; Starshine stores the nested element load in appended local `10` and rereads `10`, while Binaryen uses body local `3`. Starshine still declares body locals `1` and `3`, but they are otherwise unused in the printed output. That makes this semantic-safe by inspected same-op dataflow, but not a Starshine win: it is a local-count-losing output-shape gap caused by structured raw scratch freshening choosing appended locals instead of reusing or compacting unused same-typed body locals.

Measured deltas: defined function `571` encodes to the same `92` byte code body in both artifacts (`89` instruction bytes plus `3` local-declaration bytes). Starshine declares `10` body i32 locals versus Binaryen `8`, so the current encoded body is byte-size neutral only because all affected local indexes and the local-declaration count still encode in one LEB byte. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `598` reports `structured-local-writes-mutated`, so the follow-up is structured raw scratch-local allocation/compaction work rather than a canonical LocalGraph no-merge success reason. Agent classification: semantic-safe but Starshine-local-count-losing parity gap, split to `[SSANM-009b30a]` for implementation work. No executable code changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b31]` one-shot temp-local classification at `abs=600`

`[SSANM-009b31]` follows the current self-artifact pair to `defined=573 abs=600` after `defined=572 abs=599` matched in the prior scan. Targeted `--print-func 600` extraction under `.tmp/ssanm009b30-next600` shows identical canonical `body_raw` token streams once local indexes are masked, with `48` local operations on both sides (`35` `local.get`, `10` `local.set`, and `3` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are two dead stack-preserving `local.tee` target choices. Starshine uses locals `3` and `13`, while Binaryen allocates fresh locals `15` and `16`; Binaryen still declares locals `3` and `13` but does not use them. Local-use analysis shows each differing local appears exactly once as a same-typed `local.tee` target on its side, so this is the repeated one-shot temp-local representation family rather than a control, memory, call, or dataflow change.

Measured deltas: defined function `573` encodes to the same `217` byte code body in both artifacts (`214` instruction bytes plus `3` local-declaration bytes). Starshine declares `13` body i32 locals versus Binaryen `15`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `600` reports `multiparam-value-if-branch-carrier-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b32]` repeated one-shot temp-local classification at `abs=601`

`[SSANM-009b32]` follows the current self-artifact pair to `defined=574 abs=601`. Targeted `--print-func 601` extraction under `.tmp/ssanm009b31-next601` shows identical canonical `body_raw` token streams once local indexes are masked, with `228` local operations on both sides (`156` `local.get`, `39` `local.set`, and `33` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 20 one-use same-typed write targets: 19 dead stack-preserving `local.tee` targets and one dead `local.set` target. Starshine reuses locals `7`, `8`, `16`, `17`, `40`, `64`, `42`, `43`, `46`, `48`, `47`, `69`, `51`, `23`, `54`, `68`, `39`, `33`, `56`, and `55`, while Binaryen allocates fresh one-use locals `75..94`. Local-use analysis shows every differing local appears exactly once as the corresponding write target on its side.

Measured deltas: defined function `574` encodes to the same `999` byte code body in both artifacts (`996` instruction bytes plus `3` local-declaration bytes). Starshine declares `72` body i32 locals versus Binaryen `92`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `601` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b33]` repeated one-shot temp-local classification at `abs=602`

`[SSANM-009b33]` follows the current self-artifact pair to `defined=575 abs=602`. Targeted `--print-func 602` extraction under `.tmp/ssanm009b32-next602` shows identical canonical `body_raw` token streams once local indexes are masked, with `278` local operations on both sides (`182` `local.get`, `53` `local.set`, and `43` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 27 one-use same-typed write targets: 26 dead stack-preserving `local.tee` targets and one dead `local.set` target. Starshine reuses locals `7`, `8`, `51`, `75`, `20`, `21`, `53`, `45`, `84`, `47`, `48`, `54`, `56`, `58`, `57`, `89`, `61`, `28`, `64`, `65`, `67`, `88`, `44`, `38`, `69`, `68`, and `72`, while Binaryen allocates fresh one-use locals `99..125`. Local-use analysis shows every differing local appears exactly once as the corresponding write target on its side.

Measured deltas: defined function `575` encodes to the same `1251` byte code body in both artifacts (`1248` instruction bytes plus `3` local-declaration bytes). Starshine declares `96` body i32 locals versus Binaryen `123`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `602` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b34]` repeated one-shot temp-local classification at `abs=603`

`[SSANM-009b34]` follows the current self-artifact pair to `defined=576 abs=603`. Targeted `--print-func 603` extraction under `.tmp/ssanm009b33-next603` shows identical canonical `body_raw` token streams once local indexes are masked, with `161` local operations on both sides (`108` `local.get`, `29` `local.set`, and `24` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 15 one-use dead `local.tee` targets. Starshine reuses locals `7`, `8`, `17`, `48`, `19`, `43`, `29`, `23`, `51`, `25`, `26`, `30`, `36`, `39`, and `42`, while Binaryen allocates fresh one-use locals `55..69`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `576` encodes to the same `699` byte code body in both artifacts (`696` instruction bytes plus `3` local-declaration bytes). Starshine declares `53` body i32 locals versus Binaryen `68`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `603` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b35]` repeated one-shot temp-local classification at `abs=604`

`[SSANM-009b35]` follows the current self-artifact pair to `defined=577 abs=604`. Targeted `--print-func 604` extraction under `.tmp/ssanm009b34-next604` shows identical canonical `body_raw` token streams once local indexes are masked, with `519` local operations on both sides (`343` `local.get`, `94` `local.set`, and `82` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 52 one-use same-typed write targets: 47 dead stack-preserving `local.tee` targets and five dead `local.set` targets. Starshine reuses i32 tee locals `89`, `91`, `62`, `63`, `64`, `65`, `67`, `68`, `70`, `71`, `76`, `83`, `133`, `132`, `135`, `136`, `138`, `50`, `145`, `52`, `118`, `120`, `58`, `126`, `125`, `128`, `129`, `131`, `37`, `107`, `106`, `109`, `110`, `112`, `27`, `100`, `99`, `102`, `103`, `105`, `16`, `93`, `92`, `95`, `96`, `98`, and `140`, plus i64 set locals `179`, `178`, `177`, `176`, and `175`; Binaryen allocates fresh one-use i32 locals `175..221` and fresh one-use i64 set locals `227..231`. Local-use analysis shows every differing local appears exactly once as the corresponding write target on its side.

Measured deltas: defined function `577` encodes smaller on Starshine (`2558` byte code body, `2552` instruction bytes, `6` local-declaration bytes) than Binaryen (`2595` / `2589` / `6`). Starshine declares `(169 i32, 5 i64)` body locals versus Binaryen `(216 i32, 10 i64)`, so this is both local-count reducing and encoded-body-size reducing. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `604` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count and encoded-body-size win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b36]` repeated one-shot temp-local classification at `abs=605`

`[SSANM-009b36]` follows the current self-artifact pair to `defined=578 abs=605`. Targeted `--print-func 605` extraction under `.tmp/ssanm009b35-next605` shows identical canonical `body_raw` token streams once local indexes are masked, with `221` local operations on both sides (`150` `local.get`, `40` `local.set`, and `31` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 20 one-use dead `local.tee` targets. Starshine reuses locals `7`, `8`, `14`, `63`, `16`, `17`, `38`, `24`, `66`, `26`, `57`, `42`, `29`, `69`, `31`, `32`, `43`, `50`, `53`, and `56`, while Binaryen allocates fresh one-use locals `73..92`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `578` encodes to the same `947` byte code body in both artifacts (`944` instruction bytes plus `3` local-declaration bytes). Starshine declares `71` body i32 locals versus Binaryen `91`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `605` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b37]` repeated one-shot temp-local classification at `abs=606`

`[SSANM-009b37]` follows the current self-artifact pair to `defined=579 abs=606`. Targeted `--print-func 606` extraction under `.tmp/ssanm009b36-next606` shows identical canonical `body_raw` token streams once local indexes are masked, with `169` local operations on both sides (`110` `local.get`, `35` `local.set`, and `24` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 14 one-use dead `local.tee` targets. Starshine reuses locals `7`, `8`, `18`, `47`, `46`, `33`, `27`, `54`, `29`, `30`, `41`, `39`, `40`, and `45`, while Binaryen allocates fresh one-use locals `60..73`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `579` encodes to the same `735` byte code body in both artifacts (`732` instruction bytes plus `3` local-declaration bytes). Starshine declares `58` body i32 locals versus Binaryen `72`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `606` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b38]` repeated one-shot temp-local classification at `abs=607`

`[SSANM-009b38]` follows the current self-artifact pair to `defined=580 abs=607`. Targeted `--print-func 607` extraction under `.tmp/ssanm009b37-next607` shows identical canonical `body_raw` token streams once local indexes are masked, with `187` local operations on both sides (`126` `local.get`, `36` `local.set`, and `25` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 15 one-use dead `local.tee` targets. Starshine reuses locals `8`, `9`, `19`, `50`, `49`, `30`, `57`, `32`, `33`, `40`, `36`, `44`, `42`, `43`, and `47`, while Binaryen allocates fresh one-use locals `63..77`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `580` encodes to the same `810` byte code body in both artifacts (`807` instruction bytes plus `3` local-declaration bytes). Starshine declares `60` body i32 locals versus Binaryen `75`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `607` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures). `abs=608` / `defined=581` matches after excluding the artifact-path log line.

## `[SSANM-009b39]` repeated one-shot temp-local classification at `abs=609`

`[SSANM-009b39]` follows the current self-artifact pair to `defined=582 abs=609`. Targeted `--print-func 609` extraction under `.tmp/ssanm009b38-next609` shows identical canonical `body_raw` token streams once local indexes are masked, with `174` local operations on both sides (`114` `local.get`, `27` `local.set`, and `33` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 12 one-use dead `local.tee` targets. Starshine reuses locals `38`, `6`, `7`, `8`, `17`, `55`, `19`, `20`, `30`, `27`, `29`, and `32`, while Binaryen allocates fresh one-use locals `60..71`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `582` encodes to the same `773` byte code body in both artifacts (`770` instruction bytes plus `3` local-declaration bytes). Starshine declares `59` body i32 locals versus Binaryen `71`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `609` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures). `abs=610` / `defined=583` matches exactly in targeted `--print-func` output.

## `[SSANM-009b40]` repeated one-shot temp-local classification at `abs=611`

`[SSANM-009b40]` follows the current self-artifact pair to `defined=584 abs=611`. Targeted `--print-func 611` extraction under `.tmp/ssanm009b40-next611` shows identical canonical `body_raw` token streams once local indexes are masked, with `180` local operations on both sides (`119` `local.get`, `28` `local.set`, and `33` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 12 one-use dead `local.tee` targets. Starshine reuses locals `40`, `7`, `8`, `9`, `19`, `57`, `21`, `22`, `31`, `28`, `30`, and `35`, while Binaryen allocates fresh one-use locals `62..73`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `584` encodes to the same `794` byte code body in both artifacts (`791` instruction bytes plus `3` local-declaration bytes). Starshine declares `60` body i32 locals versus Binaryen `72`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `611` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b41]` repeated one-shot temp-local classification at `abs=612`

`[SSANM-009b41]` follows the current self-artifact pair to `defined=585 abs=612`. Targeted `--print-func 612` extraction under `.tmp/ssanm009b41-next612` shows identical canonical `body_raw` token streams once local indexes are masked, with `163` local operations on both sides (`106` `local.get`, `24` `local.set`, and `33` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 12 one-use dead `local.tee` targets. Starshine reuses locals `36`, `7`, `8`, `9`, `18`, `53`, `20`, `21`, `27`, `25`, `26`, and `31`, while Binaryen allocates fresh one-use locals `58..69`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `585` encodes to the same `729` byte code body in both artifacts (`726` instruction bytes plus `3` local-declaration bytes). Starshine declares `56` body i32 locals versus Binaryen `68`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `612` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b42]` repeated one-shot temp-local classification at `abs=613`

`[SSANM-009b42]` follows the current self-artifact pair to `defined=586 abs=613`. Targeted `--print-func 613` extraction under `.tmp/ssanm-scan-next613` shows identical canonical `body_raw` token streams once local indexes are masked, with `136` local operations on both sides (`87` `local.get`, `19` `local.set`, and `30` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are nine one-use dead `local.tee` targets. Starshine reuses locals `28`, `5`, `6`, `7`, `11`, `45`, `13`, `14`, and `21`, while Binaryen allocates fresh one-use locals `50..58`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `586` encodes to the same `615` byte code body in both artifacts (`612` instruction bytes plus `3` local-declaration bytes). Starshine declares `49` body i32 locals versus Binaryen `58`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `613` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b43]` repeated one-shot temp-local classification at `abs=614`

`[SSANM-009b43]` follows the current self-artifact pair to `defined=587 abs=614`. Targeted `--print-func 614` extraction under `.tmp/ssanm009b43-next614` shows identical canonical `body_raw` token streams once local indexes are masked, with `121` local operations on both sides (`79` `local.get`, `22` `local.set`, and `20` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 10 one-use dead `local.tee` targets. Starshine reuses locals `6`, `7`, `15`, `35`, `17`, `19`, `38`, `21`, `22`, and `27`, while Binaryen allocates fresh one-use locals `43..52`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `587` encodes to the same `532` byte code body in both artifacts (`529` instruction bytes plus `3` local-declaration bytes). Starshine declares `42` body i32 locals versus Binaryen `52`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `614` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures).

## `[SSANM-009b44]` neutral local-slot permutation classification at `abs=615`

`[SSANM-009b44]` follows the current self-artifact pair to `defined=588 abs=615`. Targeted `--print-func 615` extraction under `.tmp/ssanm009b44-next615` shows identical canonical `body_raw` token streams once local indexes are masked, with `72` local operations on both sides (`50` `local.get`, `15` `local.set`, and `7` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are a same-type permutation among locals `26..30`: Starshine uses locals `26`, `27`, `28`, and `29` as one-use `local.tee` targets and local `30` for one set/get pair, while Binaryen uses `27`, `28`, `29`, and `30` as one-use `local.tee` targets and local `26` for the set/get pair. Local-use analysis shows the paired set/get stays paired on the same side-local and every differing tee target appears exactly once.

Measured deltas: defined function `588` encodes to the same `327` byte code body in both artifacts (`324` instruction bytes plus `3` local-declaration bytes). Both artifacts declare the same 26 body i32 locals, so this is local-count and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `615` reports `structured-local-writes`, so this remains artifact representation classification rather than a new mutation owner. Agent classification: semantic-safe neutral local-slot permutation / no-regression representation difference. No code or executable tests changed, so direct compare was not rerun beyond the current `.tmp/pass-fuzz-ssa-nomerge-ssanm009b14-classify-20260614` lane (`9977/10000`, `9977` normalized matches, `0` mismatches, `23` cached Binaryen/tool command failures). These were followed by `[SSANM-009b45]` through `[SSANM-009b48]`.

## `[SSANM-009b45]` repeated one-shot temp-local classification at `abs=616`

`[SSANM-009b45]` follows the current self-artifact pair to `defined=589 abs=616`. Targeted `--print-func 616` extraction under `.tmp/ssanm-scan-next616` shows identical canonical `body_raw` token streams once local indexes are masked, with `588` local operations on both sides (`391` `local.get`, `106` `local.set`, and `91` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 59 one-use same-typed write targets: 53 `local.tee` targets plus six `local.set` targets. Local-use analysis shows every differing local appears exactly once as a same-typed write target on its side. Starshine declares body locals `(190 i32, 5 i64)` versus Binaryen `(244 i32, 10 i64)`.

Measured deltas: defined function `589` is smaller on Starshine (`2931` byte body: `2925` instruction bytes plus `6` local-declaration bytes) than Binaryen (`2971` byte body: `2965` instruction bytes plus `6` local-declaration bytes). Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `616` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count and encoded-body-size win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b46]` repeated one-shot temp-local classification at `abs=617`

`[SSANM-009b46]` follows the current self-artifact pair to `defined=590 abs=617`. Targeted `--print-func 617` extraction under `.tmp/ssanm009b45-next617` shows identical canonical `body_raw` token streams once local indexes are masked, with `80` local operations on both sides (`54` `local.get`, `13` `local.set`, and `13` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are eight one-use dead `local.tee` targets. Starshine reuses locals `6`, `7`, `17`, `13`, `25`, `15`, `16`, and `21`, while Binaryen allocates fresh one-use locals `28..35`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `590` encodes to the same `341` byte code body in both artifacts (`338` instruction bytes plus `3` local-declaration bytes). Starshine declares `26` body i32 locals versus Binaryen `34`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `617` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b47]` neutral local-slot permutation classification at `abs=618`

`[SSANM-009b47]` follows the current self-artifact pair to `defined=591 abs=618`. Targeted `--print-func 618` extraction under `.tmp/ssanm009b46-next618` shows identical canonical `body_raw` token streams once local indexes are masked, with `72` local operations on both sides (`50` `local.get`, `15` `local.set`, and `7` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are a same-type permutation among locals `25..29`: Starshine uses locals `25`, `26`, `27`, and `28` as one-use `local.tee` targets and local `29` for one set/get pair, while Binaryen uses `26`, `27`, `28`, and `29` as one-use `local.tee` targets and local `25` for the set/get pair. Local-use analysis shows the paired set/get stays paired on the same side-local and every differing tee target appears exactly once.

Measured deltas: defined function `591` encodes to the same `329` byte code body in both artifacts (`326` instruction bytes plus `3` local-declaration bytes). Both artifacts declare the same 26 body i32 locals, so this is local-count and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `618` reports `structured-local-writes`, so this remains artifact representation classification rather than a new mutation owner. Agent classification: semantic-safe neutral local-slot permutation / no-regression representation difference, not an implementation gap.

## `[SSANM-009b48]` repeated one-shot temp-local classification at `abs=619`

`[SSANM-009b48]` follows the current self-artifact pair to `defined=592 abs=619`. Targeted `--print-func 619` extraction under `.tmp/ssanm009b47-next619` shows identical canonical `body_raw` token streams once local indexes are masked, with `240` local operations on both sides (`169` `local.get`, `35` `local.set`, and `36` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 20 one-use dead `local.tee` targets. Starshine reuses locals `18`, `57`, `20`, `21`, `60`, `23`, `24`, `64`, `63`, `26`, `27`, `67`, `31`, `42`, `39`, `35`, `13`, `54`, `44`, and `47`, while Binaryen allocates fresh one-use locals `73..92`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `592` encodes to the same `1089` byte code body in both artifacts (`1086` instruction bytes plus `3` local-declaration bytes). Starshine declares `69` body i32 locals versus Binaryen `89`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `619` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b49]` repeated one-shot temp-local classification at `abs=620`

`[SSANM-009b49]` follows the current self-artifact pair to `defined=593 abs=620`. Targeted `--print-func 620` extraction under `.tmp/ssanm009b48-next620` shows identical canonical `body_raw` token streams once local indexes are masked, with `171` local operations on both sides (`112` `local.get`, `36` `local.set`, and `23` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 13 one-use dead `local.tee` targets. Starshine reuses locals `6`, `7`, `18`, `46`, `45`, `27`, `53`, `29`, `30`, `40`, `37`, `39`, and `43`, while Binaryen allocates fresh one-use locals `59..71`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `593` encodes to the same `738` byte code body in both artifacts (`735` instruction bytes plus `3` local-declaration bytes). Starshine declares `58` body i32 locals versus Binaryen `71`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `620` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b50]` repeated one-shot temp-local classification at `abs=621`

`[SSANM-009b50]` follows the current self-artifact pair to `defined=594 abs=621`. Targeted `--print-func 621` extraction under `.tmp/ssanm009b49-next621` shows identical canonical `body_raw` token streams once local indexes are masked, with `181` local operations on both sides (`118` `local.get`, `38` `local.set`, and `25` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 15 one-use dead `local.tee` targets. Starshine reuses locals `7`, `8`, `17`, `55`, `19`, `40`, `34`, `39`, `26`, `58`, `28`, `29`, `47`, `46`, and `49`, while Binaryen allocates fresh one-use locals `63..77`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `594` encodes to the same `799` byte code body in both artifacts (`796` instruction bytes plus `3` local-declaration bytes). Starshine declares `62` body i32 locals versus Binaryen `77`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `621` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b51]` repeated one-shot temp-local classification at `abs=622`

`[SSANM-009b51]` follows the current self-artifact pair to `defined=595 abs=622`. Targeted `--print-func 622` extraction under `.tmp/ssanm009b49-next622` shows identical canonical `body_raw` token streams once local indexes are masked, with `119` local operations on both sides (`78` `local.get`, `17` `local.set`, and `24` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are five one-use dead `local.tee` targets. Starshine reuses locals `23`, `5`, `6`, `7`, and `18`, while Binaryen allocates fresh one-use locals `42..46`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `595` encodes to the same `542` byte code body in both artifacts (`539` instruction bytes plus `3` local-declaration bytes). Starshine declares `41` body i32 locals versus Binaryen `46`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `622` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new mutation owner. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b52]` repeated one-shot temp-local classification at `abs=624`

`[SSANM-009b52]` follows the current self-artifact pair to `defined=597 abs=624` after targeted `abs=623` output matched exactly. Targeted `--print-func 624` extraction under `.tmp/ssanm009b51-next624` shows identical canonical `body_raw` token streams once local indexes are masked, with `194` local operations on both sides (`125` `local.get`, `39` `local.set`, and `30` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 18 one-use dead `local.tee` targets. Starshine reuses locals `7`, `8`, `20`, `61`, `22`, `23`, `17`, `58`, `19`, `40`, `39`, `30`, `64`, `32`, `33`, `49`, `48`, and `51`, while Binaryen allocates fresh one-use locals `69..86`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `597` encodes to the same `854` byte code body in both artifacts (`851` instruction bytes plus `3` local-declaration bytes). Starshine declares `68` body i32 locals versus Binaryen `86`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `624` reports `structured-local-writes`, so this remains artifact representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b53]` repeated one-shot temp-local classification at `abs=625`

`[SSANM-009b53]` follows the current self-artifact pair to `defined=598 abs=625`. Targeted `--print-func 625` extraction under `.tmp/ssanm009b51-next625` shows identical canonical `body_raw` token streams once local indexes are masked, with `86` local operations on both sides (`56` `local.get`, `18` `local.set`, and `12` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are seven one-use dead `local.tee` targets. Starshine reuses locals `7`, `8`, `14`, `28`, `16`, `17`, and `23`, while Binaryen allocates fresh one-use locals `31..37`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `598` encodes to the same `353` byte code body in both artifacts (`350` instruction bytes plus `3` local-declaration bytes). Starshine declares `30` body i32 locals versus Binaryen `37`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `625` reports `structured-local-writes`, so this remains artifact representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b54]` structured helper one-use temp classification at `abs=626`

`[SSANM-009b54]` follows the current self-artifact pair to `defined=599 abs=626`. Targeted `--print-func 626` extraction under `.tmp/ssanm009b51-next626` shows identical canonical `body_raw` token streams once local indexes are masked, with `576` local operations on both sides (`383` `local.get`, `98` `local.set`, and `95` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 62 one-use same-typed write targets: 55 `local.tee` targets plus seven dead `local.set` targets. Starshine declares `191` body i32 locals versus Binaryen `253`; Binaryen allocates the differing locals as fresh one-use locals `195..256`, while Starshine reuses one-use same-typed local slots.

Measured deltas: defined function `599` is smaller on Starshine (`2932` byte body: `2928` instruction bytes plus `4` local-declaration bytes) than Binaryen (`2974` byte body: `2970` instruction bytes plus `4` local-declaration bytes). Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `626` reports `structured-local-writes-mutated`, so this is a structured helper output-shape classification, not a new semantic gap. Agent classification: semantic-safe Starshine local-count and encoded-body-size win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b55]` repeated one-shot temp-local classification at `abs=627`

`[SSANM-009b55]` follows the current self-artifact pair to `defined=600 abs=627`. Targeted `--print-func 627` extraction under `.tmp/ssanm009b54-next627` shows identical canonical `body_raw` token streams once local indexes are masked, with `98` local operations on both sides (`66` `local.get`, `18` `local.set`, and `14` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are seven one-use dead `local.tee` targets. Starshine reuses locals `7`, `8`, `13`, `29`, `15`, `16`, and `23`, while Binaryen allocates fresh one-use locals `34..40`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `600` encodes to the same `423` byte code body in both artifacts (`420` instruction bytes plus `3` local-declaration bytes). Starshine declares `32` body i32 locals versus Binaryen `39`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `627` reports `multiparam-value-if-branch-carrier-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b56]` neutral local-slot classification at `abs=628`

`[SSANM-009b56]` follows the current self-artifact pair to `defined=601 abs=628`. Targeted `--print-func 628` extraction under `.tmp/ssanm009b55-next628` shows identical canonical `body_raw` token streams once local indexes are masked, with `73` local operations on both sides (`51` `local.get`, `15` `local.set`, and `7` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences form a same-typed local-slot permutation: Starshine uses locals `26`, `27`, `28`, and `29` for one-use `local.tee` targets and local `30` for one `local.set` / `local.get` pair; Binaryen uses locals `27`, `28`, `29`, and `30` for the one-use tee targets and local `26` for the set/get pair.

Measured deltas: defined function `601` encodes to the same `331` byte code body in both artifacts (`328` instruction bytes plus `3` local-declaration bytes), and both sides declare `26` body i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `628` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe neutral local-slot permutation / no-regression representation difference, not an implementation gap.

## `[SSANM-009b57]` repeated one-shot temp-local classification at `abs=629`

`[SSANM-009b57]` follows the current self-artifact pair to `defined=602 abs=629`. Targeted `--print-func 629` extraction under `.tmp/ssanm009b55-next629` shows identical canonical `body_raw` token streams once local indexes are masked, with `158` local operations on both sides (`113` `local.get`, `19` `local.set`, and `26` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 15 one-use dead `local.tee` targets. Starshine reuses locals `39`, `19`, `20`, `21`, `22`, `24`, `25`, `27`, `28`, `33`, `35`, `16`, `42`, `37`, and `38`, while Binaryen allocates fresh one-use locals `47..61`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `602` encodes to the same `733` byte code body in both artifacts (`730` instruction bytes plus `3` local-declaration bytes). Starshine declares `42` body i32 locals versus Binaryen `57`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `629` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b58]` repeated one-shot temp-local classification at `abs=630`

`[SSANM-009b58]` follows the current self-artifact pair to `defined=603 abs=630`. Targeted `--print-func 630` extraction under `.tmp/ssanm009b55-next630` shows identical canonical `body_raw` token streams once local indexes are masked, with `193` local operations on both sides (`130` `local.get`, `38` `local.set`, and `25` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 15 one-use dead `local.tee` targets. Starshine reuses locals `8`, `9`, `19`, `52`, `51`, `31`, `59`, `33`, `34`, `46`, `37`, `42`, `40`, `41`, and `45`, while Binaryen allocates fresh one-use locals `65..79`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `603` encodes to the same `831` byte code body in both artifacts (`828` instruction bytes plus `3` local-declaration bytes). Starshine declares `62` body i32 locals versus Binaryen `77`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `630` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b59]` repeated one-shot temp-local classification at `abs=631`

`[SSANM-009b59]` follows the current self-artifact pair to `defined=604 abs=631`. Targeted `--print-func 631` extraction under `.tmp/ssanm009b55-next631` shows identical canonical `body_raw` token streams once local indexes are masked, with `154` local operations on both sides (`99` `local.get`, `32` `local.set`, and `23` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 13 one-use dead `local.tee` targets. Starshine reuses locals `6`, `7`, `17`, `42`, `41`, `26`, `49`, `28`, `29`, `36`, `34`, `35`, and `39`, while Binaryen allocates fresh one-use locals `55..67`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `604` encodes to the same `673` byte code body in both artifacts (`670` instruction bytes plus `3` local-declaration bytes). Starshine declares `54` body i32 locals versus Binaryen `67`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `631` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b60]` repeated one-shot temp-local classification at `abs=632`

`[SSANM-009b60]` follows the current self-artifact pair to `defined=605 abs=632`. Targeted `--print-func 632` extraction under `.tmp/ssanm009b59-next632` shows identical canonical `body_raw` token streams once local indexes are masked, with `136` local operations on both sides (`87` `local.get`, `19` `local.set`, and `30` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are nine one-use dead `local.tee` targets. Starshine reuses locals `28`, `5`, `6`, `7`, `11`, `45`, `13`, `14`, and `21`, while Binaryen allocates fresh one-use locals `50..58`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `605` encodes to the same `615` byte code body in both artifacts (`612` instruction bytes plus `3` local-declaration bytes). Starshine declares `49` body i32 locals versus Binaryen `58`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `632` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b61]` neutral local-slot classification at `abs=633`

`[SSANM-009b61]` follows the current self-artifact pair to `defined=606 abs=633`. Targeted `--print-func 633` extraction under `.tmp/ssanm009b59-next633` shows identical canonical `body_raw` token streams once local indexes are masked, with `70` local operations on both sides (`45` `local.get`, `15` `local.set`, and `10` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences form a same-typed local-slot permutation among six one-use `local.tee` targets, two `local.set` / `local.get` pairs, and one dead set-only slot. Starshine uses tee targets `25`, `26`, `27`, `28`, `30`, and `31`, set/get pairs on `32` and `33`, and set-only slot `29`; Binaryen uses tee targets `27`, `28`, `29`, `30`, `32`, and `33`, set/get pairs on `25` and `26`, and set-only slot `31`.

Measured deltas: defined function `606` encodes to the same `342` byte code body in both artifacts (`339` instruction bytes plus `3` local-declaration bytes), and both sides declare `32` body i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `633` reports `call-heavy-memory-structured-noop`, so this remains representation classification rather than a new parity gap. Agent classification: semantic-safe neutral local-slot permutation / no-regression representation difference, not an implementation gap.

## `[SSANM-009b62]` repeated one-shot temp-local classification at `abs=634`

`[SSANM-009b62]` follows the current self-artifact pair to `defined=607 abs=634`. Targeted `--print-func 634` extraction under `.tmp/ssanm009b59-next634` shows identical canonical `body_raw` token streams once local indexes are masked, with `205` local operations on both sides (`133` `local.get`, `33` `local.set`, and `39` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 16 one-use dead `local.tee` targets. Starshine reuses locals `47`, `6`, `7`, `8`, `23`, `67`, `25`, `26`, `37`, `19`, `64`, `21`, `22`, `34`, `36`, and `39`, while Binaryen allocates fresh one-use locals `72..87`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `607` encodes to the same `913` byte code body in both artifacts (`910` instruction bytes plus `3` local-declaration bytes). Starshine declares `71` body i32 locals versus Binaryen `87`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `634` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b63]` neutral local-slot classification at `abs=635`

`[SSANM-009b63]` follows the current self-artifact pair to `defined=608 abs=635`. Targeted `--print-func 635` extraction under `.tmp/ssanm009b59-next635` shows identical canonical `body_raw` token streams once local indexes are masked, with `62` local operations on both sides (`43` `local.get`, `13` `local.set`, and `6` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences form a same-typed local-slot permutation. Starshine uses locals `22`, `23`, `24`, and `25` for one-use `local.tee` targets and local `26` for one `local.set` / `local.get` pair; Binaryen uses locals `23`, `24`, `25`, and `26` for the one-use tee targets and local `22` for the set/get pair.

Measured deltas: defined function `608` encodes to the same `279` byte code body in both artifacts (`276` instruction bytes plus `3` local-declaration bytes), and both sides declare `23` body i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `635` reports `structured-local-writes`, so this remains representation classification rather than a new parity gap. Agent classification: semantic-safe neutral local-slot permutation / no-regression representation difference, not an implementation gap.

## `[SSANM-009b64]` repeated one-shot temp-local classification at `abs=636`

`[SSANM-009b64]` follows the current self-artifact pair to `defined=609 abs=636`. Targeted `--print-func 636` extraction under `.tmp/ssanm009b63-next636` shows identical canonical `body_raw` token streams once local indexes are masked, with `233` local operations on both sides (`155` `local.get`, `40` `local.set`, and `38` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 15 one-use dead `local.tee` targets. Starshine reuses locals `54`, `7`, `8`, `9`, `31`, `24`, `71`, `26`, `27`, `34`, `33`, `44`, `41`, `43`, and `46`, while Binaryen allocates fresh one-use locals `78..92`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `609` encodes to the same `1030` byte code body in both artifacts (`1027` instruction bytes plus `3` local-declaration bytes). Starshine declares `76` body i32 locals versus Binaryen `91`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `636` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b65]` neutral local-slot classification at `abs=637`

`[SSANM-009b65]` follows the current self-artifact pair to `defined=610 abs=637`. Targeted `--print-func 637` extraction under `.tmp/ssanm009b64-next637` shows identical canonical `body_raw` token streams once local indexes are masked, with `70` local operations on both sides (`48` `local.get`, `15` `local.set`, and `7` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences form a same-typed local-slot permutation. Starshine uses locals `25`, `26`, `27`, and `28` for one-use `local.tee` targets and local `29` for one `local.set` / `local.get` pair; Binaryen uses locals `26`, `27`, `28`, and `29` for the one-use tee targets and local `25` for the set/get pair.

Measured deltas: defined function `610` encodes to the same `321` byte code body in both artifacts (`318` instruction bytes plus `3` local-declaration bytes), and both sides declare `26` body i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `637` reports `straight-line-local-writes-localgraph-plan`, so this is LocalGraph-plan output-shape classification rather than a new parity gap. Agent classification: semantic-safe neutral local-slot permutation / no-regression representation difference, not an implementation gap.

## `[SSANM-009b66]` repeated one-shot temp-local classification at `abs=638`

`[SSANM-009b66]` follows the current self-artifact pair to `defined=611 abs=638`. Targeted `--print-func 638` extraction under `.tmp/ssanm009b64-next638` shows identical canonical `body_raw` token streams once local indexes are masked, with `178` local operations on both sides (`118` `local.get`, `31` `local.set`, and `29` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 16 one-use dead `local.tee` targets. Starshine reuses locals `14`, `46`, `16`, `17`, `49`, `19`, `20`, `53`, `52`, `22`, `23`, `56`, `27`, `37`, `34`, and `40`, while Binaryen allocates fresh one-use locals `62..77`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `611` encodes to the same `774` byte code body in both artifacts (`771` instruction bytes plus `3` local-declaration bytes). Starshine declares `58` body i32 locals versus Binaryen `74`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `638` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b67]` repeated one-shot temp-local classification at `abs=639`

`[SSANM-009b67]` follows the current self-artifact pair to `defined=612 abs=639`. Targeted `--print-func 639` extraction under `.tmp/ssanm009b64-next639` shows identical canonical `body_raw` token streams once local indexes are masked, with `132` local operations on both sides (`91` `local.get`, `25` `local.set`, and `16` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 10 one-use dead `local.tee` targets. Starshine reuses locals `7`, `8`, `17`, `39`, `19`, `20`, `23`, `29`, `32`, and `35`, while Binaryen allocates fresh one-use locals `43..52`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `612` encodes to the same `565` byte code body in both artifacts (`562` instruction bytes plus `3` local-declaration bytes). Starshine declares `41` body i32 locals versus Binaryen `51`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `639` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b68]` larger one-shot temp-local classification at `abs=640`

`[SSANM-009b68]` follows the current self-artifact pair to `defined=613 abs=640`. Targeted `--print-func 640` extraction under `.tmp/ssanm009b64-next640` shows identical canonical `body_raw` token streams once local indexes are masked, with `531` local operations on both sides (`355` `local.get`, `95` `local.set`, and `81` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 51 one-use same-typed write targets: 46 `local.tee` targets plus five dead `local.set` targets. Starshine reuses locals `90`, `92`, `63`, `64`, `65`, `66`, `68`, `69`, `71`, `72`, `77`, `84`, `138`, `137`, `139`, `141`, `142`, `144`, `50`, `151`, `52`, `123`, `59`, `129`, `128`, `130`, `132`, `133`, `135`, `38`, `110`, `109`, `111`, `113`, `114`, `116`, `28`, `102`, `101`, `103`, `105`, `106`, `108`, `17`, `94`, `93`, `95`, `97`, `98`, `100`, and `146`, while Binaryen allocates fresh one-use locals `181..231`. Local-use analysis shows every differing local appears exactly once as a same-typed write target on its side.

Measured deltas: defined function `613` is smaller on Starshine (`2602` byte body: `2598` instruction bytes plus `4` local-declaration bytes) than Binaryen (`2639` byte body: `2635` instruction bytes plus `4` local-declaration bytes). Starshine declares `174` body i32 locals versus Binaryen `225`, so this is both local-count reducing and encoded-body-size reducing. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `640` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count and encoded-body-size win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b69]` larger one-shot temp-local classification at `abs=641`

`[SSANM-009b69]` follows the current self-artifact pair to `defined=614 abs=641`. Targeted `--print-func 641` extraction under `.tmp/ssanm009b68-next641` shows identical canonical `body_raw` token streams once local indexes are masked, with `1028` local operations on both sides (`845` `local.get`, `69` `local.set`, and `114` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 39 one-use dead `local.tee` targets. Starshine reuses locals `85`, `84`, `83`, `46`, `48`, `50`, `52`, `54`, `56`, `148`, `58`, `151`, `60`, `155`, `154`, `62`, `158`, `64`, `82`, `81`, `80`, `79`, `78`, `41`, `75`, `121`, `34`, `35`, `29`, `74`, `71`, `102`, `22`, `23`, `17`, `70`, `67`, `7`, and `65`, while Binaryen allocates fresh one-use locals `181..219`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `614` is smaller on Starshine (`6063` byte body: `6059` instruction bytes plus `4` local-declaration bytes) than Binaryen (`6097` byte body: `6093` instruction bytes plus `4` local-declaration bytes). Starshine declares `178` body i32 locals versus Binaryen `217`, so this is both local-count reducing and encoded-body-size reducing. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `641` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count and encoded-body-size win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b70]` repeated one-shot temp-local classification at `abs=642`

`[SSANM-009b70]` follows the current self-artifact pair to `defined=615 abs=642`. Targeted `--print-func 642` extraction under `.tmp/ssanm009b69-next642` shows identical canonical `body_raw` token streams once local indexes are masked, with `136` local operations on both sides (`88` `local.get`, `15` `local.set`, and `33` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are eight one-use dead `local.tee` targets. Starshine reuses locals `20`, `19`, `15`, `27`, `12`, `13`, `7`, and `16`, while Binaryen allocates fresh one-use locals `50..57`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `615` encodes to the same `629` byte code body in both artifacts (`626` instruction bytes plus `3` local-declaration bytes). Starshine declares `48` body i32 locals versus Binaryen `56`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `642` reports `structured-local-writes`, so this remains representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b71]` repeated one-shot temp-local classification at `abs=643`

`[SSANM-009b71]` follows the current self-artifact pair to `defined=616 abs=643`. Targeted `--print-func 643` extraction under `.tmp/ssanm009b69-next643` shows identical canonical `body_raw` token streams once local indexes are masked, with `136` local operations on both sides (`87` `local.get`, `19` `local.set`, and `30` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are nine one-use dead `local.tee` targets. Starshine reuses locals `28`, `5`, `6`, `7`, `11`, `45`, `13`, `14`, and `21`, while Binaryen allocates fresh one-use locals `50..58`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `616` encodes to the same `615` byte code body in both artifacts (`612` instruction bytes plus `3` local-declaration bytes). Starshine declares `49` body i32 locals versus Binaryen `58`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `643` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b72]` repeated one-shot temp-local classification at `abs=644`

`[SSANM-009b72]` follows the current self-artifact pair to `defined=617 abs=644`. Targeted `--print-func 644` extraction under `.tmp/ssanm009b69-next644` shows identical canonical `body_raw` token streams once local indexes are masked, with `83` local operations on both sides (`53` `local.get`, `18` `local.set`, and `12` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 10 one-use same-typed write targets: nine `local.tee` targets plus one dead `local.set` target. Starshine reuses locals `11`, `23`, `15`, `18`, `26`, `27`, `16`, `4`, `21`, and `25`, while Binaryen allocates fresh one-use locals `32..41`. Local-use analysis shows every differing local appears exactly once as a same-typed write target on its side.

Measured deltas: defined function `617` encodes to the same `399` byte code body in both artifacts (`396` instruction bytes plus `3` local-declaration bytes). Starshine declares `30` body i32 locals versus Binaryen `40`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `644` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b73]` repeated one-shot temp-local classification at `abs=645`

`[SSANM-009b73]` follows the current self-artifact pair to `defined=618 abs=645`. Targeted `--print-func 645` extraction under `.tmp/ssanm009b69-next645` shows identical canonical `body_raw` token streams once local indexes are masked, with `115` local operations on both sides (`73` `local.get`, `22` `local.set`, and `20` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 10 one-use dead `local.tee` targets. Starshine reuses locals `6`, `7`, `15`, `35`, `17`, `19`, `38`, `21`, `22`, and `27`, while Binaryen allocates fresh one-use locals `43..52`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `618` encodes to the same `505` byte code body in both artifacts (`502` instruction bytes plus `3` local-declaration bytes). Starshine declares `42` body i32 locals versus Binaryen `52`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `645` reports `structured-local-writes`, so this remains representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b74]` repeated one-shot temp-local classification at `abs=646`

`[SSANM-009b74]` follows the current self-artifact pair to `defined=619 abs=646`. Targeted `--print-func 646` extraction under `.tmp/ssanm009b73-next646` shows identical canonical `body_raw` token streams once local indexes are masked, with `140` local operations on both sides (`89` `local.get`, `30` `local.set`, and `21` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 16 one-use same-typed write targets: 14 `local.tee` targets plus two dead `local.set` targets. Starshine reuses locals `19`, `41`, `23`, `36`, `44`, `45`, `34`, `5`, `33`, `25`, `26`, `46`, `9`, `32`, `39`, and `43`, while Binaryen allocates fresh one-use locals `54..69`. Local-use analysis shows every differing local appears exactly once as a same-typed write target on its side.

Measured deltas: defined function `619` encodes to the same `689` byte code body in both artifacts (`686` instruction bytes plus `3` local-declaration bytes). Starshine declares `51` body i32 locals versus Binaryen `67`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `646` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

Targeted `abs=647` / `defined=620` output matches exactly (`17` byte code bodies with three body i32 locals), so the next classification candidate skips to `abs=648`.

## `[SSANM-009b75]` repeated one-shot temp-local classification at `abs=648`

`[SSANM-009b75]` follows the current self-artifact pair to `defined=621 abs=648`. Targeted `--print-func 648` extraction under `.tmp/ssanm009b74-next648` shows identical canonical `body_raw` token streams once local indexes are masked, with `80` local operations on both sides (`54` `local.get`, `13` `local.set`, and `13` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are eight one-use dead `local.tee` targets. Starshine reuses locals `6`, `7`, `17`, `13`, `25`, `15`, `16`, and `21`, while Binaryen allocates fresh one-use locals `28..35`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `621` encodes to the same `341` byte code body in both artifacts (`338` instruction bytes plus `3` local-declaration bytes). Starshine declares `26` body i32 locals versus Binaryen `34`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `648` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b76]` local-slot permutation classification at `abs=649`

`[SSANM-009b76]` follows the current self-artifact pair to `defined=622 abs=649`. Targeted `--print-func 649` extraction under `.tmp/ssanm009b74-next649` shows identical canonical `body_raw` token streams once local indexes are masked, with `72` local operations on both sides (`50` `local.get`, `15` `local.set`, and `7` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are four one-use `local.tee` targets plus one set/get pair. Starshine uses tee locals `25`, `26`, `27`, and `28` plus set/get local `29`; Binaryen uses tee locals `26`, `27`, `28`, and `29` plus set/get local `25`. Local-use analysis shows the differing slots are same-typed and either one-use or paired on one local.

Measured deltas: defined function `622` encodes to the same `329` byte code body in both artifacts (`326` instruction bytes plus `3` local-declaration bytes), and both declare `26` body i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `649` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe neutral local-slot drift, not an implementation gap.

## `[SSANM-009b77]` repeated one-shot temp-local classification at `abs=650`

`[SSANM-009b77]` follows the current self-artifact pair to `defined=623 abs=650`. Targeted `--print-func 650` extraction under `.tmp/ssanm009b74-next650` shows identical canonical `body_raw` token streams once local indexes are masked, with `239` local operations on both sides (`169` `local.get`, `35` `local.set`, and `35` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 19 one-use dead `local.tee` targets. Starshine reuses locals `18`, `56`, `20`, `21`, `59`, `23`, `24`, `63`, `62`, `26`, `27`, `66`, `31`, `41`, `38`, `13`, `53`, `43`, and `46`, while Binaryen allocates fresh one-use locals `72..90`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `623` encodes to the same `1086` byte code body in both artifacts (`1083` instruction bytes plus `3` local-declaration bytes). Starshine declares `68` body i32 locals versus Binaryen `87`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `650` reports `structured-local-writes`, so this remains representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b78]` repeated one-shot temp-local classification at `abs=651`

`[SSANM-009b78]` follows the current self-artifact pair to `defined=624 abs=651`. Targeted `--print-func 651` extraction under `.tmp/ssanm009b77-next651` shows identical canonical `body_raw` token streams once local indexes are masked, with `162` local operations on both sides (`104` `local.get`, `32` `local.set`, and `26` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 15 one-use dead `local.tee` targets. Starshine reuses locals `7`, `8`, `29`, `15`, `49`, `17`, `32`, `34`, `25`, `52`, `27`, `28`, `41`, `40`, and `43`, while Binaryen allocates fresh one-use locals `58..72`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `624` encodes to the same `728` byte code body in both artifacts (`725` instruction bytes plus `3` local-declaration bytes). Starshine declares `57` body i32 locals versus Binaryen `72`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `651` reports `structured-local-writes`, so this remains representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b79]` repeated one-shot temp-local classification at `abs=652`

`[SSANM-009b79]` follows the current self-artifact pair to `defined=625 abs=652`. Targeted `--print-func 652` extraction under `.tmp/ssanm009b78-next652` shows identical canonical `body_raw` token streams once local indexes are masked, with `171` local operations on both sides (`112` `local.get`, `36` `local.set`, and `23` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 13 one-use dead `local.tee` targets. Starshine reuses locals `6`, `7`, `18`, `46`, `45`, `27`, `53`, `29`, `30`, `40`, `37`, `39`, and `43`, while Binaryen allocates fresh one-use locals `59..71`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `625` encodes to the same `738` byte code body in both artifacts (`735` instruction bytes plus `3` local-declaration bytes). Starshine declares `58` body i32 locals versus Binaryen `71`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `652` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b80]` local-slot permutation classification at `abs=653`

`[SSANM-009b80]` follows the current self-artifact pair to `defined=626 abs=653`. Targeted `--print-func 653` extraction under `.tmp/ssanm009b78-next653` shows identical canonical `body_raw` token streams once local indexes are masked, with `67` local operations on both sides (`45` `local.get`, `15` `local.set`, and `7` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are four one-use `local.tee` targets plus one set/get pair. Starshine uses tee locals `23`, `24`, `25`, and `26` plus set/get local `27`; Binaryen uses tee locals `24`, `25`, `26`, and `27` plus set/get local `23`. Local-use analysis shows the differing slots are same-typed and either one-use or paired on one local.

Measured deltas: defined function `626` encodes to the same `313` byte code body in both artifacts (`310` instruction bytes plus `3` local-declaration bytes), and both declare `26` body i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `653` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe neutral local-slot drift, not an implementation gap.

## `[SSANM-009b81]` repeated one-shot temp-local classification at `abs=654`

`[SSANM-009b81]` follows the current self-artifact pair to `defined=627 abs=654`. Targeted `--print-func 654` extraction under `.tmp/ssanm009b78-next654` shows identical canonical `body_raw` token streams once local indexes are masked, with `168` local operations on both sides (`109` `local.get`, `36` `local.set`, and `23` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 13 one-use dead `local.tee` targets. Starshine reuses locals `6`, `7`, `18`, `46`, `45`, `27`, `53`, `29`, `30`, `40`, `37`, `39`, and `43`, while Binaryen allocates fresh one-use locals `59..71`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `627` encodes to the same `721` byte code body in both artifacts (`718` instruction bytes plus `3` local-declaration bytes). Starshine declares `58` body i32 locals versus Binaryen `71`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `654` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b82]` repeated one-shot temp-local classification at `abs=655`

`[SSANM-009b82]` follows the current self-artifact pair to `defined=628 abs=655`. Targeted `--print-func 655` extraction under `.tmp/ssanm009b78-next655` shows identical canonical `body_raw` token streams once local indexes are masked, with `93` local operations on both sides (`62` `local.get`, `20` `local.set`, and `11` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are eight one-use dead `local.tee` targets. Starshine reuses locals `15`, `26`, `19`, `21`, `29`, `30`, `24`, and `28`, while Binaryen allocates fresh one-use locals `35..42`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `628` encodes to the same `431` byte code body in both artifacts (`428` instruction bytes plus `3` local-declaration bytes). Starshine declares `31` body i32 locals versus Binaryen `39`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `655` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b83]` repeated one-shot temp-local classification at `abs=656`

`[SSANM-009b83]` follows the current self-artifact pair to `defined=629 abs=656`. Targeted `--print-func 656` extraction under `.tmp/ssanm009b82-next656` shows identical canonical `body_raw` token streams once local indexes are masked, with `209` local operations on both sides (`151` `local.get`, `27` `local.set`, and `31` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 11 one-use dead `local.tee` targets. Starshine reuses locals `49`, `17`, `18`, `19`, `24`, `66`, `26`, `27`, `31`, `42`, and `45`, while Binaryen allocates fresh one-use locals `70..80`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `629` encodes to the same `882` byte code body in both artifacts (`879` instruction bytes plus `3` local-declaration bytes). Starshine declares `58` body i32 locals versus Binaryen `69`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `656` reports `structured-local-writes`, so this remains representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference.

## `[SSANM-009b84]` local-slot permutation classification at `abs=658`

`[SSANM-009b84]` skips targeted exact `defined=630 abs=657` and follows the current self-artifact pair to `defined=631 abs=658`. Targeted `--print-func 658` extraction under `.tmp/ssanm009b83-next658` shows identical canonical `body_raw` token streams once local indexes are masked, with `67` local operations on both sides (`45` `local.get`, `15` `local.set`, and `7` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are four one-use `local.tee` targets plus one set/get pair. Starshine uses tee locals `23`, `24`, `25`, and `26` plus set/get local `27`; Binaryen uses tee locals `24`, `25`, `26`, and `27` plus set/get local `23`. Local-use analysis shows the differing slots are same-typed and either one-use or paired on one local.

Measured deltas: defined function `631` encodes to the same `313` byte code body in both artifacts (`310` instruction bytes plus `3` local-declaration bytes), and both declare `26` body i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `658` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe neutral local-slot drift.

## `[SSANM-009b85]` local-slot permutation classification at `abs=659`

`[SSANM-009b85]` follows the current self-artifact pair to `defined=632 abs=659`. Targeted `--print-func 659` extraction under `.tmp/ssanm009b83-next659` shows identical canonical `body_raw` token streams once local indexes are masked, with `117` local operations on both sides (`67` `local.get`, `29` `local.set`, and `21` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The local-token differences are a same-typed permutation among 12 one-use `local.tee` targets, one set-only slot, and two set/get pairs. Starshine puts the set/get pairs on locals `60` and `61`, while Binaryen puts them on locals `47` and `48`; the one-use set-only slot is Starshine local `50` versus Binaryen local `52`. Local-use analysis shows every differing local is same-typed and either one-use or paired on one local.

Measured deltas: defined function `632` encodes to the same `503` byte code body in both artifacts (`500` instruction bytes plus `3` local-declaration bytes), and both declare `60` body i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `659` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe neutral local-slot drift.

## `[SSANM-009b86]` repeated one-shot temp-local classification at `abs=660`

`[SSANM-009b86]` follows the current self-artifact pair to `defined=633 abs=660`. Targeted `--print-func 660` extraction under `.tmp/ssanm009b83-next660` shows identical canonical `body_raw` token streams once local indexes are masked, with `136` local operations on both sides (`87` `local.get`, `19` `local.set`, and `30` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are nine one-use dead `local.tee` targets. Starshine reuses locals `28`, `5`, `6`, `7`, `11`, `45`, `13`, `14`, and `21`, while Binaryen allocates fresh one-use locals `50..58`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `633` encodes to the same `615` byte code body in both artifacts (`612` instruction bytes plus `3` local-declaration bytes). Starshine declares `49` body i32 locals versus Binaryen `58`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `660` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference.

## `[SSANM-009b87]` mixed i32/i64 temp-local classification at `abs=661`

`[SSANM-009b87]` follows the current self-artifact pair to `defined=634 abs=661`. Targeted `--print-func 661` extraction under `.tmp/ssanm009b83-next661` shows identical canonical `body_raw` token streams once local indexes are masked, with `222` local operations on both sides (`139` `local.get`, `52` `local.set`, and `31` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The local-token differences are same-typed local reuse/permutation: 12 one-use i32 `local.tee` targets, three one-use i64 `local.tee` targets, and three same-typed i64 tee/get pairs. Local-use analysis shows every differing local is same-typed and either one-use or paired on one tee/get slot.

Measured deltas: defined function `634` encodes to the same `1001` byte code body in both artifacts (`996` instruction bytes plus `5` local-declaration bytes). Starshine declares `(73 i32, 6 i64)` body locals versus Binaryen `(85 i32, 9 i64)`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `661` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine mixed i32/i64 local-count win / no-regression representation difference.

## `[SSANM-009b88]` repeated one-shot temp-local classification at `abs=663`

`[SSANM-009b88]` skips targeted exact `defined=635 abs=662` output, then follows the current self-artifact pair to `defined=636 abs=663`. Targeted `--print-func 663` extraction under `.tmp/ssanm009b87-next663` shows identical canonical `body_raw` token streams once local indexes are masked, with `165` local operations on both sides (`106` `local.get`, `30` `local.set`, and `29` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The local-token differences are 16 one-use `local.tee` targets plus one one-use `local.set` target. Starshine reuses locals `34`, `7`, `43`, `12`, `13`, `46`, `15`, `16`, `50`, `49`, `18`, `19`, `53`, `23`, `33`, `30`, and `37`, while Binaryen allocates fresh one-use locals `59..75`. Local-use analysis shows every differing local appears exactly once as a same-typed write target on its side.

Measured deltas: defined function `636` encodes to the same `772` byte code body in both artifacts (`769` instruction bytes plus `3` local-declaration bytes). Starshine declares `57` body i32 locals versus Binaryen `74`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `663` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b89]` repeated one-shot temp-local classification at `abs=664`

`[SSANM-009b89]` follows the current self-artifact pair to `defined=637 abs=664`. Targeted `--print-func 664` extraction under `.tmp/ssanm009b87-next664` shows identical canonical `body_raw` token streams once local indexes are masked, with `440` local operations on both sides (`302` `local.get`, `90` `local.set`, and `48` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 30 one-use dead `local.tee` targets. Starshine reuses locals `7`, `8`, `51`, `29`, `118`, `31`, `32`, `63`, `55`, `58`, `61`, `62`, `74`, `69`, `72`, `73`, `76`, `80`, `83`, `101`, `47`, `100`, `99`, `98`, `92`, `86`, `88`, `90`, `91`, and `95`, while Binaryen allocates fresh one-use locals `135..164`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `637` encodes smaller in Starshine: `1900` bytes versus Binaryen `1930` (`1896` versus `1926` instruction bytes plus `4` local-declaration bytes). Starshine declares `133` body i32 locals versus Binaryen `163`, so this is both local-count reducing and encoded-body-size reducing. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `664` reports `structured-local-writes`, so this remains representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count and encoded-body-size win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b90]` repeated one-shot temp-local classification at `abs=665`

`[SSANM-009b90]` follows the current self-artifact pair to `defined=638 abs=665`. Targeted `--print-func 665` extraction under `.tmp/ssanm009b88-next665` shows identical canonical `body_raw` token streams once local indexes are masked, with `190` local operations on both sides (`130` `local.get`, `31` `local.set`, and `29` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 16 one-use dead `local.tee` targets. Starshine reuses locals `15`, `47`, `17`, `18`, `50`, `20`, `21`, `54`, `53`, `23`, `24`, `57`, `28`, `38`, `35`, and `41`, while Binaryen allocates fresh one-use locals `63..78`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `638` encodes to the same `814` byte code body in both artifacts (`811` instruction bytes plus `3` local-declaration bytes). Starshine declares `58` body i32 locals versus Binaryen `74`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `665` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b91]` repeated one-shot temp-local classification at `abs=666`

`[SSANM-009b91]` follows the current self-artifact pair to `defined=639 abs=666`. Targeted `--print-func 666` extraction under `.tmp/ssanm009b88-next666` shows identical canonical `body_raw` token streams once local indexes are masked, with `78` local operations on both sides (`54` `local.get`, `5` `local.set`, and `19` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are three one-use dead `local.tee` targets. Starshine reuses locals `11`, `5`, and `6`, while Binaryen allocates fresh one-use locals `27..29`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `639` encodes to the same `365` byte code body in both artifacts (`362` instruction bytes plus `3` local-declaration bytes). Starshine declares `24` body i32 locals versus Binaryen `27`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `666` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## `[SSANM-009b92]` local-slot permutation classification at `abs=667`

`[SSANM-009b92]` follows the current self-artifact pair to `defined=640 abs=667`. Targeted `--print-func 667` extraction under `.tmp/ssanm009b88-next667` shows identical canonical `body_raw` token streams once local indexes are masked, with `77` local operations on both sides (`47` `local.get`, `18` `local.set`, and `12` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The local-token differences are a same-typed permutation among five one-use `local.tee` targets plus three set/get pairs over body i32 locals `29..36`. Local-use analysis shows every differing local is same-typed and either one-use or paired on one set/get slot.

Measured deltas: defined function `640` encodes to the same `320` byte code body in both artifacts (`317` instruction bytes plus `3` local-declaration bytes), and both declare `35` body i32 locals. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `667` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe neutral local-slot drift, not an implementation gap.

## `[SSANM-009b93]` repeated one-shot temp-local classification at `abs=668`

`[SSANM-009b93]` follows the current self-artifact pair to `defined=641 abs=668`. Targeted `--print-func 668` extraction under `.tmp/ssanm009b88-next668` shows identical canonical `body_raw` token streams once local indexes are masked, with `135` local operations on both sides (`82` `local.get`, `20` `local.set`, and `33` `local.tee`). No call, load/store memarg, branch/table opcode, label target, constant, result type, or structured-control token differs.

The only local-token differences are 10 one-use dead `local.tee` targets. Starshine reuses locals `11`, `12`, `20`, `47`, `8`, `19`, `31`, `16`, `17`, and `18`, while Binaryen allocates fresh one-use locals `53..62`. Local-use analysis shows every differing local appears exactly once as a same-typed `local.tee` target on its side.

Measured deltas: defined function `641` encodes to the same `622` byte code body in both artifacts (`619` instruction bytes plus `3` local-declaration bytes). Starshine declares `52` body i32 locals versus Binaryen `62`, so this is local-count reducing and function-body byte-size neutral. Both full artifacts validate with `wasm-tools validate --features all`. The Starshine trace for abs `668` reports `call-heavy-memory-structured-noop`, so this remains boundary/no-op representation classification rather than a new parity gap. Agent classification: semantic-safe Starshine local-count win / no-regression representation difference, not an implementation gap.

## Starshine test map

| Local test surface | What it proves |
| --- | --- |
| `src/passes/ssa_nomerge_test.mbt:235` | `[SSANM-002a]` planner fixtures cover already-SSA straight-line locals, overwritten freshenable writes, parameter-entry and body-default reads, one-arm branch merges, loop-carried merges, no-read dead `local.set`, and dead `local.tee`. `[SSANM-002b]` adjacent test-only shadow helpers summarize planner freshen/retarget/default/keep counts and current output body-local/local-get shape for reduced fixtures, without changing pass mutation. `[SSANM-005c1]` adds a mixed-region planner summary fixture proving one original local can have freshened writes before/after a canonical merge region. `[SSANM-005a]` public-pipeline fixtures prove missing-else body-local/default and parameter-entry merges keep canonical slots without fresh merge locals or predecessor copies. `[SSANM-005b1]` public-pipeline fixtures prove simple both-arm and block/`br_if` multi-source merge gets keep the original body-local slot and trace the LocalGraph canonical-only merge path. `[SSANM-005b2]` public-pipeline coverage proves a simple void-loop `br_if 0` backedge merge stays canonical and traces `structured-loop-backedge-merge-localgraph-plan`; `[SSANM-006b2c1]` / `[SSANM-006b2c2]` add the decorated-loop variant where branch-free block decoration before the backedge still stays canonical and avoids lifted HOT fallback; `[SSANM-006b2c3a]` adds branch/table decorated-loop boundary locks that return `structured-loop-backedge-boundary-noop`, reject ordinary planned LocalGraph reasons, and avoid lifted HOT mutation. `[SSANM-005b3]` fail-closed public-pipeline fixtures prove plain `br` and `br_table` multi-source merge regions preserve their branch opcodes but do not claim the canonical-only or mixed LocalGraph path yet. `[SSANM-006a1]` adds fail-closed public-pipeline fixtures for value-carrying `br` and `br_table` operands, preserving their branch/table opcodes and keeping them off the canonical-only/mixed LocalGraph reasons. `[SSANM-005c2]` public-pipeline coverage proves a narrow mixed normal `if`/`local.set` region traces `structured-mixed-localgraph-plan`, freshens only the planned non-merge writes, and introduces no predecessor-copy merge local. `[SSANM-005c3a]` adds public-pipeline coverage proving the same mixed path retargets small `local.tee` freshenable writes while preserving tee stack results and canonical merge-feeding sets. `[SSANM-006a3b]` through `[SSANM-006a3d]` add fail-closed public-pipeline coverage for ordinary plain branches, ordinary `br_table`, nested outer-target `br_if`, and nested loop-exit `br_if` shapes that validate and preserve the branch/table opcode without claiming ordinary planned LocalGraph reasons. `[SSANM-007a2a]` adds throwing `try_table` catch/catch-all fail-closed locks that preserve local writes and `throw` while avoiding ordinary planned structured LocalGraph reasons and lifted HOT mutation. `[SSANM-007a2b]` locks direct HOT `throw_ref`, public legacy catch/rethrow, and direct HOT delegate terminators as no-mutation boundaries. `[SSANM-007a3]` strengthens no-throw `try_table` ordinary local-write and scalar proxy fixtures, and adds the call-bearing `try_table` fail-closed contrast. `[SSANM-007b2]` adds trace/output locks for scalar/reference typed loop-param proxy helpers, no-copy typed-loop no-mutation boundaries, multi-param/single-result store-model helpers, typed-loop `br_table` helpers, and nested loop-target gates. `[SSANM-007b3a]` / `[SSANM-007b3b]` add shared trace/validation locks for value-carrying `br`, `br_if`, direct `br_table`, and mixed-target `br_table` operands, preserving branch/table opcodes while rejecting ordinary planned structured LocalGraph reasons. `[SSANM-007b3c]` adds the same trace/validation rejection surface for representative no-copy, copy-needing/prefix, non-null raw-path, and local-tee tested-producer `br_on_null` / `br_on_non_null` exits. `[SSANM-007b3d]` adds shared trace/validation locks for representative no-copy, divergent-alias, multi-result, multi-param, no-copy loop-target, and copy-needing loop-target `br_on_cast` / `br_on_cast_fail` exits. |
| `src/passes/ssa_nomerge_test.mbt:48` | Straight-line local traffic can stay canonical; `[SSANM-003a]` public-pipeline trace/output fixtures prove the raw `local.set` subset consumes the LocalGraph plan for live parameter overwrites and overwritten body-local writes; `[SSANM-003b]` adds LocalGraph-planned `local.tee` freshening, stack-result preservation, final-get retargeting, and folded effectful tee operand coverage; `[SSANM-006b2b]` adds trace-lock coverage proving straight-line `local.set` / `local.tee`, plain no-write, no-write default-read, and no-write unreachable-debris families exit through named raw/no-write reasons rather than lifted HOT fallback. `[SSANM-009b1]` adds the debug-WASI-derived stack-carried `local.tee` regression where a void call sits before the tee and a later get must read the fresh tee local instead of the body-local default. `[SSANM-009b2]` adds the debug-WASI-derived structured branch/value-carrier regression that rejects outputs reading appended fresh locals with no writes. `[SSANM-009b3]` adds the debug-WASI-derived structured branch-carrier regression that rejects outputs dropping all writes to a canonical local while later plain-branch exits still read that local. `[SSANM-009b4]` adds the debug-WASI-derived large loop-carried plain-branch boundary fixture that rejects the legacy structured helper's branch/else copy materialization until a Binaryen-shaped LocalGraph rewrite exists; `[SSANM-009b5]` adds the medium scanner variant from `defined=538 abs=565` and lowers the fail-closed threshold to source-lowered scanner-sized functions; `[SSANM-009b6]` adds the typed result-loop plain-`br` carrier boundary from `defined=651 abs=678` and keeps non-plain typed-control branches on the existing helper paths; `[SSANM-009b7]` adds the typed loop-param local.set/plain-`br` carrier boundary from `defined=987 abs=1014` while preserving local.tee, br_if, br_table, nested, try_table, and reference/cast typed-loop helper owners; `[SSANM-009b8]` adds the branch result-carrier fixture from `defined=1163 abs=1190`, proving written continuation locals are not default-materialized into `i32.const 0` constructor operands; `[SSANM-009b9]` adds the nested typed loop-param plain-`br` boundary from `defined=1286 abs=1313`, keeping a source-lowered single-param/no-result typed-loop carrier fail-closed even when nested inside an outer void loop; `[SSANM-009b10]` adds the `tlsf/addMemory` parameter-tee branch-carrier regression from `defined=3 abs=30`, preserving a parameter `local.tee` that feeds the not-taken path while still freshening body-local allocator scratch; `[SSANM-009b11]` adds the `parse__olevel__text` loop-header alias-copy regression from `defined=154 abs=181`, preserving locals written before a loop when loop headers read them before any loop-local write; `[SSANM-009b12]` adds the `dae__try__unwrap__func313__suffix__staging__block__once` branch-exit store-suffix regression from `defined=300 abs=327`, preserving stack-to-local suffix carriers before plain branches to outer merges. |
| `src/passes/ssa_nomerge_test.mbt:68` | Latest straight-line alias stays live. |
| `src/passes/ssa_nomerge_test.mbt:99` and `:119` | Dead param set/tee rewrites spill through fresh locals. |
| `src/passes/ssa_nomerge_test.mbt:140` | Structured param writes can remain canonical. |
| Earlier branch-join and loop-carried fixtures | Historical raw/HOT predecessor-copy-shaped expectations are superseded for ordinary no-merge families by the `[SSANM-005*]` and `[SSANM-006b2*]` LocalGraph trace locks above; any remaining copy-shaped branch/table/typed/EH output must be classified through the boundary-owner rows instead of treated as normal no-merge behavior. |
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
- Local line numbers are approximate anchors after the 2026-06-14 SSANM refresh; prefer the named function/test identifiers when code motion shifts exact line numbers.

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
