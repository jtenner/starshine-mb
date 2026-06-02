---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-dealign-primary-sources.md
  - ../../../raw/research/0389-2026-04-26-dealign-port-readiness.md
  - ../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../alignment-lowering/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./align-one-rewrite-surface-and-alignment-lowering-split.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../alignment-lowering/starshine-strategy.md
---

# Starshine Strategy For `dealign`

Use this page together with the raw primary-source manifests in [`../../../raw/binaryen/2026-04-24-dealign-primary-sources.md`](../../../raw/binaryen/2026-04-24-dealign-primary-sources.md) and [`../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md).
The goal here is to show the exact current Starshine status and the concrete local files a future port would need to touch, not to imply that a local implementation already exists. The implementation-order and validation details live in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## The honest current status

`dealign` is **not implemented** in Starshine.

More specifically, it is currently upstream-only rather than even boundary-only:

- no `src/passes/dealign.mbt` owner file exists
- `src/passes/optimize.mbt` does not list `dealign` in active, module, boundary-only, or removed registry names
- explicit `--pass dealign` requests therefore fail through the generic unknown-pass path
- the old pass-port map names neighboring `alignment-lowering`, but not `dealign`
- `agent-todo.md` has no dedicated `dealign` slice
- the canonical no-DWARF Binaryen path does not schedule `dealign`

So this page is a **status and future-port boundary page**, not a code-map for an existing transform.

## Exact local code map today

The fastest read-along path is:

- current known-pass registry lists
  - [`src/passes/optimize.mbt#L127-L153`](../../../../../src/passes/optimize.mbt#L127-L153)
    - `pass_registry_boundary_only_names()` includes `alignment-lowering` but not `dealign`
    - `pass_registry_removed_names()` also omits `dealign`
- request rejection path for names absent from the registry
  - [`src/passes/optimize.mbt#L446-L466`](../../../../../src/passes/optimize.mbt#L446-L466)
    - `run_hot_pipeline_expand_passes(...)` returns `unknown pass flag {name}` when lookup fails
- pass-port planning map
  - [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md#L57-L61`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md#L57-L61)
    - the layout bucket includes `alignment-lowering`; it does not include `dealign`
- canonical no-DWARF path context
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - no current default-route role for `dealign`
- backlog context
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - no dedicated `dealign` slice today
- neighboring local status bridge
  - [`../alignment-lowering/starshine-strategy.md`](../alignment-lowering/starshine-strategy.md)
    - `alignment-lowering` is tracked boundary-only, while `dealign` is currently not tracked in the registry at all

## What Starshine currently does for this pass name

Today Starshine's behavior is simply:

- it does not recognize `dealign` as a known pass name
- it does not silently no-op the request
- it returns the generic unknown-pass error through the registry expansion path

That is an important distinction from many neighboring upstream passes, which are tracked as boundary-only or removed. If future work decides `dealign` should be user-visible, the first local change should probably be a registry/status decision before any transform work.

## Why the local strategy is different from `alignment-lowering`

`alignment-lowering` is locally tracked as boundary-only because older port maps and neighboring memory-lowering plans already named it.

`dealign` is different:

- it is not in the current local registry
- it is not in the older pass-port map
- it has no backlog slice
- its main value today is explanatory: it keeps the `alignment-lowering` sibling boundary precise

So future work should not assume that `dealign` must be ported merely because `alignment-lowering` is tracked.

## Future port contract if the repo chooses to add it

If Starshine later chooses to implement or at least recognize `dealign`, the source-backed contract is small:

- add an explicit registry status for `dealign` in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- keep request behavior honest until the transform exists
- implement only the reviewed Binaryen surface unless deliberately extending it:
  - `Load`
  - `Store`
  - `SIMDLoad`
- set the alignment metadata to `1`
- preserve offsets, widths, signedness, child expressions, result types, and control flow
- do not split accesses into chunks
- do not claim `SIMDStore`, atomics, or bulk-memory coverage without fresh source-backed justification

## Likely local landing options

Because the pass is metadata-only, a future implementation could plausibly land in more than one place:

1. a tiny module/function traversal over Starshine's library IR memory instructions;
2. a HOT-side memory-access rewrite if HOT reliably carries all relevant memarg alignment fields; or
3. a late boundary/emit-side normalization if the main use case is testing or backend stress.

The repo has not chosen among those options. Keep that uncertainty explicit until a real implementation plan lands.

## Validation plan for a future port

A future local implementation should include reduced tests for:

- `i32.load` default alignment printing as `align=1`
- explicit `align=2` scalar load/store becoming `align=1`
- explicit `align=1` staying `align=1`
- offset preservation
- child-expression preservation
- source-confirmed broader `Load` / `Store` family coverage if represented locally
- `SIMDLoad` coverage only if Starshine's IR/parser surface can express and round-trip it
- negative tests documenting no `SIMDStore`, atomic, or bulk-memory rewrite unless intentionally added

Then compare the pass directly against Binaryen on focused WAT fixtures before adding any preset role.

## Bottom line

Current Starshine `dealign` strategy is **do not pretend it exists locally**:

- Binaryen has a real tiny pass, documented in [`./binaryen-strategy.md`](./binaryen-strategy.md)
- Starshine does not track the name in [`src/passes/optimize.mbt#L127-L153`](../../../../../src/passes/optimize.mbt#L127-L153)
- explicit requests fall through the unknown-pass path at [`src/passes/optimize.mbt#L446-L466`](../../../../../src/passes/optimize.mbt#L446-L466)
- no backlog, port-map, or no-DWARF route currently assigns local work to it
- the main local value today is keeping the [`alignment-lowering`](../alignment-lowering/index.md) boundary precise

## Sources

- [`../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-dealign-primary-sources.md`](../../../raw/binaryen/2026-04-24-dealign-primary-sources.md)
- [`../../../raw/research/0389-2026-04-26-dealign-port-readiness.md`](../../../raw/research/0389-2026-04-26-dealign-port-readiness.md)
- [`../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md`](../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../alignment-lowering/index.md`](../alignment-lowering/index.md)
