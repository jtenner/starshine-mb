---
kind: decision
status: supported
last_reviewed: 2026-10-08
sources:
  - ../../../src/ir/local_graph_read_flow_wbtest.mbt
  - ../binaryen/passes/ssa-nomerge/index.md
  - https://doi.org/10.1145/115372.115320
  - ../../../src/ir/ssa_policy.mbt
  - ../../../src/ir/ssa_local.mbt
  - ../../../src/ir/ssa_destroy.mbt
  - ../../../src/ir/local_graph.mbt
  - ../../../src/ir/analysis_cache.mbt
  - ../../../src/ir/architecture.mbt
  - ../../../src/passes/pass_common.mbt
  - ../../../src/ir/ssa_policy_test.mbt
  - ../../../src/ir/ssa_local_test.mbt
  - ../../../src/ir/ssa_destroy_test.mbt
  - ../../../src/ir/local_graph_test.mbt
  - ../../../src/ir/analysis_cache_test.mbt
related:
  - ./architecture-rules.md
  - ./cfg-contract.md
  - ./test-matrix.md
  - ./pass-porting-checklist.md
  - ../../../src/ir/use_def.mbt
  - ../../../src/ir/liveness.mbt
  - ../../../src/ir/dominators.mbt
  - ../../../src/ir/hot_mutate.mbt
  - ../../../src/ir/analysis_cache.mbt
  - ../../../src/ir/architecture.mbt
  - ../../../src/passes/pass_common.mbt
---

# IR2 Local SSA Policy

## September 27 follow-up allocation campaign renewal

