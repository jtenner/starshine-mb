---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
---

# Starshine Strategy For `local-subtyping`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the practical landing zone a future port would need.

## The honest current status

`local-subtyping` is still **unimplemented** in Starshine.
There is no `src/passes/local_subtyping.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is registry and scheduler planning:

- keep the pass spelling tracked in the registry surface
- keep the canonical no-DWARF slot documented
- keep the backlog slice focused on the real Binaryen scope instead of an imagined wider locals pass
- keep the neighboring local-cleanup dossiers aligned so a future implementation can land into an honest cluster

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - `src/passes/optimize.mbt`
    - `pass_registry_removed_names()` includes `"local-subtyping"`
- backlog and delivery plan
  - `agent-todo.md`
    - `#### LS - Local Subtyping`
    - `[LS]001 - Local Type Narrowing Core`
    - `[LS]002 - Ordering Tests and Artifact Proof`
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the GC/local cleanup slot where `local-subtyping` belongs after `optimize-casts` and before `coalesce-locals -> local-cse -> simplify-locals`
- neighboring living dossiers a future port must line up with
  - `docs/wiki/binaryen/passes/optimize-casts/index.md`
  - `docs/wiki/binaryen/passes/coalesce-locals/index.md`
  - `docs/wiki/binaryen/passes/local-cse/index.md`
  - `docs/wiki/binaryen/passes/reorder-locals/index.md`

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `local-subtyping` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `local-subtyping` in `pass_registry_removed_names()`.
That means:

- the project still treats `local-subtyping` as a real known pass
- the spelling is preserved in the registry compatibility surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning

That is the right current behavior for an unimplemented parity pass.

### 2. The work is planned, but the current backlog wording is broader than the reviewed upstream contract

`agent-todo.md` already gives `local-subtyping` a real backlog slice under `LS`.
That is good.

But the current wording still says a future port should:

- compute safe narrower local types from **uses and defs**
- preserve **multivalue and tuple-local behavior**

The reviewed Binaryen `version_129` source is narrower:

- it is definition-driven first, not a broad use-and-def collector
- it narrows only helper-supported reference locals here
- tuple locals are skipped through `TypeUpdating::canHandleAsLocal(...)`

The docs should keep that mismatch explicit instead of smoothing it over.
A future Starshine port can widen scope on purpose, but that should be a deliberate local design choice, not something silently attributed to upstream Binaryen.

### 3. The scheduler slot is already documented

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already places `local-subtyping` inside the GC/local cleanup cluster.
That matters because the pass is not supposed to be taught as a stand-alone locals improvement.

The upstream neighborhood is meaningful:

- `optimize-casts` can expose cleaner definition-side local types
- `local-subtyping` then narrows declarations and expression types to match those definitions
- `coalesce-locals` must come later because it freezes exact local types and can erase narrowing opportunities
- `local-cse` and `simplify-locals` then consume the cleaner local flow

That cluster story is part of the local strategy even before a MoonBit implementation exists.

## The right future Starshine implementation shape

The reviewed Binaryen source suggests that a future local `local-subtyping` port should be taught as a **function-wide local-declaration/type-retag pass**, not as a tiny HOT peephole.

Why:

- it changes local declarations, not just interior expression trees
- it retags `local.get` and `local.tee` expression types across a whole function
- it consults structured dominance for non-nullability safety
- it sits between other local-declaration-sensitive passes like `coalesce-locals` and `reorder-locals`

So the likely local landing shape is not “just another HOT region cleanup.”
It is more plausibly one of these:

- a module/boundary-aware locals pass
- or a hybrid pass that can reason over whole-function local metadata before writeback

The current repo does not implement that yet, so the important thing today is to keep the slot and neighboring dependencies honest.

## The most important local dependency map

### `optimize-casts` is the immediate left neighbor

See [`../optimize-casts/index.md`](../optimize-casts/index.md).

Why it matters locally:

- the upstream cluster expects `optimize-casts` to expose cleaner local definitions first
- `local-subtyping` is then allowed to tighten declarations to match those definitions
- a future Starshine port should therefore validate not only `--local-subtyping` in isolation, but also the real `optimize-casts -> local-subtyping` neighborhood

### `coalesce-locals` is the immediate right neighbor

See [`../coalesce-locals/index.md`](../coalesce-locals/index.md).

Why:

- Binaryen places `coalesce-locals` immediately after `local-subtyping`
- `coalesce-locals` requires exact type equality, so declaration narrowing needs to happen first
- the local scheduler story should preserve that same pressure instead of treating the two passes as interchangeable

### `local-cse` consumes the cleaner local traffic later

See [`../local-cse/index.md`](../local-cse/index.md).

Why:

- once declarations and local expression types are tightened, later local cleanup can reason over a smaller, cleaner local-value space
- that is one reason the cluster keeps `local-subtyping` ahead of `local-cse`

### `reorder-locals` stays a useful comparison point

See [`../reorder-locals/index.md`](../reorder-locals/index.md).

Why:

- both passes touch whole-function local metadata rather than only interior HOT regions
- the current Starshine `reorder-locals` dossier already explains why some locals work remains module-scoped in this repo
- future local-subtyping work should reuse that lesson instead of pretending declaration/type rewrites are pure interior-tree edits

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `local-subtyping`
- a scheduler entry that actually executes the pass
- pass-specific declaration-retag logic for locals and `local.get` / `local.tee`
- pass-specific dominance checks for non-nullability tightening
- pass-specific tests or CLI execution coverage beyond the tracked registry and backlog surfaces

So the current repo status is best summarized as:

- name tracked
- backlog tracked
- scheduler slot documented
- neighboring locals passes documented
- transform itself not yet landed

## Validation plan for the eventual port

The existing backlog plus the corrected upstream story imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the real upstream families
   - set-driven declaration narrowing
   - sibling-set common-parent LUBs
   - `local.tee` expression-type retagging
   - non-nullability tightening only when dominance proves it safe
2. negative correctness tests
   - params remain unchanged
   - tuple locals remain unchanged until helper support changes
   - gets alone do not narrow declarations
   - `ref.as_non_null`-only stories stay out of scope unless Starshine deliberately widens beyond upstream
3. cluster interaction tests
   - `optimize-casts -> local-subtyping`
   - `local-subtyping -> coalesce-locals`
   - `coalesce-locals -> local-cse`
4. artifact and oracle comparison
   - the `LS` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it keeps the corrected pass scope explicit.

## Bottom line

Current Starshine `local-subtyping` strategy is honest registry and scheduler planning:

- the pass name is intentionally preserved in `src/passes/optimize.mbt`
- the backlog already treats it as a real parity slice under `LS`
- the canonical slot is already documented in the no-DWARF optimizer notes
- the surrounding `optimize-casts`, `coalesce-locals`, `local-cse`, and `reorder-locals` dossiers already define the practical landing zone for a future port
- the docs now keep one important contradiction explicit: the reviewed Binaryen oracle is smaller than the current backlog wording

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear slot in the local-cleanup cluster**
- **clear neighboring implementation map for the eventual port**
- **clear warning not to silently broaden the reviewed upstream contract**
