# 0061 - Local SSA Policy

## Scope

- Lock SSA v1 to a locals-only analysis overlay on top of `HotFunc`.
- Define SSA values, phi ownership, entry definitions, phi placement, rename policy, and destruction policy.
- Leave concrete SSA construction and destruction mechanics to later slices.

## Current Behavior

- `HotFunc` remains the only owned optimizer body representation under the IR2 architecture rules.
- CFG, dominance, use-def, and liveness overlays now exist with a shared normal-flow policy that excludes exceptional edges from dominance and liveness propagation.
- There was no canonical SSA policy yet, so later construction work could have drifted into incompatible ownership or placement rules.

## Policy

- SSA v1 is an overlay keyed to `HotFunc.revision`, not a new body representation.
- Scope is locals-only:
  - defs come from parameter entry definitions, default-local-init entry definitions, `LocalSet`, `LocalTee`, and overlay phis.
  - uses come from `LocalGet` and phi inputs.
- `SsaValueId` and `PhiId` are overlay-local analysis ids, not `HotFunc` node ids.
- Every local starts with exactly one synthetic entry definition:
  - parameters use `EntryParamDef(local_id)`.
  - body locals use `EntryDefaultInitDef(local_id)`.
- Phi nodes are block-entry overlay facts only:
  - they are never persistent `HotFunc` nodes.
  - they name one local per block entry.
  - their resulting SSA value is a normal SSA definition, but the phi itself lives only in the overlay.
- Phi placement policy is pruned Cytron placement:
  - seed from the synthetic entry definition and all real local definition blocks.
  - walk dominance frontiers.
  - keep only frontier blocks where the local is live-in.
- Rename policy is dominator-tree renaming over ordinary local ops plus overlay phis.
- Destruction policy is parallel-copy lowering in predecessor blocks so plain hot local ops remain the post-pass body form.

## SSA v1 Exclusions

- Exceptional-edge SSA is out of scope until dominance/liveness grow an exceptional-flow mode.
- No IR-owned SSA body or persistent phi nodes may be added.
- SSA values do not model globals, memory, tables, stack values, or non-local expression values.
- Multi-value block parameters and non-local generalized SSA remain future work.

## Correctness Constraints

- `HotFunc` stays ordinary hot IR before and after SSA-assisted passes.
- Every SSA value has exactly one defining origin.
- Phi placement must stay consistent with the current normal-flow CFG, dominance, and liveness policy.
- Revision changes invalidate the overlay.

## Validation Plan

- Unit tests lock entry-definition classification and overlay phi metadata queries.
- Unit tests lock pruned dominance-frontier phi placement on a diamond.
- Unit tests lock overlay-only phi policy and the v1 exclusion list.

## Performance Impact

- This slice is mostly metadata plus a reusable pruned phi-placement helper.
- Runtime cost is limited to dominance-frontier walks during placement queries; no owned-body duplication is introduced.

## Open Questions

- Whether SSA v2 should grow an exceptional-edge mode or keep exceptional-flow rewrites in non-SSA analyses.
- Whether future generalized SSA should add separate overlays for stack values instead of widening the locals-only surface.
