---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md
  - ../../../raw/research/0336-2026-04-25-reorder-globals-always-source-bridge.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../agent-todo.md
  - ../reorder-globals/starshine-strategy.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./small-module-threshold-scoring-and-proof.md
  - ./wat-shapes.md
  - ../reorder-globals/index.md
  - ../global-struct-inference/index.md
  - ../reorder-globals/starshine-strategy.md
---

# Starshine strategy for `reorder-globals-always`

Use this page together with the sibling-specific raw manifest in [`../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md`](../../../raw/binaryen/2026-04-25-reorder-globals-always-primary-sources.md).
This is a **status-and-port-strategy** page: Starshine does not implement the transform today, so the goal is to show exactly what is tracked locally, where active requests stop, and which code surfaces a future implementation would have to touch.

## Honest current status

`reorder-globals-always` is currently **boundary-only** in Starshine.

That means:

- the pass name is intentionally recognized as a real compatibility / planning surface
- it is not available in the active hot or module optimizer pipeline
- explicit user requests are rejected with the standard boundary-only error
- public `optimize` and `shrink` presets do not schedule it
- there is no `src/passes/reorder_globals_always.mbt` owner file today
- there is also no shared `src/passes/reorder_globals.mbt` owner file that could host both the production and always variants today

The important local distinction is:

- [`../reorder-globals/starshine-strategy.md`](../reorder-globals/starshine-strategy.md) covers the production late-tail backlog slice `RG`
- this page covers the sibling whose upstream purpose is small-module / test / internal-fixup behavior

## Exact local code map today

The fastest local read-along path is:

