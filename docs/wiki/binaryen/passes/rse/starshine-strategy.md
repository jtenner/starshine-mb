---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-rse-primary-sources.md
  - ../../../raw/research/0259-2026-04-22-rse-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
  - ../heap-store-optimization/index.md
  - ../merge-blocks/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
  - ../heap-store-optimization/index.md
  - ../merge-blocks/index.md
---

# Starshine Strategy For `rse`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-rse-primary-sources.md`](../../../raw/binaryen/2026-04-22-rse-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`rse` is still **unimplemented** in Starshine.
There is no `src/passes/rse.mbt` or `src/passes/redundant_set_elimination.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is boundary and port planning:

- keep the upstream pass spelling tracked in the registry surface
- keep the pass in the canonical no-DWARF parity and backlog documents
- teach the surrounding late-cluster Starshine passes a future port would need to compose with
- keep the Binaryen-vs-backlog scope mismatch explicit instead of silently broadening the planned work

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - `src/passes/optimize.mbt`
    - `pass_registry_removed_names()` includes `"redundant-set-elimination"`
- backlog and delivery plan
  - `agent-todo.md`
    - `#### RSE - Redundant Set Elimination`
    - `[RSE]001 - Redundant Write Detection`
    - `[RSE]002 - Final-Cleanup Regression and Artifact Proof`
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the late-cluster slot where `rse` belongs after `merge-blocks` and before the final `vacuum`
- surrounding implemented Starshine cleanup consumers and feeders
  - `docs/wiki/binaryen/passes/simplify-locals/index.md`
  - `docs/wiki/binaryen/passes/heap-store-optimization/index.md`
  - `docs/wiki/binaryen/passes/merge-blocks/index.md`
  - `docs/wiki/binaryen/passes/vacuum/index.md`

That code-and-doc map is the main practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and the future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `rse` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps the upstream spelling `redundant-set-elimination` in `pass_registry_removed_names()`.
That means:

- the project still treats `rse` as a real known pass
- the name is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning

That is the right current behavior for an unimplemented parity pass.

### 2. The work is planned as a parity slice, not an orphan idea

`agent-todo.md` already gives `rse` a real backlog slice under `RSE`.
The current deliverables point in the right general direction:

- late-pipeline write elimination after other cleanup passes
- explicit side-effect and trap preservation
- artifact-level proof before the final `vacuum`

But one important mismatch needs to stay explicit.
The current backlog wording still says a future port should cover locals, globals, and GC field writes “where applicable”.
The reviewed Binaryen `version_129` source does **not** support that broad reading.

Current source-backed teaching should stay:

- `rse` is a **locals-only** pass in the reviewed upstream oracle
- future Starshine work should preserve that scope unless a newer upstream source or a deliberate local design doc widens it on purpose

The docs should not smooth that contradiction away.

### 3. The scheduler slot is already documented

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already places `rse` in the late cleanup cluster.
That matters because this pass is not meant to run in isolation.
Upstream Binaryen expects other passes to expose the right shapes first, and then expects the final `vacuum` to clean up what `rse` leaves behind.

That scheduler story is part of the local strategy even before a MoonBit implementation exists.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `rse` port should be taught as a **very late HOT local-value rewrite family**, not as an isolated generic optimizer.

Why:

- Binaryen runs it extremely late
- the upstream pass is explicitly locals-only
- earlier cleanup passes such as `simplify-locals` and `heap-store-optimization` expose copied-local and same-value traffic that `rse` can exploit
- later structural cleanup such as `merge-blocks` can simplify the control shapes that feed `rse`
- the final `vacuum` is expected to consume the debris `rse` leaves behind

So the local strategy should be thought of as:

1. identify a HOT-level representation of the real upstream families
   - same-value `local.set` / `local.tee` elimination
   - dead overwritten local writes
   - same-block `local.get` replacement that unlocks dead-set removal
2. preserve the same conservative boundaries locally
   - locals-only scope
   - exact-vs-merged predecessor reasoning
   - non-linear barrier invalidation
   - explicit loop conservatism unless a stronger proof exists
3. rely on neighboring late-cluster passes to expose and clean up the right shapes
   - `simplify-locals`
   - `heap-store-optimization`
   - `merge-blocks`
   - final `vacuum`

In other words, the future port should slot into a local cleanup ecosystem that already exists.

## The most important local dependency map

### Upstream `rse` depends on local-value cleanup already having happened

See [`../simplify-locals/index.md`](../simplify-locals/index.md).

Why it matters locally:

- Binaryen runs `simplify-locals` before `rse`
- copied-local cleanup and direct local simplification make late redundant-set reasoning easier and cheaper

So a future Starshine `rse` port should be planned as a downstream consumer of those simpler local-value shapes, not as a substitute for them.

### It also sits after local heap-store cleanup

See [`../heap-store-optimization/index.md`](../heap-store-optimization/index.md).

Why:

- the late no-DWARF cluster already expects local and store-side simplification to happen before the final local-value cleanup tail
- even though Binaryen `rse` is locals-only, earlier store-related cleanup can still expose simpler local traffic around constructor/setup code

A future local implementation should keep that relationship explicit.

### Late structural cleanup still matters

See [`../merge-blocks/index.md`](../merge-blocks/index.md).

Why:

- Binaryen schedules `rse` after `code-folding -> merge-blocks`
- the simplified control shapes from `merge-blocks` are part of the practical landing zone for any local-value reasoning that wants to stay conservative around control flow

So a future local implementation should treat `merge-blocks` as part of the setup, not just an unrelated neighboring pass.

### Final `vacuum` is part of the payoff story

See [`../vacuum/index.md`](../vacuum/index.md).

Why:

- upstream `rse` can turn redundant writes into `drop(value)` or direct value expressions
- `vacuum` is then expected to remove the leftover structural debris

That means a future Starshine port should preserve the final `rse -> vacuum` handoff instead of trying to do every tiny cleanup itself.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `rse`
- HOT or raw candidate collection for redundant local sets
- local-get replacement machinery specifically for this pass
- a local-value merge lattice for exact-vs-merged predecessor state in this pass
- pass-specific tests or CLI execution coverage beyond the tracked registry and backlog surfaces

So the current repo status is best summarized as:

- name tracked
- backlog tracked
- scheduler slot documented
- neighboring cleanup passes implemented
- transform itself not yet landed

## Validation plan for the eventual port

The existing backlog plus neighboring pass docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the real upstream families
   - same-value `local.set`
   - redundant `local.tee`
   - overwritten local writes
   - same-block read-rewrite families
2. negative correctness tests
   - merged predecessor disagreement
   - non-linear barrier invalidation
   - loop-conservative bailout cases
   - GC refined-expression type-mismatch negatives
3. late-cluster interaction tests
   - `simplify-locals -> rse`
   - `heap-store-optimization -> rse`
   - `merge-blocks -> rse -> vacuum`
4. artifact and oracle comparison
   - the `RSE` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and keeps the locals-only scope explicit.

## Bottom line

Current Starshine `rse` strategy is honest boundary tracking plus port planning:

- the upstream spelling is intentionally preserved in `src/passes/optimize.mbt`
- the backlog already treats `rse` as a real late-parity slice under `RSE`
- the canonical slot is already documented in the no-DWARF optimizer notes
- the surrounding implemented cleanup passes already exist and define the practical landing zone for a future port
- the docs now keep one important contradiction explicit: the current Binaryen oracle is locals-only even though the backlog wording is still broader

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear slot in the pipeline**
- **clear neighboring implementation map for the eventual port**
- **clear warning not to silently broaden the reviewed upstream contract**
