---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md
  - ../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md
  - ../../../raw/research/0278-2026-04-23-dataflow-optimization-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../docs/0065-2026-03-24-ir2-execution-plan.md
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../agent-todo.md
  - ../flatten/index.md
  - ../simplify-locals-nonesting/index.md
  - ../souperify/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-dataflow-ir-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../flatten/index.md
  - ../simplify-locals-nonesting/index.md
  - ../souperify/index.md
---

# Starshine Strategy For `dataflow-optimization`

Use this page together with the raw primary-source manifests in [`../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md), [`../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md), and [`../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and planning surfaces that already answer whether the pass exists, and the nearest concrete files a future port would need to study. For first-slice sequencing and validation gates, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## The honest current status

`dataflow-optimization` is still **unimplemented** in Starshine.
There is no `src/passes/dataflow_optimization.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is removed-registry tracking plus a cautious port map:

- keep the local compatibility spelling `dataflow-optimization` tracked in the removed-name registry
- reject explicit requests for the pass honestly instead of silently no-oping
- keep the older batch map honest by preserving the pass in the removed-until-implemented roster
- keep the current execution-plan uncertainty explicit: the newer preferred-order note does not currently call `dfo` out as an immediate next implementation target
- keep the neighboring flat-pipeline and constant-folding dossiers explicit so a future port has a concrete landing zone

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code and doc map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - [`src/passes/optimize.mbt#L143-L153`](../../../../../src/passes/optimize.mbt#L143-L153)
    - `pass_registry_removed_names()` includes `"dataflow-optimization"`
- active request guard for removed passes
  - [`src/passes/optimize.mbt#L485-L491`](../../../../../src/passes/optimize.mbt#L485-L491)
    - `run_hot_pipeline_expand_passes(...)` resolves known names and rejects removed ones with `pass flag {name} is removed from the active hot pipeline registry`
- active registry entries by omission
  - [`src/passes/optimize.mbt#L155-L279`](../../../../../src/passes/optimize.mbt#L155-L279)
    - `pass_registry_entries()` creates the active hot/module/preset registry entries, and there is no `dataflow-optimization` implementation entry there
- removed-until-implemented planning roster
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L42`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L42)
    - `dataflow-optimization` still appears in the Batch 1 removed-pass roster
- newer preferred migration order
  - [`docs/0065-2026-03-24-ir2-execution-plan.md#L37-L40`](../../../../../docs/0065-2026-03-24-ir2-execution-plan.md#L37-L40)
    - the current “preferred implementation order from the current state” names Batch 2 control/cleanup work and Batch 3 dataflow-sensitive work, but does **not** call out `dataflow-optimization`
- backlog truth
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is still **no dedicated `dataflow-optimization` / `dfo` slice** today
- nearest active local implementation neighbors
  - [`src/passes/precompute.mbt#L2-L15`](../../../../../src/passes/precompute.mbt#L2-L15)
  - [`src/passes/precompute.mbt#L1095-L1097`](../../../../../src/passes/precompute.mbt#L1095-L1097)
  - [`src/passes/simplify_locals.mbt#L2-L15`](../../../../../src/passes/simplify_locals.mbt#L2-L15)
  - [`src/passes/simplify_locals.mbt#L4348-L4350`](../../../../../src/passes/simplify_locals.mbt#L4348-L4350)
- nearest conceptual dossier neighbors
  - [`../flatten/index.md`](../flatten/index.md)
  - [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md)
  - [`../souperify/index.md`](../souperify/index.md)

That code-and-doc map is the practical value this page adds: readers can now jump directly from the upstream algorithm to the exact local non-adoption status, the planning surfaces that still mention it, and the nearest concrete implementation files.

## What Starshine currently does for this pass name

Today Starshine's behavior for `dataflow-optimization` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps the local spelling `dataflow-optimization` in `pass_registry_removed_names()`.
That means:

- the project still treats the pass as a real known optimizer name
- the name is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and batch-planning work instead of silently falling out of scope

That is the right current behavior for an unimplemented pass that still matters to parity-oriented documentation.

### 2. The active pipeline rejects the pass honestly

The same file's `run_hot_pipeline_expand_passes(...)` path returns a specific removed-pass error when a user requests `dataflow-optimization`.
That keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI/API surface does not imply the pass already exists locally
- the removed classification remains executable documentation instead of dead metadata

For this pass family, that is currently the most important in-repo behavior after name tracking.

### 3. The repo preserves planning context, but without an active owner

The older batch map in `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still records `dataflow-optimization` in the Batch 1 removed roster.
But the current preferred execution-order note in `docs/0065-2026-03-24-ir2-execution-plan.md` does not call it out among the next implementation steps, and `agent-todo.md` still has no dedicated slice.

That is a real planning state, not just a documentation accident.
The durable current answer is:

- registry status is preserved
- older batch intent is preserved
- near-term execution priority is not currently explicit
- backlog ownership is still absent

This page keeps that uncertainty explicit instead of smoothing it over.

## The most useful current local neighborhood

Even though the pass is unimplemented, the repo already has nearby code and dossier surfaces that define the practical local neighborhood a future port would have to preserve.

### `precompute` is the closest active local analogue for the actual folding step

See:

- [`src/passes/precompute.mbt#L2-L15`](../../../../../src/passes/precompute.mbt#L2-L15)
- [`src/passes/precompute.mbt#L1095-L1097`](../../../../../src/passes/precompute.mbt#L1095-L1097)
- [`../flatten/index.md`](../flatten/index.md)

Why it matters locally:

- upstream `dfo` delegates real constant evaluation to nested `precompute`
- Starshine already has an active `precompute` hot pass with an explicit descriptor and run entrypoint
- that means the best current local bridge for the folding half of the upstream algorithm is the existing constant-evaluation machinery, not a hypothetical future `dfo` file

### `simplify-locals` is the closest active local locals-cleanup family

See:

- [`src/passes/simplify_locals.mbt#L2-L15`](../../../../../src/passes/simplify_locals.mbt#L2-L15)
- [`src/passes/simplify_locals.mbt#L4348-L4350`](../../../../../src/passes/simplify_locals.mbt#L4348-L4350)
- [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md)

Why it matters locally:

- the upstream combo pipeline is `flatten -> simplify-locals-nonesting -> dfo -> ordinary cleanup`
- Starshine already has a strong HOT-native locals-cleanup pass family
- but that family is not a flat DataFlow side-graph pass

So the local relationship is “nearest cleanup neighbor,” not “hidden implementation of `dfo`.”

### `flatten` and `souperify` define the conceptual boundary, even though neither gives Starshine a local `dfo` substrate today

See:

- [`../flatten/index.md`](../flatten/index.md)
- [`../souperify/index.md`](../souperify/index.md)

Why it matters locally:

- upstream `dfo` is defined over Flat IR and Binaryen's DataFlow graph
- the neighboring dossiers already explain those concepts precisely
- but the current Starshine tree does **not** contain a local `src/dataflow/` or `src/ir/flat*` substrate to port the pass into directly

That last sentence is an inference from the repo layout rechecked on 2026-04-25: there is no current `src/passes/dataflow_optimization.mbt`, `src/dataflow/`, or `src/ir/flat*` file path in the workspace.
So a future implementation would need either a new local substrate or a consciously different HOT-native strategy.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `dataflow-optimization`
- a local Flat IR layer matching Binaryen's `flat.h`
- a local DataFlow side graph matching Binaryen's `src/dataflow/*`
- pass-specific reduced tests or replay lanes
- a dedicated active backlog slice in `agent-todo.md`
- a current execution-plan note that treats `dfo` as a named immediate next migration target

So the current repo status is best summarized as:

- name tracked
- runtime rejection tracked
- older batch context tracked
- near-term owner still missing
- transform itself not yet landed

## What a future port would need to preserve if Starshine adopts it

Even without a local owner today, the future correctness contract is already clear from the Binaryen dossier.
A faithful Starshine port would need to preserve all of these source-backed properties:

- hard flat-input gating
- integer-local relevance filtering
- the side-IR node model and unsupported-value degradation rules
- the deliberate loop-precision cutoff
- identical-constant-phi collapse
- nested-`precompute`-driven constant expression folding
- expectation of later ordinary cleanup after the flatten-era pass

For the full source-backed explanation of those invariants, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./flat-ir-dataflow-ir-and-boundaries.md`](./flat-ir-dataflow-ir-and-boundaries.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Validation plan for any eventual port

Because the pass has no local owner today, a real adoption change would need a wider validation story than ordinary pass-local testing.
A future implementation should validate in roughly this order:

1. registry honesty
   - decide whether the pass first lands as a still-removed tracked name with extra scaffolding or as a real active hot pass
   - update `src/passes/optimize.mbt`, `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`, and `docs/0065-2026-03-24-ir2-execution-plan.md` in the same change
2. reduced semantic coverage
   - same-constant branch merges
   - all-constant supported arithmetic and `select` positives
   - loop-precision-cutoff preservation
   - unsupported-op and EH bailouts
3. neighborhood honesty
   - keep the split explicit from `flatten`, `simplify-locals-nonesting`, `precompute`, and `souperify`
4. parity justification
   - document explicitly whether the goal is a faithful flat-side-graph port, a HOT-native approximation, or a more limited local subset

That is more useful locally than a vague “compare with Binaryen later” note because it preserves the most important current reality: the algorithm is well-understood, but the repo has not yet chosen a local substrate or owner for it.

## Bottom line

Current Starshine `dataflow-optimization` strategy is honest removed-registry tracking plus an explicit planning bridge:

- [`src/passes/optimize.mbt#L143-L153`](../../../../../src/passes/optimize.mbt#L143-L153) keeps the pass name alive in the removed registry
- [`src/passes/optimize.mbt#L485-L491`](../../../../../src/passes/optimize.mbt#L485-L491) rejects active requests for that removed name honestly
- [`src/passes/optimize.mbt#L155-L279`](../../../../../src/passes/optimize.mbt#L155-L279) shows there is still no active implementation entry
- [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L42`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L42) preserves the older Batch 1 removed-planning intent
- [`docs/0065-2026-03-24-ir2-execution-plan.md#L37-L40`](../../../../../docs/0065-2026-03-24-ir2-execution-plan.md#L37-L40) does not currently give it near-term preferred-order status
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md) still has no dedicated slice for it
- the nearest active implementation neighbors are [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt) and [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt), while the nearest conceptual dossier neighbors are [`../flatten/index.md`](../flatten/index.md), [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md), and [`../souperify/index.md`](../souperify/index.md)

So the right mental model today is:

- **upstream dossier complete enough to teach and port later**
- **no current Starshine implementation or local flat/DataFlow substrate**
- **name preserved and honestly rejected**
- **planning context preserved but still ownerless**
- **clear neighboring code and dossier map for future adopters**