- boundary-only name tracking
  - [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
  - `pass_registry_boundary_only_names()` includes both `"reorder-globals"` and `"reorder-globals-always"`
- preset omission
  - [`src/passes/optimize.mbt#L242-L270`](../../../../../src/passes/optimize.mbt#L242-L270)
  - [`src/passes/optimize.mbt#L382-L410`](../../../../../src/passes/optimize.mbt#L382-L410)
  - the public `optimize` / `shrink` pass lists do not include either global-reorder sibling
- active request rejection
  - [`src/passes/optimize.mbt#L446-L461`](../../../../../src/passes/optimize.mbt#L446-L461)
  - boundary-only entries return `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- adjacent backlog, but not a sibling-specific backlog
  - [`agent-todo.md#L668-L680`](../../../../../agent-todo.md#L668-L680)
  - `RG - Reorder Globals` covers the production late-tail pass and artifact parity plan; it does not define a separate `reorder-globals-always` slice
- global representation surfaces a future module pass must understand
  - [`src/lib/types.mbt#L113`](../../../../../src/lib/types.mbt#L113) defines `GlobalIdx`
  - [`src/lib/types.mbt#L171`](../../../../../src/lib/types.mbt#L171) defines `GlobalType`
  - [`src/lib/types.mbt#L193`](../../../../../src/lib/types.mbt#L193) defines exported global indices through `ExternIdx`
  - [`src/lib/types.mbt#L224`](../../../../../src/lib/types.mbt#L224) defines `Global`
  - [`src/lib/types.mbt#L442`](../../../../../src/lib/types.mbt#L442) defines `GlobalSec`
  - [`src/lib/types.mbt#L539-L540`](../../../../../src/lib/types.mbt#L539-L540) defines `GlobalGet` / `GlobalSet`
  - [`src/lib/types.mbt#L8059-L8061`](../../../../../src/lib/types.mbt#L8059-L8061) constructs a `GlobalSec`

This is enough to prove the current local state precisely: recognized name, rejected active request, no scheduled preset, no owner file, and a clear future whole-module remap surface.

## What Starshine currently does for the pass name

### 1. Keeps the spelling known

Keeping `reorder-globals-always` in `pass_registry_boundary_only_names()` prevents the pass from becoming an unknown spelling.
That is useful because Binaryen exposes the sibling as a real pass name and because the neighboring `reorder-globals` / `global-struct-inference` docs need the split to stay explicit.

### 2. Rejects explicit execution honestly

The boundary-only category is not a silent no-op.
When the requested pass list expands, `run_hot_pipeline_expand_passes(...)` stops and reports that the pass is boundary-only and unimplemented.

That behavior is correct today because the sibling needs a whole-module declaration reorder plus index repair, not a HOT-region peephole.

### 3. Leaves presets honest

Neither `optimize` nor `shrink` expands to `reorder-globals-always`.
That matches the Binaryen-side teaching:

- ordinary `reorder-globals` is the production late-tail pass
- `reorder-globals-always` is a small-module / test / internal-fixup sibling

Until Starshine has a shared global-reorder module engine, scheduling the sibling would imply a capability the repo does not have.

## Future implementation shape

A faithful future Starshine design should probably share one module-pass engine with production [`../reorder-globals/index.md`](../reorder-globals/index.md), then expose two policy modes:

| Policy | Production `reorder-globals` | `reorder-globals-always` |
| --- | --- | --- |
| Small-module cutoff | no-op below `128` globals | run below `128` globals too |
| Cost model | real stepped index-size model | smooth `1.0 + (i / 128.0)` model |
| Legality | imports-first and initializer dependencies | same |
| Tie behavior | original index remains the stable fallback | same |
| Starshine status today | boundary-only with `RG` backlog | boundary-only with no dedicated sibling slice |

The shared local engine would need to:

1. count `GlobalGet` and `GlobalSet` traffic across function bodies and module-code-like surfaces that Starshine represents
2. count or intentionally exclude any Starshine-specific global-use surfaces with a documented reason
3. build dependency edges from global initializers so a global used in another global's initializer stays earlier
4. keep imported globals before defined globals, matching the local import-section / global-section split
5. choose a dependency-safe candidate order using the right policy-mode score
6. rewrite `GlobalSec` declaration order
7. repair every affected numeric `GlobalIdx` user, including exports and `GlobalGet` / `GlobalSet`
8. validate and compare against Binaryen on reduced shapes before any preset scheduling claim

## Starshine-specific caveat: Binaryen names vs local indices

Binaryen's in-memory IR can reorder global declarations while uses remain name-based.
Starshine's core representation exposes numeric `GlobalIdx` values in instructions and exports.
That makes the local port more index-repair-heavy than the upstream source might look at first glance.

For this sibling, that caveat is especially important because the pass is tempting to treat as “just production `reorder-globals` with `always=true`.”
The policy difference is small, but the local rewrite still needs the same whole-module index correctness as the production pass.

## What not to claim yet

Do **not** claim current Starshine has:

- a runnable `reorder-globals-always` transform
- a module dispatcher case for the sibling
- a Starshine equivalent of Binaryen's nested `GlobalStructInference` repair runner
- reduced local lit/regression tests for tiny-module smooth scoring
- artifact parity for this sibling
- a dedicated backlog slice separate from the production `RG` work

The current repo truth is narrower: the name is tracked and safely rejected, while the implementation remains future module-pass work.

## Validation plan for a future port

A future implementation should validate at three levels.

### Reduced sibling-shape tests

Use the shape families in [`./wat-shapes.md`](./wat-shapes.md):

- tiny independent globals that ordinary production mode would skip
- dependency-preserving chains
- independent hot globals moving around dependency chains
- `global.set` traffic counting
- imports-first negatives
- tied / already-best stability cases

### Shared-engine policy tests

Prove the two local policy modes differ only where Binaryen differs:

- production mode keeps the under-`128` no-op
- always mode removes that no-op
- production mode uses real stepped cost
- always mode uses the smooth synthetic cost
- both modes preserve dependency and import legality

### Starshine remap tests

Because local globals are index-bearing, test at least:

- exported global index repair
- `GlobalGet` / `GlobalSet` body repair
- global-initializer dependency repair
- imported-global prefix preservation
- final module validation after reorder

For production parity, use the `RG` backlog and [`../reorder-globals/starshine-strategy.md`](../reorder-globals/starshine-strategy.md). For the sibling, add an explicit future backlog slice only if the project decides it should be user-facing or internally callable.

## Bottom line

Current Starshine strategy for `reorder-globals-always` is:

- keep the real Binaryen pass spelling tracked in [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
- keep active requests honest through the boundary-only guard at [`src/passes/optimize.mbt#L446-L461`](../../../../../src/passes/optimize.mbt#L446-L461)
- keep it out of public presets until a shared global-reorder module engine exists
- reuse the production [`reorder-globals`](../reorder-globals/index.md) port plan whenever the project implements the family
- preserve the exact sibling split: no `< 128` bailout plus smooth synthetic scoring, with the same imports/dependency legality
