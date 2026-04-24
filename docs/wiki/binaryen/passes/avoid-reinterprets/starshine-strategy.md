---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md
  - ../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/ir/hot_builders.mbt
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/ir/use_def.mbt
  - ../../../../../src/ir/ssa_local.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../alignment-lowering/index.md
  - ../optimize-added-constants/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./single-load-chains-and-bailouts.md
  - ./wat-shapes.md
  - ../alignment-lowering/index.md
  - ../optimize-added-constants/index.md
---

# Starshine Strategy For `avoid-reinterprets`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`](../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main uncertainty a future parity port must resolve.

## The honest current status

`avoid-reinterprets` is still **unimplemented** in Starshine.
There is no `src/passes/avoid_reinterprets.mbt` owner file today.

The current Starshine strategy is deliberately limited:

- preserve the pass spelling in the registry as a known removed name
- reject active requests honestly instead of silently no-oping
- keep the older Batch 1 port-intent breadcrumb visible
- keep its absence from the canonical no-DWARF path explicit
- keep the missing dedicated backlog slice explicit
- document which existing HOT-IR utilities would likely matter to a future port without pretending they already implement Binaryen's proof

So this is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- removed pass-name tracking
  - [`src/passes/optimize.mbt#L144-L153`](../../../../../src/passes/optimize.mbt#L144-L153)
    - `pass_registry_removed_names()` includes `"avoid-reinterprets"`
- registry entry construction for removed names
  - [`src/passes/optimize.mbt#L269-L270`](../../../../../src/passes/optimize.mbt#L269-L270)
    - each removed name becomes a `HotPassRegistryCategory::Removed` registry entry
- active request guard for removed passes
  - [`src/passes/optimize.mbt#L463-L466`](../../../../../src/passes/optimize.mbt#L463-L466)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is removed from the active hot pipeline registry`
- generic removed-name regression coverage
  - [`src/passes/registry_test.mbt#L160-L168`](../../../../../src/passes/registry_test.mbt#L160-L168)
    - the current test proves removed names reject; it uses `de-nan`, not `avoid-reinterprets`, so the coverage is category-level rather than pass-specific
- older pass-port planning breadcrumb
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L42-L43`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L42-L43)
    - `avoid-reinterprets` is still listed under Batch 1 names removed until a hot implementation lands
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `avoid-reinterprets` in the active default route
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `avoid-reinterprets` slice

That map is the durable local status today: the pass is known, intentionally unavailable, and not assigned to an active implementation slice.

## Nearby HOT-IR surfaces a future port would likely use

The repo already has several low-level tools that would probably matter if `avoid-reinterprets` is ported later:

- node builders for the shapes Binaryen rewrites
  - [`src/ir/hot_builders.mbt#L296-L333`](../../../../../src/ir/hot_builders.mbt#L296-L333)
    - `hot_build_local_get`, `hot_build_local_set`, and `hot_build_local_tee`
  - [`src/ir/hot_builders.mbt#L533-L546`](../../../../../src/ir/hot_builders.mbt#L533-L546)
    - `hot_build_load`
  - [`src/ir/hot_builders.mbt#L608-L618`](../../../../../src/ir/hot_builders.mbt#L608-L618)
    - `hot_build_unary`
- fresh local allocation
  - [`src/ir/hot_mutate.mbt#L196-L201`](../../../../../src/ir/hot_mutate.mbt#L196-L201)
    - `hot_append_body_local(...)` appends typed body locals and bumps the HOT revision
- local read/write discovery
  - [`src/ir/use_def.mbt`](../../../../../src/ir/use_def.mbt)
    - the use-def layer records local reads and writes
- SSA-like local value mapping
  - [`src/ir/ssa_local.mbt`](../../../../../src/ir/ssa_local.mbt)
    - the local SSA layer maps `local.get` nodes to value IDs and records write defs

Those files are **not** a finished port.
They only identify plausible building blocks for the future implementation.

## The key Starshine-specific uncertainty

Binaryen's correctness proof is not just “this value came from a load.”
It specifically asks `LocalGraph` for a single reaching set, rejects entry/parameter values, follows only fallthrough values, rejects cycles, and then checks that the source load is reachable and full-width.

Starshine does not currently have a documented `LocalGraph`-equivalent pass-local proof for `avoid-reinterprets`.
The closest-looking local facilities are `use_def` and HOT local SSA, but the wiki should not blur that boundary.

A future port must decide whether to:

1. build a small pass-local reaching-set proof just for this pass,
2. reuse HOT local SSA after documenting exact behavior for params, default values, merges, unreachable cycles, and wrapper fallthrough,
3. or add a LocalGraph-like helper shared with future locals-family ports.

Until that decision lands, the correct Starshine strategy is to keep the pass unavailable and preserve the Binaryen proof obligations in the dossier.

## What Starshine currently does for the pass name

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `avoid-reinterprets` in `pass_registry_removed_names()`.
That means:

- the spelling remains discoverable in the local registry
- older planning docs and new wiki pages can point at one consistent local status
- future port work does not need to rediscover whether the repo meant to track this upstream pass

### 2. The active pipeline rejects it honestly

When a user requests a removed pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a removed-pass error.
That behavior matters because:

- explicit pass requests do not silently pretend to optimize
- the registry category remains executable documentation
- future implementation work will have to change the category and tests intentionally

### 3. The old Batch 1 map is only a breadcrumb

The pass-port batch map still lists `avoid-reinterprets` under Batch 1 removed names, but `agent-todo.md` has no dedicated current slice for it.
Treat that as a weak historical planning signal, not an active commitment.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- direct full-width `reinterpret(load)` can become an opposite-typed load directly
- indirect `reinterpret(local.get)` needs a single-load provenance proof first
- the original typed load result must remain available for non-reinterpret users
- multiple reinterpret users of one source load should share one alternate typed helper local
- partial loads remain no-ops
- unreachable loads remain no-ops
- parameter/default-entry values remain no-ops unless an intentional extension is documented
- multi-source local merges remain no-ops
- non-fallthrough wrappers remain barriers
- memory64 pointer helpers must use the memory's address type rather than hardcoded `i32`

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./single-load-chains-and-bailouts.md`](./single-load-chains-and-bailouts.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Nearby boundaries to keep distinct

### `alignment-lowering`

See [`../alignment-lowering/index.md`](../alignment-lowering/index.md).

Both passes touch memory-adjacent syntax, but they prove different things:

- `avoid-reinterprets` duplicates full-width loads to avoid reinterpret users
- `alignment-lowering` legalizes weak alignment by splitting scalar loads/stores into smaller aligned accesses

Do not merge them into a vague “memory cleanup” port plan.

### `optimize-added-constants`

See [`../optimize-added-constants/index.md`](../optimize-added-constants/index.md).

Both can rewrite load syntax, but their operands and safety proofs differ:

- `avoid-reinterprets` changes the loaded value type and may duplicate a same-address load
- `optimize-added-constants` rewrites address arithmetic into memarg offsets under low-memory safety constraints

Keeping the split explicit prevents accidental overgeneralization.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep removed-pass rejection until the transform exists
   - when the pass lands, update registry category, tests, and docs in the same change
2. reduced WAT-shape tests
   - direct load flip
   - one indirect reinterpret user
   - multiple reinterpret users sharing one helper local
   - mixed original and reinterpret users
   - copy-chain positive
   - partial-load no-op
   - merge/param/no-fallthrough bailouts
   - memory64 pointer-temp typing
3. source parity
   - compare direct `--pass avoid-reinterprets` behavior against Binaryen for focused fixtures
4. broader fuzzing only after the reduced rules are green
   - the risky part is the reaching-set proof, so fuzzing should classify merge/default/wrapper failures explicitly

## Bottom line

Current Starshine `avoid-reinterprets` strategy is honest removed-name tracking plus an explicit future-proofing map:

- the pass name is preserved at [`src/passes/optimize.mbt#L144-L153`](../../../../../src/passes/optimize.mbt#L144-L153)
- active requests are rejected at [`src/passes/optimize.mbt#L463-L466`](../../../../../src/passes/optimize.mbt#L463-L466)
- Batch 1 planning still mentions it at [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L42-L43`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L42-L43)
- the active backlog still has no dedicated slice
- the likely local building blocks are HOT builders, fresh body-local allocation, use-def, and local SSA, but none of those should be mistaken for Binaryen's existing `LocalGraph` proof

So the right mental model today is:

- **no transform yet**
- **clear removed-registry behavior**
- **source-backed Binaryen contract**
- **clear future proof obligation around single-load provenance**
- **clear local uncertainty until a real implementation slice chooses the analysis shape**