The [final follow-up campaign](../tooling/tracing-playbook.md#september-27-2026-follow-up-pass-allocation-campaign)
supersedes pending-renewal notes for its allocation changes below. The frozen
source passes 12,583 default tests. Its 220,000 comparisons across 22 affected
lanes report no validation, generator, property-counter, command or observed
Starshine/original semantic failures. The report retains exact tool identities,
all artifact timings, active fixtures, residual/size replays and runtime limits.
Per-change measurements are historical isolated pairs, not additive gains.
Remaining timing, output-quality and runtime-coverage gaps stay open; rejected
prototypes remain rejected.

## Overview

Starshine's local SSA is **not** a second optimizer IR. It is a locals-only analysis overlay built over a normal [`HotFunc`](../../../src/ir/hot_core.mbt) body, keyed to that function's revision. The body remains ordinary HOT IR before and after SSA-assisted work: local reads are still `LocalGet`, writes are still `LocalSet` / `LocalTee`, and phis are metadata that never become persistent HOT nodes.

Use this page when adding or reviewing an SSA-assisted pass, debugging local-def/use facts, or deciding whether a new optimization really needs the current local overlay versus a different IR2 analysis. The classic external lineage is Cytron-style SSA placement, but Starshine intentionally narrows it: [`ssa_policy.mbt`](../../../src/ir/ssa_policy.mbt) uses dominance frontiers plus liveness filtering for locals, [`ssa_local.mbt`](../../../src/ir/ssa_local.mbt) performs dominator-tree renaming over local ops, and [`ssa_destroy.mbt`](../../../src/ir/ssa_destroy.mbt) lowers overlay phis back to predecessor copies so the owned body never stops being HOT IR. [`local_graph.mbt`](../../../src/ir/local_graph.mbt) is a separate Binaryen-facing reaching-source graph: it records entry/default sources and explicit local writes that can reach each `LocalGet`, plus the gets influenced by each set/tee, without rewriting the function. The cache and pass-use contract is grounded in [`analysis_cache.mbt`](../../../src/ir/analysis_cache.mbt), [`pass_common.mbt`](../../../src/passes/pass_common.mbt), and their focused tests. The classic SSA lineage is Cytron et al.'s [1991 paper](https://doi.org/10.1145/115372.115320), while the first local policy note is archived at research note 0061.

## Data Shape

| Concept | Starshine shape | Meaning |
| --- | --- | --- |
| SSA value | `SsaValueId` | Overlay-local id for one local definition. It is not a `NodeId`. |
| Phi | `PhiId` + `HotSsaPhi(block, local_id)` | Block-entry overlay fact for one local. It has a result SSA value, but the phi itself is not a HOT node. |
| Definition origin | `HotSsaValueOrigin` | One of entry-param, entry-default-init, local-set, local-tee, or phi. |
| Use origin | `HotSsaUseOrigin` | Either a `LocalGet` use or a phi input from a predecessor block. |
| Entry definitions | `entry_defs[local_id]` | Exactly one synthetic starting definition per parameter/body local. |
| Node maps | `local_get_values` / `local_write_defs` | Node-indexed lookup from local HOT nodes to overlay value ids. |
| Use lists | `value_uses[value_id]` | Consumers used by destruction and dead-def cleanup. |
| LocalGraph source | `HotLocalGraphSource` | Binaryen-facing reaching-source fact: either `EntrySource(local_id)` or `SetSource(node_id)`. Entry sources carry first-class param-vs-body-default classification through `local_graph_source_is_param_entry(...)`, `local_graph_source_is_default_entry(...)`, `local_graph_entry_source_is_param(...)`, and `local_graph_entry_source_is_default(...)`. |
| LocalGraph get class | `local_graph_get_is_single_source(...)` / `local_graph_get_is_merge(...)` | Whether a `LocalGet` has exactly one reaching source or multiple reaching sources, matching the first analysis-only step toward Binaryen `SSAify.cpp` no-merge decisions. |
| LocalGraph write class | `local_graph_node_is_write(...)`, `local_graph_write_is_set(...)`, `local_graph_write_is_tee(...)`, `local_graph_write_local_id(...)` | Per-node explicit-write facts for `LocalSet` and `LocalTee`, including the written local id and the opcode family. Non-write nodes are excluded from write-specific queries. |
| LocalGraph influence | `local_graph_influenced_gets_for_set(...)` / `local_graph_influenced_gets_for_write(...)` | The `LocalGet` nodes whose reaching-source set includes a specific `LocalSet` / `LocalTee`, reported in LocalGraph's normal-flow transfer order for later Binaryen-style per-write decisions. |
| LocalGraph already-SSA local | `local_graph_local_is_already_ssa(...)` | Binaryen-style local-index classifier used before per-write freshening: a local is already effectively SSA when its reachable gets collectively see exactly one source, and no other explicit write to that local exists. No-read locals and locals with dead unrelated writes fail closed instead of being treated as canonical. |
| LocalGraph no-merge write eligibility | `local_graph_write_has_merge_influences(...)` / `local_graph_write_is_no_merge_freshenable(...)` | Analysis-only per-write policy fact for Binaryen `SSAify.cpp` no-merge mode. A write has merge influences if any influenced get is multi-source. A write is freshenable only when its original local is not already SSA and none of its influenced gets is a merge. |
| LocalGraph defaultability | `local_graph_entry_source_has_legal_default(...)` / `local_graph_source_is_defaultable_entry(...)` | Analysis-only body-default-entry fact for future default replacement decisions. Body-local entry sources are defaultable only when the local `ValType` has a legal WebAssembly default; parameter entries and explicit set/tee sources are not default-replacement candidates. |

Two entry-origin rules are especially important for beginners:

- Function parameters begin as `EntryParamDef(local_id)` because the caller supplied their values.
- Body locals begin as `EntryDefaultInitDef(local_id)` because WebAssembly locals are initialized to their type default before the body runs.

That means every `LocalGet` can resolve to a reaching definition even if the function never wrote that local explicitly.

## Build Flow

The implemented build pipeline is:

1. Build or reuse normal-flow CFG, dominators, use-def, and liveness overlays: [`cfg.mbt`](../../../src/ir/cfg.mbt), [`dominators.mbt`](../../../src/ir/dominators.mbt), [`use_def.mbt`](../../../src/ir/use_def.mbt), and [`liveness.mbt`](../../../src/ir/liveness.mbt).
2. Allocate one entry value per local in [`ssa_build_local(...)`](../../../src/ir/ssa_local.mbt).
3. For each local, call the pruned placement helper from [`ssa_policy.mbt`](../../../src/ir/ssa_policy.mbt): start from blocks with real writes, walk dominance frontiers, and keep only frontier blocks where the local is live-in.
4. Allocate overlay phis and phi result values for those block/local pairs.
5. Rename by walking the dominator tree, maintaining one stack of current SSA values per local.
6. Visit ordinary HOT nodes child-first for non-region operands; `LocalGet` consumes the current value, while `LocalSet` and `LocalTee` create new values and push them on the local stack. A parameter-free, branch-free single-result `Block` used as an expression operand is inline-visited in surrounding operand order, including its body-local writes. Parameterized blocks and nested-control bodies remain fail-closed until their stack inputs and path joins are modeled explicitly.
7. Record phi inputs on normal successor edges, explicitly skipping `ExceptionalEdge` successors.
8. Sort phi inputs into predecessor-edge order and abort if a phi's input count or positions no longer align with the normal-flow incoming edges. Repeated predecessor blocks retain separate positions; every input consumes one position, with independent cursors for each phi. The two-phi `[A, B, A]` regression in [`ssa_local_test.mbt`](../../../src/ir/ssa_local_test.mbt) checks ordering and reaching definitions without deduplicating CFG edges. This repairs edge multiplicity only; it does not close the independent SSA-no-merge branch-copy failures tracked in [`agent-todo.md`](../../../agent-todo.md).

Concrete locked examples live in [`ssa_local_test.mbt`](../../../src/ir/ssa_local_test.mbt): diamond joins create one join phi, loop headers create loop-carried phis, uninitialized locals read their default-init entry definitions, `LocalTee` creates a definition for later reads, unreachable branch-carry ladders do not let unreachable predecessor blocks corrupt phi-input alignment, and a straight-line result block used as an arithmetic operand carries its nested `local.set` to the following sibling `local.get`. The use-def overlay follows the same eligible operand-block traversal so phi placement and SSA renaming consume one execution-order model.

## LocalGraph Companion Analysis

[`local_graph_build(...)`](../../../src/ir/local_graph.mbt) is analysis-only. It uses the existing normal-flow CFG and child-before-parent HOT expression order to compute may-reaching local sources:

- every local begins with an entry source;
- entry sources are classified as parameter entries or body-local default entries so future no-merge/full-SSA decisions can distinguish caller-provided values from implicit WebAssembly defaults;
- `LocalSet` and `LocalTee` replace the current source set for their local on that path;
- each explicit write records whether it came from `local.set` or `local.tee`, the written local id, and its influenced get list;
- joins union source sets from normal predecessors;
- `LocalGet` queries expose single-source versus merge-source classification without mutating the function;
- `local_graph_local_is_already_ssa(...)` exposes the Binaryen `computeSSAIndexes()`-style local classifier: param-entry/default-only reads, straight-line explicit writes, and tee-defined locals can be canonical, while branch/loop merges, no-read locals, and locals with dead unrelated writes fail closed;
- `local_graph_write_has_merge_influences(...)` and `local_graph_write_is_no_merge_freshenable(...)` expose the next Binaryen `createNewIndexes(...)` no-merge policy fact per explicit write: already-SSA locals stay canonical, while writes to non-SSA locals are freshenable only when all influenced gets stay single-source;
- `local_graph_entry_source_has_legal_default(...)` and `local_graph_source_is_defaultable_entry(...)` keep body-local default entries separate from parameter entries and explicit set/tee sources, and require `@lib.has_default(...)` before treating a default entry as a future replacement candidate. LocalGraph operates on Starshine HOT `ValType` locals; Binaryen's internal tuple value category is not a separate Starshine local type, so current defaultability fixtures cover WebAssembly locals: numeric, SIMD, and nullable GC/reference types versus non-null reference boundaries;
- ordinary `local_graph_build(...)` skips exceptional edges for normal-flow consumers, while `local_graph_build_full_flow(...)` includes exceptional predecessors for the public full `ssa` pass;
- `local_graph_build_read_sources(...)` returns the narrower immutable
  `HotLocalReadSources` snapshot used by DAE2. Its checked count/scalar queries
  preserve full-flow source order, exceptional edges, sparse fallback and
  unknown zero-source rows, without computing unused writer/SSA metadata.
  It is a distinct API; full graph callers keep all existing fields. See the
  [snapshot fixtures](../../../src/ir/local_graph_read_flow_wbtest.mbt).
- unreachable or detached nodes are excluded by the normal HOT liveness checks used while building the graph;
- `local_graph_can_move_set_past_node(...)` ports the Binaryen `canMoveSet` test idea by reporting only influenced gets still reachable from a set when a candidate obstacle node blocks paths after that set.

This graph now serves both analysis and the complete public full-`ssa` plan. `ssa_full_build_merge_rewrite_plan(...)` consumes full-flow LocalGraph facts, orders fresh write locals before merge locals, records explicit/parameter/default inputs, and skips impossible nondefaultable defaults. The dispatcher applies that immutable plan to raw stack instructions and batch-validates changed definitions before commit. Locked LocalGraph examples live in [`local_graph_test.mbt`](../../../src/ir/local_graph_test.mbt): simple set/get influence with explicit write facts, get-before-set entry reads, param-vs-default entry classification, legal-default classification for scalar numeric, SIMD `v128`, nullable GC refs, and nondefaultable non-null refs while rejecting params and explicit set/tee sources, single-source/merge get classification, already-SSA local classification for straight-line, branch, loop, param, body-local, tee, no-read, and dead-write fixtures, per-write no-merge eligibility for split overwrite regions, merge-feeding writes, and default/param entry merges, overwrite kills, child-expression tee facts, diamond merge sources, loop-carried sources, and Binaryen `canMoveSet` obstacle families. Complete full-`ssa` planner and mutation examples live in [`../../../src/passes/ssa_test.mbt`](../../../src/passes/ssa_test.mbt), with profile coverage in [`../../../src/validate/gen_valid_ssa_full_wbtest.mbt`](../../../src/validate/gen_valid_ssa_full_wbtest.mbt).

## Default Ref Replacement And Type Repair

The current `ssa-nomerge` no-write raw path replaces reads of never-written body locals with explicit WebAssembly default instructions before the module is validated. For reference locals this uses [`run_hot_pipeline_raw_default_instr_for_local(...)`](../../../src/passes/pass_manager.mbt), which emits `ref.null` with the original nullable `RefType` payload, including exact concrete heap types. This is Starshine's local equivalent of the Binaryen `ReFinalize` need for this narrow replacement family: the raw instruction stream does not carry persistent parent-expression type annotations, so validation/typecheck recomputes the parent stack types after the replacement rather than requiring a separate HOT refinalization pass.

Focused guards in [`ssa_nomerge_test.mbt`](../../../src/passes/ssa_nomerge_test.mbt) cover nullable exact child refs under a parent block result, exact nullable struct refs flowing through `ref.as_non_null -> struct.get`, and nullable array refs flowing into `array.get`. These tests prove the output contains the expected `ref.null` payload, removes the original body-local `local.get`, and validates. The proof is limited to the no-local-write default-replacement raw path; future LocalGraph-driven mutation that replaces defaults in functions with explicit writes must either reuse this typed default materialization plus final validation or add an explicit repair/refinalization step with its own tests.

## Cache And Pass-Use Lifecycle

Local SSA participates in the same revision-keyed overlay lifecycle as CFG, dominance, liveness, and effects. [`HotAnalysisCache`](../../../src/ir/analysis_cache.mbt) stores `ssa : HotCacheEntry[HotLocalSsa]?`; [`cache_get_or_build_ssa(...)`](../../../src/ir/analysis_cache.mbt) reuses that slot only when `built_at_revision == hot_revision_current(func)`. A cache miss rebuilds dependencies through CFG, dominators, use-def, and liveness before calling `ssa_build_local(...)`.

Passes should normally request SSA through their descriptor and the pass helper layer:

```moonbit
HotPassDescriptor::new(
  "example-pass",
  requires=[HotAnalysis::ssa()],
)
```

In the public optimizer path, [`pass_require_ssa(...)`](../../../src/passes/pass_common.mbt) routes that request through the shared cache, records `analysis:ssa` timing/counters when the entry was stale, and returns the overlay for the current function revision. After a pass mutates a `HotFunc`, [`pass_mark_mutated(...)`](../../../src/passes/pass_common.mbt) calls `cache_invalidate_all(...)`; any old `SsaValueId`, `PhiId`, phi-input order, `BlockId`, liveness bit, or derived predecessor-copy plan must be reacquired instead of reused.

Descriptor wording matters: `requires=[HotAnalysis::ssa()]` means “the pass may need the locals-only SSA overlay built before it runs.” It does **not** mean the pass owns persistent SSA state, rewrites through phi nodes, or must call `ssa_destroy_into_hot(...)`. Current active pass declarations often include SSA together with CFG/effects/loop info for common HOT analysis setup, while concrete direct users such as [`ssa_nomerge.mbt`](../../../src/passes/ssa_nomerge.mbt) and [`precompute.mbt`](../../../src/passes/precompute.mbt) call `pass_require_ssa(...)` for pass-specific decisions. Pass dossiers should say which of those roles applies rather than letting descriptor presence imply deeper semantics.

The cache behavior is locked in [`analysis_cache_test.mbt`](../../../src/ir/analysis_cache_test.mbt): unchanged revisions reuse cached overlays, root mutation rebuilds stale SSA plus its dependencies, and `cache_invalidate_all(...)` drops the SSA slot. [`hot_verify_ssa(...)`](../../../src/ir/hot_verify.mbt) now accepts concrete CFG/SSA overlays, checks the SSA revision against `HotFunc.revision`, rebuilds dominators from the supplied CFG for dominance-sensitive checks, and validates phi/input/local-get/local-write/value-use shape. It is verifier infrastructure; `ssa_policy` / `ssa_local` / `ssa_destroy` / `analysis_cache` tests still carry the detailed builder/destructor behavior contract.

## Out-Of-SSA Flow

Destruction is a writeback step, not a persistent mode switch. [`ssa_destroy_into_hot(...)`](../../../src/ir/ssa_destroy.mbt) currently uses `HotSsaDestroyPolicy::ReusePhiLocals`:

1. Map each SSA value to a concrete local: entry and phi values reuse their original local, while real local-set/local-tee definitions receive fresh body locals.
2. Rewrite `LocalGet`, `LocalSet`, and `LocalTee` node operands to those concrete locals.
3. For each phi input, insert predecessor copies that move the incoming value's concrete local into the phi target local.
4. Insert copies before block terminators and preserve insertion order when multiple predecessor-copy groups land in the same region.
5. Schedule parallel copies safely. A cycle like `0 -> 1` and `1 -> 0` allocates a temporary local first.
6. Remove dead local definitions when it is safe to preserve the value expression as a `drop`; retain the local write when a later concrete read or unreachable/lowering rule still needs it.
7. Trim unused trailing temporary locals introduced only for now-dead definitions.

The destruction tests in [`ssa_destroy_test.mbt`](../../../src/ir/ssa_destroy_test.mbt) lock predecessor copies for diamonds, loop preheaders/backedges, synthetic block continuations, copy-cycle temporaries, root-region copy order, duplicate dead-node tolerance, later-read preservation, dead-set trimming, Binaryen-compatible dead-tee behavior, and reduced `br_table` / unreachable-carrier regressions.

## Concrete Example: Diamond Merge

Before SSA, a local may be set on only one branch and read after the `if`:

```wasm
(local i32)
i32.const 1
if
  i32.const 7
  local.set 0
end
local.get 0
drop
```

The overlay sees two incoming values at the post-`if` join:

- the `then` predecessor contributes the value defined by `local.set 0`;
- the other predecessor contributes `EntryDefaultInitDef(0)`.

So `ssa_build_local` creates one join phi for local `0`, maps the later `local.get 0` to the phi value, and records both predecessor inputs. When `ssa_destroy_into_hot` writes back, the `then` branch's fresh local is copied into local `0` before leaving the predecessor, while the default-init path can continue to use local `0` directly. The final body remains ordinary HOT IR with concrete local operations and no phi nodes.

## Correctness Constraints

- **Revision-keyed:** `HotLocalSsa.revision` records `hot_revision_current(func)` at build time. Treat any mutation through [`hot_mutate.mbt`](../../../src/ir/hot_mutate.mbt), [`pass_mark_mutated(...)`](../../../src/passes/pass_common.mbt), or other revision-bumping APIs as invalidating the overlay and its dependent ids.
- **Normal-flow only:** SSA v1 skips exceptional successors while recording phi inputs. Do not use it to prove facts across `try` / `try_table` exceptional edges. The 2026-06-09 `ssa-nomerge` audit found a true corruption when this exclusion was ignored: a `try_table` body `local.set` followed by `throw` to a catch target was dropped while a later read observed the default value. Optimizer passes must fail closed on exceptional-flow functions unless they implement explicit exceptional-edge SSA semantics.
- **Local values only:** The overlay models local variable definitions and uses. It does not model stack SSA, globals, memory, tables, tags, heap objects, data/elem segments, or arbitrary expression values.
- **Structured operand boundary:** A single-result block may contribute local writes to the surrounding operand sequence only when `ssa_simple_value_block_operand_allowed(...)` proves one result, no block parameters, and a branch-free straight-line subtree. Do not generalize this to parameterized, multivalue, loop, conditional, EH, or branch-containing regions without corresponding CFG/use-def/rename tests.
- **No persistent phis:** A pass may inspect `PhiId`s and phi input values, but it must not add a HOT `Phi` opcode or store SSA as an owned body form.
- **Liveness-pruned placement:** A dominance frontier alone is insufficient. `ssa_phi_placement_blocks(...)` keeps a candidate only if the local is live-in to that block.
- **Predecessor-copy writeback:** Any pass that mutates according to SSA values must either call the existing destruction/writeback helpers or maintain the same concrete-local and predecessor-copy invariants.
- **Validate after mutation:** After SSA-assisted mutation and destruction, run HOT verification and normal module validation/signoff through [`test-matrix.md`](./test-matrix.md) and [`pass-porting-checklist.md`](./pass-porting-checklist.md).

## Explicit Exclusions

SSA v1 deliberately excludes:

- exceptional-edge SSA;
- persistent HOT phi nodes;
- an IR-owned SSA body representation;
- non-local values, including globals, memory, tables, heap/GC objects, and generalized stack values;
- LocalGraph-driven mutation; `local_graph.mbt` currently exposes analysis facts only, not a replacement for `ssa-nomerge` rewriting;
- multi-value block-parameter modeling beyond the ordinary HOT/CFG/local policy already documented in [`cfg-contract.md`](./cfg-contract.md).

If future work needs any of those, update the IR2 architecture contract first, add tests before implementation, and record how the new overlay invalidates or coexists with this locals-only policy.

## Maintenance Checklist

- Start from the current code and tests, not the old March policy note alone.
- Keep new queries on `HotLocalSsa` overlay types; do not add persistent SSA nodes to `HotFunc`.
- Build CFG/dominance/use-def/liveness from the same function revision as the SSA overlay, preferably through `cache_get_or_build_ssa(...)` or `pass_require_ssa(...)` instead of parallel private caches.
- Reacquire SSA after any mutation that bumps the HOT revision; never keep `SsaValueId` or `PhiId` handles across `pass_mark_mutated(...)`.
- Add focused tests in `src/ir/ssa_policy_test.mbt`, `src/ir/ssa_local_test.mbt`, `src/ir/ssa_destroy_test.mbt`, or `src/ir/analysis_cache_test.mbt` for new placement, rename, destruction, or cache-lifecycle behavior.
- If an optimizer pass uses SSA, document the pass-local assumptions in that pass dossier and include ordinary pass validation plus Binaryen oracle comparison when the pass has an upstream equivalent.

## Sources

- 2026-06-09 exceptional-edge audit: [research note 0722](../binaryen/passes/ssa-nomerge/index.md)
- Cache/pass-use evidence: [`../../../src/ir/analysis_cache.mbt`](../../../src/ir/analysis_cache.mbt), [`../../../src/passes/pass_common.mbt`](../../../src/passes/pass_common.mbt), and [`../../../src/ir/analysis_cache_test.mbt`](../../../src/ir/analysis_cache_test.mbt)
- SSA lineage: Cytron et al., [“Efficiently Computing Static Single Assignment Form and the Control Dependence Graph”](https://doi.org/10.1145/115372.115320)
- Archived original policy note: research note 0061
- Policy/query layer: [`../../../src/ir/ssa_policy.mbt`](../../../src/ir/ssa_policy.mbt)
- Builder: [`../../../src/ir/ssa_local.mbt`](../../../src/ir/ssa_local.mbt)
- Destruction/writeback: [`../../../src/ir/ssa_destroy.mbt`](../../../src/ir/ssa_destroy.mbt)
- Cache/pass helper layer: [`../../../src/ir/analysis_cache.mbt`](../../../src/ir/analysis_cache.mbt), [`../../../src/ir/architecture.mbt`](../../../src/ir/architecture.mbt), [`../../../src/passes/pass_common.mbt`](../../../src/passes/pass_common.mbt)
- Tests: [`../../../src/ir/ssa_policy_test.mbt`](../../../src/ir/ssa_policy_test.mbt), [`../../../src/ir/ssa_local_test.mbt`](../../../src/ir/ssa_local_test.mbt), [`../../../src/ir/ssa_destroy_test.mbt`](../../../src/ir/ssa_destroy_test.mbt), [`../../../src/ir/local_graph_test.mbt`](../../../src/ir/local_graph_test.mbt), [`../../../src/ir/analysis_cache_test.mbt`](../../../src/ir/analysis_cache_test.mbt)
- Supporting overlays: [`../../../src/ir/use_def.mbt`](../../../src/ir/use_def.mbt), [`../../../src/ir/liveness.mbt`](../../../src/ir/liveness.mbt), [`../../../src/ir/dominators.mbt`](../../../src/ir/dominators.mbt), [`../../../src/ir/cfg.mbt`](../../../src/ir/cfg.mbt)

## Forwarding an existing operand through an identity wrapper

Normal HOT node replacement keeps the later of the old and replacement source
positions. Identity-wrapper removal has a different contract: the operand was
already evaluated, possibly before intervening roots. `hot_replace_node` and
`pass_replace_node` accept `preserve_value_order=true` for this proven case.
The flag requires a nonnegative source order and retains it after replacement;
other replacements keep the existing rule. Callers must prove the wrapper has
no remaining effect or trap before selecting this mode.

OptimizeCasts uses this mode only when forwarding a child through a proven
redundant refinement. The Dew component-order regression starts with
`call first; call second; local.set; ref.cast`. Both calls trap differently.
Removing the static cast previously gave the first call the later cast's
position, so the second call ran first. Native ordered-instruction assertions
and Node/Wago execution now retain the first unreachable trap while still
removing three redundant casts.

## Raw source accesses and pending stack locals

HOT lift records each raw local read/write in source order, including an absent
node marker for unreachable stack-polymorphic instructions. Synthetic captures
have no raw entry. SSANoMerge maps its HOT decisions back through these entries;
it must not align raw instruction cursors with HOT creation order. The mapping
is valid only while the lifted function's revision is unchanged.

Pending stack expressions carry local dependencies. Before a later access can
conflict, lift captures the complete stack prefix through the last conflicting
value, in evaluation order. Capturing only the conflicting read can move an
older throwing call past the write and change a handler's local value. Complete
tuple groups are captured together; producers already anchored by an earlier
root are not evaluated again. Reference storage is nullable, with a non-null
restoration on reads when required by the result type. Raw source access maps
exclude all these synthetic accesses.

The shared prefix rule applies with either value of `capture_stack_locals`;
that option additionally captures pending effects at general roots. The
[throwing-call regression](../../../src/ir/hot_lower_local_lifetime_test.mbt)
checks both modes and original read/write ordinals. GenValid's constraint effects
family includes a throwing call before a handler-visible conflicting local write,
with an unused callee parameter for the DAE2 comparison lane.

The positive scalar Flatten regression returns 7 (the old output returned 0).
The aggregate SimplifyLocals regression keeps the earlier value 4. Raw SSA tests
cover dropped unreachable writes without shifting subsequent access decisions.
The carried Fibonacci sum, carried load/tee, and OptimizeInstructions tee
comparison tests execute bounded local updates, allowing temporary captures
while checking the original results. The
full IR suite passes 376 tests; the focused LocalSubtyping, MergeLocals, and
Flatten suite passes 101 tests. Broad size/performance and generated-pass
signoff remains open. All original failed fixture/orders remain in the Dewdrop
replay log.

Pending values can also carry calls, heap/global/memory operations, and traps.
Lowering emits a preceding pending value before a later conflicting root. This
uses source execution order, including the original order retained by a set
split from a tee; allocation IDs do not establish execution order. The effect
mask for every node is built once per lowered function and reused for these
queries. Regressions in `src/ir/hot_lower_pending_effect_test.mbt` cover a call
before a global write and a memory-backed tee write before a later read. The
same call shape also runs through the public Flatten dispatcher.

A new wrapper's source position also must not outrank effects in its operands.
The lowerer caches the earliest external effect under each root. A pending
value can precede that root only if it precedes the first effect that root will
actually emit. Replacing two drop statements after creating both calls used to
reverse their call order; the new regression requires calls 0 then 1. The full
IR suite passes 377 tests. The 1,540-test OptimizeInstructions/SimplifyLocals run
now passes 1,530; ten remaining capture-layout/reference/fact checks stay open.
The bulk-memory call-order regressions pass again.

## Control region exits

HOT lifting and the validator use the same `tc_state_finish_block`,
`tc_state_finish_loop`, and `tc_state_finish_if` helpers. These helpers merge
recorded reachable branch targets as well as the last instruction's exit state.
A trailing `unreachable` does not erase an earlier branch to an outer label.
Loop backedges do not imply fallthrough. The helpers consume already checked
region states, so nested bodies are still visited once.

Losing those branch records marked the live tail of Dewdrop's array-copy loop
unreachable. A following result `if` with two other carried stack values then
lost all three consuming local stores, including the loaded array element. The
reduced test in `src/ir/hot_lift_reachable_exit_test.mbt` requires that result
store to remain attached to its conditional producer. The old tail-if lowering
test now uses valid Wasm: it drops the polymorphic conditional result and gives
the outer block a result on both exits. Runtime replay remains required in
addition to validation.
The repaired shared path passes 380 native IR tests (8.519 seconds) and 1,787
native validator tests (24.134 seconds). The saved array-carriers CoalesceLocals
prefix and map-iterator SimplifyLocals prefix pass validation and execution in
both Node and the locally tested Wago PR 606 runner. The fresh full replay and
release/generated-pass performance signoff are still open. The debug CLI build
took 31.373 seconds and is recorded as a build-performance bug.


## Reference locals after code motion

`hot_repair_nondefaultable_local_scopes` restores the Wasm storage contract after
an otherwise semantics-preserving transform. Its scan follows operand order,
keeps initialization within each control frame, and tracks loop entry operands
in the enclosing frame. A write log restores frame entry state without copying
the full local table for each nested region. Node visits are shared within a
frame, including tuple producers used by more than one root.

Only body reference locals with a read outside their initialization scope become
nullable. Every get and tee of an affected local retains its original non-null
result through `ref.as_non_null`; copied reads/writes keep the original source
order. Parameters and locals initialized in an enclosing scope retain their
types. CodeFolding invokes the repair once after a successful fixpoint, retaining
its common-tail optimization. The helper is a storage repair for valid-input
code motion, not a validator or a way to accept invalid source Wasm.

### Reusing carried values below later operands

A single-result value already emitted onto the Wasm stack must not be evaluated
again merely because another operand now covers it. `hot_lower_impl_emit_root`
keeps its top-of-stack fast path and reuses a buried effectful value through
typed scratch locals. Values above it retain their order. Pure values retain
cheap rematerialization. This preserves read snapshots, call counts, traps,
and allocation identity across later effects.

When a pass turns `local.set` plus `local.get` into a tee,
`hot_build_local_tee_from_set` preserves the write position. Replacing the read
must explicitly retain that order with `preserve_value_order=true`. The new
builder asserts that its source is a unary set. SimplifyLocals uses this pair.
The bounded lowerer regression in `src/ir/hot_lower_pending_effect_test.mbt`
requires the carried call to run once, before the later call; the array-pop
execution regression also checks the value and memory writes. See the
[SimplifyLocals ordering dossier](../binaryen/passes/simplify-locals/effect-ordering-and-barriers.md)
for measured validation and remaining gates.

Carried Fibonacci, call arguments and load addresses now have bounded behavior
assertions rather than exact scratch layouts. The focused stack-carried suite
passes 40/40 after remote integration. Full combined-source and native generated
signoff are pending; the earlier 99/100 lift/lower result is historical. Broad
capture size/performance measurements remain open.

Forward LocalGraph states now share immutable reaching-definition sets for
unchanged locals. Every write and join replaces its local's set, so a branch
cannot mutate its sibling or a predecessor's recorded facts. This targets the
compiler function whose former deep state copies drove DAE2 above 3 GiB. The
[dedicated compiler resource lane](../../../scripts/test/binaryen132-compiler-cost.ts)
records binary/input/output identities, CPU time and peak RSS against an explicit
budget; it is outside default tests. Native `7fb86dfa…` passes the 1 GiB check:
peak RSS falls from 3,188,972 to 683,456 KiB and wall time from 65.91 to 22.82
seconds with identical output (`645c4281…`). These concurrent exploratory runs
do not close the remaining pass-local performance gap.

Full-flow queries use symbolic per-block entry sources when reverse scanning
cannot linearize a nested conditional or shared expression. Block transfer keeps
only changed-local summaries; each demanded entry is resolved through complete
predecessor closure, including requested exception edges, before caching. This
avoids retaining a full function state at every block. The standard converged
forward solver remains an independent comparison implementation. Both source and
write-influence sets agree on four targeted fixtures and the dedicated 5,000-module
GenValid lane in `local_graph_sparse_wbtest.mbt`; that sweep is skipped by default.
Native `c447149a…` completes the same compiler DAE2 probe in 7.53 seconds /
451,280 KiB with the same output hash. The 304 adapted upstream module/world
cases and 24 independent lifetime comparisons pass. Pass-level campaigns and
isolated performance attribution remain pending.

## September 27, 2026: expanded CFG tuple bookkeeping

The forward LocalGraph solver now allocates per-producer tuple evaluation flags
only for recursive, unexpanded traversal. An expanded CFG already lists operands
at their execution positions and never reads these flags. Clearing an entire
function-sized array per CFG block added work proportional to nodes times blocks
on every solver iteration and the final source-recording traversal.

The bounded regression first allocated four unused slots in expanded mode; it
now allocates zero while asserting the exact reaching write and write-to-read
influence. Unexpanded mode retains all four slots. Existing shared-tuple,
branch/loop/handler and dispatcher tests remain green (36 focused tests).
The native 256-region full-graph benchmark improved from **1.94 s to 46.75 ms**;
the unexpanded control did not regress. No transfer, merge, fixed-point order,
exceptional-edge policy or source-recording rule changed.

A paired artifact check first exposed a 31.7% propagation slowdown between two
binaries differing only in inlining retention work. GDB samples in the slower
binary repeatedly landed in the unused array's byte-clearing loop. None of the
Precompute function sizes changed; code-layout sensitivity is an inference, not
a proven mechanism. Removing the unused work addresses the sampled hotspot
independently of that inference. Final artifact and generated evidence belongs
in the [campaign report](../tooling/tracing-playbook.md).

Sources: [implementation](../../../src/ir/local_graph.mbt),
[bounded transfer regression](../../../src/ir/local_graph_tuple_state_wbtest.mbt),
[native controls](../../../src/ir/local_graph_tuple_state_perf_wbtest.mbt),
[existing tuple/control invariants](../../../src/ir/local_graph_test.mbt), and
[dispatcher fixture](../../../src/cmd/perf_precompute_module_env_wbtest.mbt).

## September 27, 2026: stable forward transfers

The forward solver executes each block on its first visit, then repeats its pure
transfer only when the block's incoming state changes. A fixed function and CFG
produce the same output from the same input; transfers clone their input and
replace changed local sets. Retaining the prior output therefore preserves the
fixed point, including exceptional predecessors and source ordering. Predecessor
merges and the final source-recording traversal remain unchanged.

A bounded test first observed nine transfers where the CFG needs only its first
visits; it now checks the reduced count and exact entry/exit reaching definitions
in expanded and unexpanded modes. Existing tuple/control tests plus the command
branch-join fixture pass (37 focused tests). Same-binary native reference/current
controls assert every converged input state before timing: 64 expanded regions
improve **2.57 ms → 484.08 µs**, 256 regions **44.78 → 6.82 ms**, and the
unexpanded 64-region control **22.12 → 1.05 ms**. These are synthetic solver
measurements, not whole-pass speedup claims. Final artifact and generated checks
are recorded in the [campaign report](../tooling/tracing-playbook.md).

Sources: [solver](../../../src/ir/local_graph.mbt),
[bounded invariant](../../../src/ir/local_graph_stable_transfer_wbtest.mbt),
[paired native controls](../../../src/ir/local_graph_stable_transfer_perf_wbtest.mbt),
and [dispatcher join fixture](../../../src/cmd/perf_precompute_module_env_wbtest.mbt).

## September 27, 2026: ordered sparse forward work queues

The forward solver now re-merges only blocks whose predecessors changed output.
It still visits every block once, including disconnected regions, and retains
ascending block order within each original convergence round. A changed output
queues later successors in the current round and earlier successors in the next;
exceptional edges follow the query's existing inclusion policy. Two min-heaps
preserve source ordering without rescanning unrelated stable blocks. Transfers
and immutable source-set ownership are unchanged.

The bounded red-first regression observed 77 predecessor merges on 12 blocks;
the new queue needs 19. It asserts every input state against the former solver,
exit reaching writes, and unchanged-local defaults in both CFG modes. A separate
loop/handler case checks cyclic convergence and exceptional-edge filtering.
The dispatcher verifies a constant propagated across a finite loop. All 38
focused tests pass. Native same-binary original/current controls assert exact
states before timing: expanded 32/128 reads/locals **2.33 ms → 174.85 µs**,
expanded 128/512 **130.68 → 2.62 ms**, unexpanded 32/128 **2.35 ms → 187.35 µs**.

The isolated large propagation artifact improves **1,983.883 → 1,684.910 ms**
pipeline in alternating pairs (one warmup, three accepted rounds), with identical
output bytes and independent validation. This is still above one second;
six small/large pairs preserve bytes and validate, with OI effectively flat
(3,592.813 → 3,631.380 ms large). The large MergeLocals fixture is still a
guarded no-op, so its 42.053 → 46.080 ms admission timing is not evidence
about solver throughput. Final aggregate renewal is tracked in
`.tmp/pass-perf-next-20260927/`. This checkpoint does not close DAE2's sparse
reverse-query costs or the remaining propagation gap.

Sources: [solver](../../../src/ir/local_graph.mbt),
[bounded invariants](../../../src/ir/local_graph_worklist_wbtest.mbt),
[native controls](../../../src/ir/local_graph_worklist_perf_wbtest.mbt), and
[dispatcher loop fixture](../../../src/cmd/perf_local_flow_worklist_wbtest.mbt).

## September 27, 2026: sparse tuple evaluation state

Unexpanded block transfers now record only tuple producers actually encountered
on a path. Scalar nodes allocate no tuple entries. Conditional arms copy the
encountered set; their join retains its intersection, so a producer evaluated
on only one arm can still execute afterward. Expanded CFG transfer remains
unchanged and needs no entries. This replaces a function-sized Boolean array
per block and its whole-array copies/intersection at every nested conditional.
It does not change local-state joining, exceptional policy or source ordering.

The scalar storage bound failed at four flags before implementation and now
requires zero while asserting reaching writes and influences. An independent
copy of the former dense transfer checks exact states and observation order
through shared tuple producers, nested joins, loops and handlers. All 41 focused
checks pass, including active tuple-producer dispatch through Coalesce, DAE2,
propagation and OI. Native full-transfer controls improve **326.91 → 83.52 µs**
for 64 scalar regions and **4.07 ms → 344.22 µs** for 256.

One warmup and three isolated alternating pairs reduce large DAE2 pipeline
**5,447.170 → 5,228.758 ms (4.0%)** with identical raw bytes, traced/untraced
agreement and independent validation. Large propagation (1,553.324 →
1,557.568 ms) and OI (2,738.469 → 2,733.916 ms) are effectively unchanged.
Small DAE2 improves 17.604 → 17.268 ms; propagation 5.198 → 4.976 ms;
OI is 3.328 → 3.346 ms. Remaining pass and parity gaps stay open;
final affected-pass aggregate renewal is pending.

Evidence: `.tmp/pass-perf-next-20260927/sparse-tuples-{checks.json,bench-0.log}`
and `sparse-tuples-pairs-{small,large}/result.json`; native SHA-256
`ad4bc3b931fc54a838cc0db1e2d3af0e3f9a3481932f19bad08b78d51139a1d6`.
Sources: [transfer](../../../src/ir/local_graph.mbt),
[sparse state](../../../src/ir/local_graph_sparse_tuple_state.mbt),
[exact reference comparison](../../../src/ir/local_graph_sparse_tuple_wbtest.mbt),
[scalar invariant](../../../src/ir/local_graph_tuple_state_wbtest.mbt),
[native controls](../../../src/ir/local_graph_sparse_tuple_perf_wbtest.mbt), and
[dispatcher test](../../../src/cmd/perf_lower_input_view_wbtest.mbt).

## September 27, 2026: borrowed immutable predecessor states

Forward merges borrow the first admitted predecessor state and copy its outer
array only when a later predecessor adds a source. Source sets remain immutable;
nonempty transfers still own an outer-array copy before replacing local sets.
Empty blocks share their input, and identity checks avoid rescanning shared
states. Exceptional-edge filtering and first-seen source order are unchanged.

Two ownership checks failed before implementation. The three bounded regressions
compare exact sources with the original merger, exercise subset and multi-source
joins, and prove later transfers cannot modify either predecessor. All 16 focused
checks pass, including the dispatcher fixture that retains an earlier captured
local across both arms of a later write. Native batches of 128 single-predecessor
merges improve **65.76 → 1.71 µs** at 128 locals and **2.02 ms → 1.90 µs** at
4,096 locals; these are helper measurements, not whole-pass speedups.

One warmup and three accepted alternating compiler-artifact pairs reduce large
propagation pipeline **1,637.447 → 1,584.323 ms** and DAE2 **5,704.756 →
5,543.947 ms**. Large OI is effectively flat (2,792.210 → 2,832.533 ms). Small
propagation improves 5.442 → 5.175 ms, DAE2 18.918 → 18.805 ms, while OI
increases 3.456 → 3.570 ms and MergeLocals 1.502 → 1.824 ms. The guarded large
MergeLocals admission timing (38.928 → 42.759 ms) does not exercise this path.
All eight pairs preserve raw bytes, traced/untraced agreement and independent
validation. Remaining budgets and final aggregate renewal stay open.

Evidence: `.tmp/pass-perf-next-20260927/flow-borrow-{checks.json,bench-0.log}`
and `flow-borrow-pairs-{small,large}/result.json`; native SHA-256
`e0df4ac3a6947fc3eafb868a3549d1e6dadc1ca2c0e8a0047df290a7e23f3f3c`.
Sources: [implementation](../../../src/ir/local_graph.mbt),
[bounded ownership checks](../../../src/ir/local_graph_borrow_wbtest.mbt),
[original reference](../../../src/ir/local_graph_borrow_reference_wbtest.mbt),
[native controls](../../../src/ir/local_graph_borrow_perf_wbtest.mbt), and
[dispatcher fixture](../../../src/cmd/perf_local_flow_borrow_wbtest.mbt).

## Pass-local expanded SSA — October 7, 2026

This update supersedes root-only graph descriptions for the full SSA pass
and the admitted SSA-nomerge path. Each builds one operand-expanded CFG locally;
the revision-only shared analysis cache retains its existing graph contract.
Expanded SSA renaming handles each listed node's local action once. It does
not recursively rename a producer again at its consumer. Root-only clients
retain the recursive walk.

The dispatcher keeps escaping block writes and legacy Try accesses on canonical
locals. This includes repeated body-local and parameter definitions. A forward
scan stops a pending escape at a dominating root overwrite. If arms share one
alias boundary, so one arm's writes do not reach the other arm's reads.

Parameter If writes use separate instruction flags. Incoming writes still
freshen and the existing If entry copy restores them. Earlier writes can also
freshen when a later canonical write dominates them in the same straight-line
segment. Calls and control exits split those segments. Pending candidates use
two primitive integer rows; each candidate is marked once. The scan has linear
work and O(locals + regions + instructions) scratch, with no per-write objects
or local-by-region matrix. The scan scratch is released before rewriting.
Legacy Try bodies and catches enter the loop read/write scans as well.

The fixed input-local limit includes scratch types added by preceding stages.
New types added during this rewrite do not expand that limit. Escape and loop
masks use that input limit. Seen-write heuristics retain the original declaration
limit; alias rows grow only when a source lane actually freshens. This avoids
copying unused appended aliases into each control arm. Allocator index heuristics
retain the original declaration limit. A loop records first reads directly in
one integer row, without a new read bitset or a full-local scan per instruction.
Each loop scan uses O(loop subtree + input locals) work. Branch write masks are
collected once per arm. Nested loop scans and later-read heuristics still have
separate costs; this is not a claim that the whole legacy freshener is linear.

The [direct regressions](../../../src/passes/p00_scratch_escapes_wbtest.mbt)
cover both write forms, parameters, If continuations, conditional exits,
legacy catches and independent freshening. EH phi/copy placement remains open.

Evidence: [ssa_local.mbt](../../../src/ir/ssa_local.mbt), [ssa_local_test.mbt](../../../src/ir/ssa_local_test.mbt), [ssa.mbt](../../../src/passes/ssa.mbt), [ssa_nomerge.mbt](../../../src/passes/ssa_nomerge.mbt), [pass_manager.mbt](../../../src/passes/pass_manager.mbt), [p00_flow_wbtest.mbt](../../../src/cmd/p00_flow_wbtest.mbt). See the [current checkpoint](../tooling/validation-gates.md#october-7-2026--p00-control-exception-and-ownership-repairs) for exact validation, timing and open limits.

The direct branch-operand repair also preserves only operand writes that
supply phi inputs in the same predecessor. Copies placed before a branch cannot
read a fresh local defined by that branch condition. One operand bitset, work
array, and phi-input scan retain independent local transformations. See
[`ssa_nomerge.mbt`](../../../src/passes/ssa_nomerge.mbt) and
[the direct regression](../../../src/passes/p00_ssa_branch_operand_wbtest.mbt).

## Cache ownership and repeated entries

`HotAnalysisCache` binds derived analyses to the physical root array of one
function, as well as its revision. Reusing a cache for another function clears
its prior analyses. Verification reports `InvalidAnalysisOwner` if the cache
owner differs. The generated interface adds the owner field and this public
error variant; exhaustive external error matches must handle it.

Full SSA, SSA-nomerge, MergeLocals, and the affected cleanup routes retain a
conservative boundary for repeated entry evaluation until their mutation
contracts can place copies for each occurrence. Straight-line expanded local
flow can still represent those evaluations.

Tuple materialization keeps source-positioned capture stores and uses nullable
reference storage where required. Later observable-prefix and source-local
capture scans do not capture those stable reads again. Their original producers
retain their effects and execution count.

Sources: [cache](../../../src/ir/analysis_cache.mbt),
[verifier](../../../src/ir/hot_verify.mbt),
[lift](../../../src/ir/hot_lift.mbt), and
[direct ownership/capture tests](../../../src/ir/mass_audit_ir_wbtest.mbt).
