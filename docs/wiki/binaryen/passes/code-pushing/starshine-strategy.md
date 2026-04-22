---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
  - ../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../precompute/index.md
  - ../tuple-optimization/index.md
  - ../simplify-locals-nostructure/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ../precompute/index.md
  - ../tuple-optimization/index.md
  - ../simplify-locals-nostructure/index.md
---

# Starshine Strategy For `code-pushing`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`code-pushing` is still **unimplemented** in Starshine.
There is no `src/passes/code_pushing.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is registry and slot planning:

- keep the pass spelling tracked in the registry surface
- keep the canonical no-DWARF slot documented
- keep the tuple-opt exact-slot gate honest until `code-pushing` and `simplify-locals-nostructure` are both real active neighbors
- keep the backlog slice focused on motion safety and rewrite validation
- teach the surrounding implemented and near-neighbor dossiers a future port would need to compose with

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - `src/passes/optimize.mbt`
    - `pass_registry_removed_names()` includes `"code-pushing"`
- exact-slot gate for the already-implemented tuple pass
  - `src/passes/optimize.mbt`
    - `tuple_optimization_exact_slot_prereqs_ready()` requires both `code-pushing` and `simplify-locals-no-structure` to be active hot passes before tuple-opt can claim its Binaryen slot in public presets
- regression proof that the gate is still intentionally closed
  - `src/passes/optimize_test.mbt`
    - `tuple-optimization exact preset slot remains unavailable while its neighbors are removed`
- backlog and delivery plan
  - `agent-todo.md`
    - `CP` slice under the Binaryen no-DWARF default optimize pathway parity section
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the early slot where `code-pushing` belongs between `precompute` and `tuple-optimization`
- neighboring living dossiers a future port must line up with
  - `docs/wiki/binaryen/passes/precompute/index.md`
  - `docs/wiki/binaryen/passes/tuple-optimization/index.md`
  - `docs/wiki/binaryen/passes/simplify-locals-nostructure/index.md`

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `code-pushing` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `code-pushing` in `pass_registry_removed_names()`.
That means:

- the project still treats `code-pushing` as a real known pass
- the spelling is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning

That is the right current behavior for an unimplemented parity pass.

### 2. The tuple-opt preset gate intentionally depends on this pass still being missing

The strongest local implementation-facing clue lives in `tuple_optimization_exact_slot_prereqs_ready()`.
That function explicitly checks whether:

- `code-pushing`
- `simplify-locals-no-structure`

have both graduated to `HotPass` registry entries.

Because `code-pushing` is still removed today, the function stays false, and `optimize_preset_passes()` / `shrink_preset_passes()` deliberately keep tuple-opt out of the public presets.

That means `code-pushing` is already part of an active local strategy story even without an implementation file:
Starshine uses its absence to keep a neighboring implemented pass from claiming an inexact Binaryen slot.

### 3. The current tests preserve that honesty boundary

`src/passes/optimize_test.mbt` locks the gate behavior in place with a regression asserting tuple-opt remains unavailable while its exact neighboring slots are still removed.

That matters because a future `code-pushing` port is not just “one more pass.”
Landing it changes when Starshine can truthfully expose the tuple-opt neighborhood in public presets.

### 4. The work is planned as a parity slice, not an orphan idea

`agent-todo.md` already gives `code-pushing` a real backlog slice under `CP`.
The current deliverables are framed around the right upstream concerns:

- motion safety rules
- trap and side-effect boundaries
- rewrite coverage on branchy fixtures
- artifact validation against Binaryen

That backlog framing already matches the upstream dossier better than a vague “sink pure code” summary would.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `code-pushing` port should be taught as an **early-cluster HOT rewrite family**, not as an isolated generic optimizer.

Why:

- Binaryen runs it after `precompute`
- it is immediately followed by `tuple-optimization`
- the next intended neighbor is `simplify-locals-nostructure`
- Starshine already has explicit `precompute` and `tuple-optimization` dossiers explaining what those neighbors expect from the surrounding shape

So the local strategy should be thought of as:

1. identify a HOT-level representation of Binaryen's two upstream motion families
   - generic structured-segment sinking
   - stricter direct-`if` sinking
2. prove the same movement-safety boundaries locally
   - contiguous-suffix reasoning
   - effect and trap barriers
   - one-arm-unreachable versus two-arm-reachable split
3. keep the scheduler story honest
   - land the real pass before claiming tuple-opt's exact public preset slot
4. preserve the handoff to later local cleanup neighbors
   - especially the still-missing `simplify-locals-nostructure` slot

In other words, the future port should slot into a local early optimization ecosystem that is already documented.

## The most important local dependency map

### Upstream `code-pushing` is the missing left neighbor of local `tuple-optimization`

See [`../tuple-optimization/index.md`](../tuple-optimization/index.md).

Why it matters locally:

- Starshine already implements tuple optimization as an explicit hot pass
- the tuple dossier repeatedly says its exact Binaryen preset slot is blocked until `code-pushing` and `simplify-locals-nostructure` exist in-tree
- a future `code-pushing` port therefore unlocks truthful preset placement work, not just one isolated explicit pass flag

### Upstream `code-pushing` is also downstream of local `precompute`

See [`../precompute/index.md`](../precompute/index.md).

Why:

- Binaryen expects `code-pushing` to see a body already simplified by precompute-level folding
- Starshine already has the explicit upstream-aligned `precompute` surface
- a future local port should therefore validate not only `--code-pushing` in isolation, but also the real `precompute -> code-pushing` neighborhood

### The right immediate consumer after it is still the missing `simplify-locals-nostructure` slot

See [`../simplify-locals-nostructure/index.md`](../simplify-locals-nostructure/index.md).

Why:

- Binaryen uses `code-pushing` to make branch-local work more local before the early no-structure locals cleanup runs
- Starshine still tracks that right neighbor as removed, under the local spelling `simplify-locals-no-structure`
- a future `code-pushing` port should therefore keep its interaction with that later locals cleanup explicit instead of trying to absorb all downstream cleanup itself

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a `code-pushing` MoonBit implementation file
- HOT-region candidate collection for contiguous movable suffixes
- local effect and use tracking specifically for this pass
- a direct-`if` rewrite engine that matches Binaryen's one-arm versus two-arm split for this pass
- pass-specific reduced tests or CLI execution coverage beyond the tracked removed-name and slot-gating surfaces

So the current repo status is best summarized as:

- name tracked
- tuple-slot dependency tracked
- backlog tracked
- scheduler slot documented
- transform itself not yet landed

## Validation plan for the eventual port

The existing backlog plus neighboring pass docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the two upstream families
   - generic structured-segment suffix sinks
   - direct `if` sinks
   - one-arm-unreachable special cases
2. negative movement-safety tests
   - side effects, calls, throws, memory, table, and mutable-global barriers
   - default trap-sensitive bailouts
   - value-still-used-after-separator bailouts
   - EH-sensitive bailout families
3. scheduler-neighborhood interaction tests
   - `precompute -> code-pushing`
   - `code-pushing -> tuple-optimization`
   - later `code-pushing -> simplify-locals-nostructure` once that pass exists locally
4. artifact and oracle comparison
   - the `CP` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow.

## Bottom line

Current Starshine `code-pushing` strategy is honest registry and slot planning:

- the pass name is intentionally preserved in `src/passes/optimize.mbt`
- tuple-opt's exact-slot gate intentionally depends on `code-pushing` still being absent, which keeps public presets honest
- `src/passes/optimize_test.mbt` locks that boundary in place
- the backlog already treats it as a real early-parity slice under `CP`
- the canonical slot is already documented in the no-DWARF optimizer notes
- the surrounding `precompute`, `tuple-optimization`, and `simplify-locals-nostructure` dossiers already define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear pipeline dependency story**
- **clear neighboring implementation map for the eventual port**
