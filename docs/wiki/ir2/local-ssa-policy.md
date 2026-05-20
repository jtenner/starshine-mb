---
kind: decision
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/ir2/2026-05-20-local-ssa-source-bridge.md
  - ../../0061-2026-03-24-local-ssa-policy.md
  - ../../../src/ir/ssa_policy.mbt
  - ../../../src/ir/ssa_local.mbt
  - ../../../src/ir/ssa_destroy.mbt
  - ../../../src/ir/ssa_policy_test.mbt
  - ../../../src/ir/ssa_local_test.mbt
  - ../../../src/ir/ssa_destroy_test.mbt
related:
  - ./architecture-rules.md
  - ./cfg-contract.md
  - ./test-matrix.md
  - ./pass-porting-checklist.md
  - ../../../src/ir/use_def.mbt
  - ../../../src/ir/liveness.mbt
  - ../../../src/ir/dominators.mbt
  - ../../../src/ir/hot_mutate.mbt
---

# IR2 Local SSA Policy

## Overview

Starshine's local SSA is **not** a second optimizer IR. It is a locals-only analysis overlay built over a normal [`HotFunc`](../../../src/ir/hot_core.mbt) body, keyed to that function's revision. The body remains ordinary HOT IR before and after SSA-assisted work: local reads are still `LocalGet`, writes are still `LocalSet` / `LocalTee`, and phis are metadata that never become persistent HOT nodes.

Use this page when adding or reviewing an SSA-assisted pass, debugging local-def/use facts, or deciding whether a new optimization really needs the current local overlay versus a different IR2 analysis. The classic external lineage is Cytron-style SSA placement, but Starshine intentionally narrows it: [`ssa_policy.mbt`](../../../src/ir/ssa_policy.mbt) uses dominance frontiers plus liveness filtering for locals, [`ssa_local.mbt`](../../../src/ir/ssa_local.mbt) performs dominator-tree renaming over local ops, and [`ssa_destroy.mbt`](../../../src/ir/ssa_destroy.mbt) lowers overlay phis back to predecessor copies so the owned body never stops being HOT IR. The source bridge is [`../raw/ir2/2026-05-20-local-ssa-source-bridge.md`](../raw/ir2/2026-05-20-local-ssa-source-bridge.md); the original local policy note is [`../../0061-2026-03-24-local-ssa-policy.md`](../../0061-2026-03-24-local-ssa-policy.md).

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

- **Revision-keyed:** `HotLocalSsa.revision` records `hot_revision_current(func)` at build time. Treat any mutation through [`hot_mutate.mbt`](../../../src/ir/hot_mutate.mbt) or other revision-bumping APIs as invalidating the overlay.
- **Normal-flow only:** SSA v1 skips exceptional successors while recording phi inputs. Do not use it to prove facts across `try` / `try_table` exceptional edges.
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
- multi-value block-parameter modeling beyond the ordinary HOT/CFG/local policy already documented in [`cfg-contract.md`](./cfg-contract.md).

If future work needs any of those, update the IR2 architecture contract first, add tests before implementation, and record how the new overlay invalidates or coexists with this locals-only policy.

## Maintenance Checklist

- Start from the current code and tests, not the old March policy note alone.
- Keep new queries on `HotLocalSsa` overlay types; do not add persistent SSA nodes to `HotFunc`.
- Build CFG/dominance/use-def/liveness from the same function revision as the SSA overlay.
- Add focused tests in `src/ir/ssa_policy_test.mbt`, `src/ir/ssa_local_test.mbt`, or `src/ir/ssa_destroy_test.mbt` for new placement, rename, or destruction behavior.
- If an optimizer pass uses SSA, document the pass-local assumptions in that pass dossier and include ordinary pass validation plus Binaryen oracle comparison when the pass has an upstream equivalent.

## Sources

- SSA lineage and source bridge: [`../raw/ir2/2026-05-20-local-ssa-source-bridge.md`](../raw/ir2/2026-05-20-local-ssa-source-bridge.md)
- Original policy note: [`../../0061-2026-03-24-local-ssa-policy.md`](../../0061-2026-03-24-local-ssa-policy.md)
- Policy/query layer: [`../../../src/ir/ssa_policy.mbt`](../../../src/ir/ssa_policy.mbt)
- Builder: [`../../../src/ir/ssa_local.mbt`](../../../src/ir/ssa_local.mbt)
- Destruction/writeback: [`../../../src/ir/ssa_destroy.mbt`](../../../src/ir/ssa_destroy.mbt)
- Tests: [`../../../src/ir/ssa_policy_test.mbt`](../../../src/ir/ssa_policy_test.mbt), [`../../../src/ir/ssa_local_test.mbt`](../../../src/ir/ssa_local_test.mbt), [`../../../src/ir/ssa_destroy_test.mbt`](../../../src/ir/ssa_destroy_test.mbt)
- Supporting overlays: [`../../../src/ir/use_def.mbt`](../../../src/ir/use_def.mbt), [`../../../src/ir/liveness.mbt`](../../../src/ir/liveness.mbt), [`../../../src/ir/dominators.mbt`](../../../src/ir/dominators.mbt), [`../../../src/ir/cfg.mbt`](../../../src/ir/cfg.mbt)
