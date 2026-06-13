---
kind: decision
status: supported
last_reviewed: 2026-06-09
sources:
  - ../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md
  - ../raw/ir2/2026-06-04-local-ssa-cache-and-pass-refresh.md
  - ../raw/ir2/2026-05-20-local-ssa-source-bridge.md
  - ../raw/research/0061-2026-03-24-local-ssa-policy.md
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

## Overview

Starshine's local SSA is **not** a second optimizer IR. It is a locals-only analysis overlay built over a normal [`HotFunc`](../../../src/ir/hot_core.mbt) body, keyed to that function's revision. The body remains ordinary HOT IR before and after SSA-assisted work: local reads are still `LocalGet`, writes are still `LocalSet` / `LocalTee`, and phis are metadata that never become persistent HOT nodes.

Use this page when adding or reviewing an SSA-assisted pass, debugging local-def/use facts, or deciding whether a new optimization really needs the current local overlay versus a different IR2 analysis. The classic external lineage is Cytron-style SSA placement, but Starshine intentionally narrows it: [`ssa_policy.mbt`](../../../src/ir/ssa_policy.mbt) uses dominance frontiers plus liveness filtering for locals, [`ssa_local.mbt`](../../../src/ir/ssa_local.mbt) performs dominator-tree renaming over local ops, and [`ssa_destroy.mbt`](../../../src/ir/ssa_destroy.mbt) lowers overlay phis back to predecessor copies so the owned body never stops being HOT IR. [`local_graph.mbt`](../../../src/ir/local_graph.mbt) is a separate Binaryen-facing reaching-source graph: it records entry/default sources and explicit local writes that can reach each `LocalGet`, plus the gets influenced by each set/tee, without rewriting the function. The current cache/pass-use source bridge is [`../raw/ir2/2026-06-04-local-ssa-cache-and-pass-refresh.md`](../raw/ir2/2026-06-04-local-ssa-cache-and-pass-refresh.md); the original bibliographic and implementation bridge remains [`../raw/ir2/2026-05-20-local-ssa-source-bridge.md`](../raw/ir2/2026-05-20-local-ssa-source-bridge.md), and the first local policy note is archived at [`../raw/research/0061-2026-03-24-local-ssa-policy.md`](../raw/research/0061-2026-03-24-local-ssa-policy.md).

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
| LocalGraph source | `HotLocalGraphSource` | Binaryen-facing reaching-source fact: either `EntrySource(local_id)` or `SetSource(node_id)`. Entry sources now carry first-class param-vs-body-default classification through `local_graph_source_is_param_entry(...)`, `local_graph_source_is_default_entry(...)`, `local_graph_entry_source_is_param(...)`, and `local_graph_entry_source_is_default(...)`. |
| LocalGraph get class | `local_graph_get_is_single_source(...)` / `local_graph_get_is_merge(...)` | Whether a `LocalGet` has exactly one reaching source or multiple reaching sources, matching the first analysis-only step toward Binaryen `SSAify.cpp` no-merge decisions. |
| LocalGraph influence | `local_graph_influenced_gets_for_set(...)` | The `LocalGet` nodes whose reaching-source set includes a specific `LocalSet` / `LocalTee`. |

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
6. Visit ordinary HOT nodes child-first for non-region operands; `LocalGet` consumes the current value, while `LocalSet` and `LocalTee` create new values and push them on the local stack.
7. Record phi inputs on normal successor edges, explicitly skipping `ExceptionalEdge` successors.
8. Sort phi inputs into predecessor order and abort if a phi's inputs no longer align with the normal-flow predecessor set.

Concrete locked examples live in [`ssa_local_test.mbt`](../../../src/ir/ssa_local_test.mbt): diamond joins create one join phi, loop headers create loop-carried phis, uninitialized locals read their default-init entry definitions, `LocalTee` creates a definition for later reads, and unreachable branch-carry ladders do not let unreachable predecessor blocks corrupt phi-input alignment.

## LocalGraph Companion Analysis

[`local_graph_build(...)`](../../../src/ir/local_graph.mbt) is analysis-only. It uses the existing normal-flow CFG and child-before-parent HOT expression order to compute may-reaching local sources:

- every local begins with an entry source;
- entry sources are classified as parameter entries or body-local default entries so future no-merge/full-SSA decisions can distinguish caller-provided values from implicit WebAssembly defaults;
- `LocalSet` and `LocalTee` replace the current source set for their local on that path;
- joins union source sets from normal predecessors;
- `LocalGet` queries expose single-source versus merge-source classification without mutating the function;
- exceptional edges are skipped for now, matching the local SSA v1 normal-flow policy;
- `local_graph_can_move_set_past_node(...)` ports the Binaryen `canMoveSet` test idea by reporting only influenced gets still reachable from a set when a candidate obstacle node blocks paths after that set.

This graph is intentionally not a mutation engine yet. It is the staged bridge toward Binaryen-style `SSAify.cpp` decisions for future `ssa-nomerge` and full `ssa` work. Locked examples live in [`local_graph_test.mbt`](../../../src/ir/local_graph_test.mbt): simple set/get influence, get-before-set entry reads, param-vs-default entry classification, single-source/merge get classification, overwrite kills, diamond merge sources, loop-carried sources, and Binaryen `canMoveSet` obstacle families.

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

- 2026-06-09 exceptional-edge audit: [`../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md`](../raw/research/0722-2026-06-09-ssa-nomerge-exceptional-edge-audit.md)
- Current cache/pass-use refresh: [`../raw/ir2/2026-06-04-local-ssa-cache-and-pass-refresh.md`](../raw/ir2/2026-06-04-local-ssa-cache-and-pass-refresh.md)
- SSA lineage and source bridge: [`../raw/ir2/2026-05-20-local-ssa-source-bridge.md`](../raw/ir2/2026-05-20-local-ssa-source-bridge.md)
- Archived original policy note: [`../raw/research/0061-2026-03-24-local-ssa-policy.md`](../raw/research/0061-2026-03-24-local-ssa-policy.md)
- Policy/query layer: [`../../../src/ir/ssa_policy.mbt`](../../../src/ir/ssa_policy.mbt)
- Builder: [`../../../src/ir/ssa_local.mbt`](../../../src/ir/ssa_local.mbt)
- Destruction/writeback: [`../../../src/ir/ssa_destroy.mbt`](../../../src/ir/ssa_destroy.mbt)
- Cache/pass helper layer: [`../../../src/ir/analysis_cache.mbt`](../../../src/ir/analysis_cache.mbt), [`../../../src/ir/architecture.mbt`](../../../src/ir/architecture.mbt), [`../../../src/passes/pass_common.mbt`](../../../src/passes/pass_common.mbt)
- Tests: [`../../../src/ir/ssa_policy_test.mbt`](../../../src/ir/ssa_policy_test.mbt), [`../../../src/ir/ssa_local_test.mbt`](../../../src/ir/ssa_local_test.mbt), [`../../../src/ir/ssa_destroy_test.mbt`](../../../src/ir/ssa_destroy_test.mbt), [`../../../src/ir/local_graph_test.mbt`](../../../src/ir/local_graph_test.mbt), [`../../../src/ir/analysis_cache_test.mbt`](../../../src/ir/analysis_cache_test.mbt)
- Supporting overlays: [`../../../src/ir/use_def.mbt`](../../../src/ir/use_def.mbt), [`../../../src/ir/liveness.mbt`](../../../src/ir/liveness.mbt), [`../../../src/ir/dominators.mbt`](../../../src/ir/dominators.mbt), [`../../../src/ir/cfg.mbt`](../../../src/ir/cfg.mbt)
