---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-type-ssa-primary-sources.md
  - ../../../raw/research/0277-2026-04-23-type-ssa-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../ssa/index.md
  - ../type-merging/index.md
  - ../type-refining/index.md
  - ../type-generalizing/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./wat-shapes.md
  - ../ssa/index.md
  - ../type-merging/index.md
  - ../type-refining/index.md
  - ../type-generalizing/index.md
---

# Starshine Strategy For `type-ssa`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-type-ssa-primary-sources.md`](../../../raw/binaryen/2026-04-23-type-ssa-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and planning surfaces that already answer whether the pass exists, and the nearest neighboring Starshine code locations a future port would need to study.

## The honest current status

`type-ssa` is still **unimplemented and untracked** in Starshine.
There is no `src/passes/type_ssa.mbt` owner file today.

That status is slightly stronger than many other dossier pages:

- the pass is **not** active
- the pass is **not** tracked as boundary-only
- the pass is **not** tracked as removed
- the pass is **not** listed in the current pass-port batches
- the pass is **not** in the canonical no-DWARF parity queue
- `agent-todo.md` currently has **no dedicated `type-ssa` slice**

So this page is intentionally a **status-and-neighborhood** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- current registry compatibility surface
  - [`src/passes/optimize.mbt#L127-L152`](../../../../../src/passes/optimize.mbt#L127-L152)
    - `pass_registry_boundary_only_names()` and `pass_registry_removed_names()` do **not** include `type-ssa`
- current active registry entries
  - [`src/passes/optimize.mbt#L156-L259`](../../../../../src/passes/optimize.mbt#L156-L259)
    - `pass_registry_entries()` defines the active hot/module/preset entries, and there is no `type-ssa` entry there either
- current expansion / rejection behavior
  - [`src/passes/optimize.mbt#L446-L461`](../../../../../src/passes/optimize.mbt#L446-L461)
    - `run_hot_pipeline_expand_passes(...)` only dispatches active entries or rejects tracked boundary-only / removed names, so `type-ssa` currently has no compatibility-path behavior beyond being absent from lookup data
- current project-wide pass-port map
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L7-L68`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L7-L68)
    - the active hot/module sets, removed batches, and boundary-only groups do not include `type-ssa`
- canonical parity queue by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `type-ssa` in the active Binaryen-parity route
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `type-ssa` slice
- closest neighboring Starshine implementation files today
  - [`src/passes/ssa_nomerge.mbt#L2-L49`](../../../../../src/passes/ssa_nomerge.mbt#L2-L49)
  - [`src/passes/global_refining.mbt#L2-L367`](../../../../../src/passes/global_refining.mbt#L2-L367)
  - [`src/passes/global_struct_inference.mbt#L1-L345`](../../../../../src/passes/global_struct_inference.mbt#L1-L345)

That code-and-doc map is the practical value this page adds: readers can now jump directly from the upstream algorithm to the exact local non-adoption status and the nearest concrete files that would matter if the repo ever chooses to port the pass.

## What Starshine currently does for this pass

Today Starshine's strategy for `type-ssa` is deliberate non-adoption.

### 1. The registry does not pretend to know the pass

Unlike boundary-only names such as `type-refining` or `type-merging`, `type-ssa` is not listed in the current registry metadata.
That means the repo is making a stronger statement than “known but unavailable.”

The durable current answer is:

- Starshine does not currently promise CLI compatibility for the pass name
- Starshine does not currently treat the pass as a planned boundary/module/hot slot
- Starshine does not currently expose a pass-specific rejection path because it has not committed to tracking the name in the first place

That is the right current behavior for an upstream-only pass that has not yet been adopted into local planning.

### 2. The pass-port map does not reserve a slot for it

`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` records active hot passes, module passes, removed batches, and boundary-only groups.
`type-ssa` appears in none of those sections.

So the local planning story today is not “scheduled later.”
It is:

- no current batch owner
- no current registry owner
- no current parity owner

That is useful durable knowledge because it prevents readers from assuming the neighboring GC/type dossiers already imply an active local adoption plan.

### 3. The no-DWARF parity route does not currently depend on it

The canonical no-DWARF `-O` / `-Os` parity page omits `type-ssa`.
That matters because it answers an easy future-question up front:

- a future `type-ssa` port is not required for the repo's current default Binaryen parity queue

So the current Starshine strategy is not “blocked on implementing `type-ssa` for present parity.”
It is simply “document the pass honestly until the repo wants it.”

## The most useful current local neighborhood

Even though the pass is not implemented, the repo already has nearby code and dossier surfaces that define the practical local neighborhood a future port would have to preserve.

### `ssa-nomerge` is the closest active SSA-adjacent implementation

See:

- [`../ssa/index.md`](../ssa/index.md)
- [`src/passes/ssa_nomerge.mbt#L2-L49`](../../../../../src/passes/ssa_nomerge.mbt#L2-L49)

Why it matters locally:

- `type-ssa` also relies on SSA-like flow ideas
- but upstream `type-ssa` is not general SSA construction
- the local `ssa-nomerge` implementation is therefore a useful neighboring code surface, not a hidden implementation of `type-ssa`

### `global-refining` is the closest active local GC/type-tightening module pass

See:

- [`../type-refining/index.md`](../type-refining/index.md)
- [`src/passes/global_refining.mbt#L2-L367`](../../../../../src/passes/global_refining.mbt#L2-L367)

Why it matters locally:

- both families are about making narrower reference-type information visible
- but `global-refining` is a module/global write-aggregation pass, not a created-value SSA-like pass
- that makes it a useful future landing-neighbor while keeping the semantics distinct

### `global-struct-inference` is another active precision neighbor, but with a different evidence source

See:

- [`src/passes/global_struct_inference.mbt#L1-L345`](../../../../../src/passes/global_struct_inference.mbt#L1-L345)
- [`../type-merging/index.md`](../type-merging/index.md)
- [`../type-generalizing/index.md`](../type-generalizing/index.md)

Why it matters locally:

- `global-struct-inference` sharpens types from globally fixed struct origins
- `type-ssa` sharpens types from freshly created exact values flowing through locals/globals/control results
- the future neighborhood is therefore conceptually real, but there is no current shared implementation

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit `type-ssa` implementation file
- a boundary-only or removed registry entry for the pass name
- a dedicated backlog slice in `agent-todo.md`
- a scheduler slot in the active presets or the no-DWARF parity route
- reduced local regressions specific to `type-ssa`
- any artifact replay lane that treats `type-ssa` as an expected missing pass

So the current repo status is best summarized as:

- pass researched upstream
- pass not adopted locally
- no compatibility alias
- no backlog owner
- no parity dependency
- nearest local understanding comes from neighboring SSA and GC/type passes only

## What a future port would need to preserve if Starshine adopts it

Even without a local owner today, the future correctness contract is already clear from the Binaryen dossier.
A faithful Starshine port would need to preserve all of these source-backed properties:

- seed precision only from the tiny created-value surface (`struct.new`, `array.new`, `array.new_fixed`, `ref.as_non_null`, `ref.cast`)
- reject abstract refs in the local equivalent of `getTargetType(...)`
- carry precision through conservative `block` / `if` / `try` value rules only
- keep the explicit `loop` no-propagation boundary
- propagate precision through local/global sets and gets
- retag direct call operands and return values only when subtype-safe
- repair parent expression types after changes in the local equivalent of `ReFinalize`

For the full source-backed explanation of those invariants, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./created-exact-types-control-values-and-signature-rewrites.md`](./created-exact-types-control-values-and-signature-rewrites.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Validation plan for any eventual port

Because the pass is not even registry-tracked today, a real adoption change would need a wider validation story than ordinary pass-local testing.
A future implementation should validate in roughly this order:

1. registry honesty
   - decide whether the pass first lands as tracked boundary-only metadata or as a real active pass
   - update `src/passes/optimize.mbt` and `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` in the same change
2. reduced semantic coverage
   - created exact-type seed shapes
   - matching `if` and `try` carried-value positives
   - explicit loop no-propagation cases
   - local/global forwarding
   - call-operand and return retagging
3. neighborhood honesty
   - keep the split explicit from `ssa`, `type-refining`, `type-generalizing`, and `type-merging`
4. parity justification
   - document explicitly why the repo wants the pass even though it is outside the current no-DWARF parity route

That is more useful locally than a vague “compare with Binaryen later” note because it preserves the most important current reality: the algorithm is well-understood, but the repo has not yet chosen to own the pass.

## Bottom line

Current Starshine `type-ssa` strategy is honest non-adoption plus explicit neighboring context:

- [`src/passes/optimize.mbt#L127-L152`](../../../../../src/passes/optimize.mbt#L127-L152) shows that the current registry's boundary-only and removed name sets do **not** include `type-ssa`
- [`src/passes/optimize.mbt#L156-L259`](../../../../../src/passes/optimize.mbt#L156-L259) shows there is no active `type-ssa` entry either
- [`src/passes/optimize.mbt#L446-L461`](../../../../../src/passes/optimize.mbt#L446-L461) shows the current expansion logic only handles tracked names, which means `type-ssa` has no local compatibility path today
- [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L7-L68`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L7-L68) likewise omits the pass from active, removed, and boundary-only planning buckets
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) omits it from the active canonical parity route
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md) still has no dedicated slice for it
- the nearest concrete local neighbors are [`src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt), [`src/passes/global_refining.mbt`](../../../../../src/passes/global_refining.mbt), and [`src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt), but none of them implement `type-ssa`

So the right mental model today is:

- **upstream dossier complete enough to teach and port later**
- **no current Starshine implementation**
- **no current registry or backlog owner**
- **clear neighboring local code map for future adopters**
- **clear future correctness contract if the repo ever decides the pass is worth owning**
