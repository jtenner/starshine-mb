---
kind: decision
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../0061-2026-03-24-local-ssa-policy.md
related:
  - ./cfg-contract.md
  - ../../../src/ir/ssa_policy.mbt
  - ../../../src/ir/ssa_policy_test.mbt
  - ../../../src/ir/ssa_local.mbt
  - ../../../src/ir/ssa_local_test.mbt
  - ../../../src/ir/ssa_destroy.mbt
  - ../../../src/ir/ssa_destroy_test.mbt
---

# IR2 Local SSA Policy

## Decision

- SSA v1 is a locals-only analysis overlay keyed to `HotFunc.revision`, not a new owned body representation.
- Every local begins with exactly one synthetic entry definition:
  - parameters use entry-parameter defs
  - body locals use default-init entry defs
- Phi nodes are block-entry overlay facts only:
  - they are not persistent `HotFunc` nodes
  - they name one local per block entry
  - their result values are ordinary SSA defs, but the phis themselves stay overlay-only
- Phi placement uses pruned Cytron placement with liveness filtering.
- Rename policy is dominator-tree renaming.
- Destruction policy is predecessor parallel-copy lowering so the post-pass body stays ordinary hot local ops.

## Explicit Exclusions

- Exceptional-edge SSA is out of scope for SSA v1.
- Persistent hot phi nodes are out of scope.
- IR-owned SSA body forms are out of scope.
- Non-local values, globals, memory, tables, and generalized stack SSA are out of scope.

## Current In-Tree Status

- Policy types and queries live in [`../../../src/ir/ssa_policy.mbt`](../../../src/ir/ssa_policy.mbt).
- Policy coverage lives in [`../../../src/ir/ssa_policy_test.mbt`](../../../src/ir/ssa_policy_test.mbt).
- Local SSA construction lives in [`../../../src/ir/ssa_local.mbt`](../../../src/ir/ssa_local.mbt) with build coverage in [`../../../src/ir/ssa_local_test.mbt`](../../../src/ir/ssa_local_test.mbt).
- SSA destruction lives in [`../../../src/ir/ssa_destroy.mbt`](../../../src/ir/ssa_destroy.mbt) with lowering coverage in [`../../../src/ir/ssa_destroy_test.mbt`](../../../src/ir/ssa_destroy_test.mbt).

## Practical Rule

- Keep `HotFunc` ordinary hot IR before and after SSA-assisted passes.
- Do not add persistent phi nodes or widen SSA beyond locals without an explicit contract update first.
- Treat revision changes as invalidating the overlay.

## Sources

- Numbered research doc: [`../../0061-2026-03-24-local-ssa-policy.md`](../../0061-2026-03-24-local-ssa-policy.md)
- Policy layer: [`../../../src/ir/ssa_policy.mbt`](../../../src/ir/ssa_policy.mbt)
- Build and destruction: [`../../../src/ir/ssa_local.mbt`](../../../src/ir/ssa_local.mbt), [`../../../src/ir/ssa_destroy.mbt`](../../../src/ir/ssa_destroy.mbt)
