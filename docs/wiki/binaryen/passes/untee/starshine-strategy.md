---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-untee-primary-sources.md
  - ../../../raw/research/0279-2026-04-23-untee-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../agent-todo.md
  - ../code-pushing/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flattening-code-pushing-and-tee-boundaries.md
  - ./wat-shapes.md
  - ../code-pushing/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
---

# Starshine strategy for `untee`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-untee-primary-sources.md`](../../../raw/binaryen/2026-04-23-untee-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`untee` is still **unimplemented** in Starshine.
There is no `src/passes/untee.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is removed-registry tracking plus a compact port map:

- keep the upstream pass spelling tracked in the removed-name registry
- keep active pipeline requests honest by rejecting the removed pass name instead of pretending the transform already exists
- keep the planning surface honest by recording that the repo still has **no dedicated `untee` backlog slice** in `agent-todo.md`
- keep the split from the current `simplify-locals` / `simplify-locals-notee` family explicit so future work does not quietly blur tee desugaring into a broader locals optimizer

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code and doc map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - [`src/passes/optimize.mbt#L144-L151`](../../../../../src/passes/optimize.mbt#L144-L151)
    - `pass_registry_removed_names()` includes `"untee"`
- active request guard for removed passes
  - [`src/passes/optimize.mbt#L446-L465`](../../../../../src/passes/optimize.mbt#L446-L465)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is removed from the active hot pipeline registry`
- removed-until-implemented planning roster
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L42`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L42)
    - `untee` still appears in the Batch 1 removed-pass roster
- active backlog truth
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is still **no dedicated `untee` slice** today; that absence is a real planning fact, not a documentation omission
- nearest active local implementation neighborhood
  - [`src/passes/simplify_locals.mbt#L1-L15`](../../../../../src/passes/simplify_locals.mbt#L1-L15)
    - the repo's main locals-rewrite pass still lives here
  - [`src/passes/pass_manager_wbtest.mbt#L291-L307`](../../../../../src/passes/pass_manager_wbtest.mbt#L291-L307)
    - the current locals-family proof surface still explicitly exercises adjacent-tee rewrite behavior rather than a tee-elimination pass
- neighboring living dossiers that define the future landing zone
  - [`../code-pushing/index.md`](../code-pushing/index.md)
  - [`../simplify-locals/index.md`](../simplify-locals/index.md)
  - [`../simplify-locals-notee/index.md`](../simplify-locals-notee/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `untee` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps the upstream spelling `untee` in `pass_registry_removed_names()`.
That means:

- the project still treats `untee` as a real known pass
- the name is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and batch-planning work instead of silently falling out of scope

That is the right current behavior for an unimplemented pass that still matters to parity-oriented documentation.

### 2. The active pipeline rejects the pass honestly

The same file's `run_hot_pipeline_expand_passes(...)` path returns a specific removed-pass error when a user requests `untee`.
That matters because it keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI and API surface do not imply the pass already exists locally
- the removed classification remains executable documentation rather than dead metadata

For this pass family, that is currently the most important in-repo behavior after name tracking.

### 3. The repo preserves planning context, but not yet an active execution slice

`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still records `untee` among the removed-until-hot-implementation passes.
But `agent-todo.md` still has no dedicated `untee` section with deliverables and exit criteria.

That mismatch is worth keeping explicit.
It means the local story today is real preserved planning, but not yet active execution.

## The most important current local boundary: `untee` is not today's `simplify-locals`

The most useful local clarification from this follow-up is not just “there is no `untee` file.”
It is that the current neighboring locals machinery is still solving a different problem.

### `simplify-locals` is the nearest active implementation neighbor

See [`src/passes/simplify_locals.mbt#L1-L15`](../../../../../src/passes/simplify_locals.mbt#L1-L15) and [`../simplify-locals/index.md`](../simplify-locals/index.md).

Why it matters locally:

- this is the repo's main active locals-rewrite owner file
- a future explicit `untee` port would likely need to live beside it or at least compose with it
- but the reviewed upstream contract is much smaller than the current local `simplify-locals` family

So the right local lesson is “nearby landing zone,” not “already the same pass in disguise.”

### The current proof surface still reasons about tee-adjacent rewrites from the optimization side

See [`src/passes/pass_manager_wbtest.mbt#L291-L307`](../../../../../src/passes/pass_manager_wbtest.mbt#L291-L307).

That test surface matters because it shows current Starshine locals work still has tee-aware rewrite behavior in the active optimizer.
Inference from the local code and neighboring dossiers:

- the repo is still comfortable creating or preserving tee-shaped intermediates when broader locals rewrites want them
- that is the opposite direction from upstream `untee`, whose whole job is to desugar tees away

So a future `untee` port should remain a separate explicit pass, not a quiet reinterpretation of the existing locals pass.

### `simplify-locals-notee` is the closest conceptual sibling, not a synonym

See [`../simplify-locals-notee/index.md`](../simplify-locals-notee/index.md).

This matters locally for the same reason it matters upstream:

- `untee` removes existing tees
- `simplify-locals-notee` is a broader locals optimizer that merely refuses transformations requiring **new** tees

Keeping that distinction explicit in the local wiki is part of the current Starshine strategy, because the repo already tracks both names and future readers will otherwise blur them together.

## The right future Starshine implementation shape

The current docs and the reviewed upstream contract strongly suggest that a future local `untee` port should be taught as a **small explicit HOT/tree rewrite pass**, not as a boundary/module transform and not as a hidden `simplify-locals` mode.

Why:

- upstream Binaryen runs it per function and marks it function-parallel
- the pass only rewrites one exact node family: `local.tee`
- correctness depends on preserving declared local types and the unreachable fast path, not on module-wide global facts
- the neighboring local dossiers already define the two most important interaction boundaries: `code-pushing` and `simplify-locals-notee`

So the local strategy should be thought of as:

1. recognize real tee nodes only
2. preserve ordinary `local.set` untouched
3. delete tee wrappers outright when the tee value is already unreachable
4. otherwise rewrite tees into explicit set-plus-get form
5. keep the declared-local-type lookup explicit for the synthetic get
6. validate in isolated `--pass untee` mode against Binaryen before worrying about broader scheduling

That is a much tighter and safer future plan than the vague idea “handle tees somewhere in locals cleanup.”

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `untee`
- a pass-specific tee-desugaring owner in `src/passes/`
- reduced tests dedicated to an `untee` pass name
- a preset or canonical no-DWARF scheduling slot for `untee`
- a dedicated active backlog slice in `agent-todo.md`

So the current repo status is best summarized as:

- name tracked
- runtime rejection tracked
- planning bucket tracked
- neighboring locals code mapped
- transform itself not yet landed

## Validation plan for the eventual port

The current docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the reviewed upstream families
   - dropped tee
   - non-integer type preservation
   - tee-feeding-set shape
   - nested inside-out expansion
   - unreachable tee deletion
2. structural-output tests
   - declared-local-type reuse for the synthetic get
   - ordinary `local.set` preservation
   - no accidental broad locals cleanup beyond tee desugaring
3. oracle comparison
   - compare isolated `--pass untee` output against Binaryen rather than assuming any default preset slot
4. only then consider broader scheduling questions
   - because the current repo does not yet treat `untee` as part of the active no-DWARF default parity queue

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the exact proof families the reviewed upstream test file already exposes.

## Bottom line

Current Starshine `untee` strategy is honest removed-registry tracking plus a compact port map:

- the upstream spelling is intentionally preserved in `src/passes/optimize.mbt`
- the active pipeline rejects the pass honestly rather than pretending it already exists
- the repo still keeps `untee` in the removed-until-implemented planning roster
- the active backlog still does **not** have a dedicated `untee` slice, and this page keeps that planning gap explicit
- the surrounding `simplify-locals`, `simplify-locals-notee`, and `code-pushing` dossiers already define the practical conceptual neighborhood for a future port
- the nearest active local proof surface still reasons about tee-adjacent rewrites from the optimization side, which is exactly why a future `untee` port should remain a separate explicit pass

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear runtime honesty**
- **clear neighboring locals/code-pushing map**
- **clear warning that the active backlog still needs a real `untee` slice before implementation work begins**
