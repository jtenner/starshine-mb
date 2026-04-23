---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md
  - ../../../raw/research/0276-2026-04-23-const-hoisting-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../precompute/index.md
  - ../optimize-added-constants/index.md
  - ../merge-similar-functions/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./size-model-and-boundaries.md
  - ./literal-bit-identity-zero-signs-and-nan-payloads.md
  - ./wat-shapes.md
  - ../precompute/index.md
  - ../optimize-added-constants/index.md
  - ../merge-similar-functions/index.md
---

# Starshine Strategy For `const-hoisting`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`](../../../raw/binaryen/2026-04-23-const-hoisting-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`const-hoisting` is still **unimplemented** in Starshine.
There is no `src/passes/const_hoisting.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is removed-registry tracking plus a compact port map:

- keep the upstream pass spelling tracked in the removed-name registry
- keep active pipeline requests honest by rejecting the removed pass name instead of pretending the transform already exists
- keep the planning surface honest by recording that the repo still has **no dedicated `const-hoisting` backlog slice** in `agent-todo.md`
- keep the neighboring size-pass dossier cluster explicit so a future port has a concrete landing zone

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code and doc map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - [`src/passes/optimize.mbt#L144-L150`](../../../../../src/passes/optimize.mbt#L144-L150)
    - `pass_registry_removed_names()` includes `"const-hoisting"`
- active request guard for removed passes
  - [`src/passes/optimize.mbt#L463-L465`](../../../../../src/passes/optimize.mbt#L463-L465)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is removed from the active hot pipeline registry`
- removed-until-implemented planning roster
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L42`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L42)
    - `const-hoisting` still appears in the Batch 1 removed-pass roster
- active backlog truth
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is still **no dedicated `const-hoisting` slice** today; that absence is a real planning fact, not a documentation omission
- neighboring living dossiers that define the future landing zone
  - [`../precompute/index.md`](../precompute/index.md)
  - [`../optimize-added-constants/index.md`](../optimize-added-constants/index.md)
  - [`../merge-similar-functions/index.md`](../merge-similar-functions/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `const-hoisting` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps the upstream spelling `const-hoisting` in `pass_registry_removed_names()`.
That means:

- the project still treats `const-hoisting` as a real known pass
- the name is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and batch-planning work instead of silently falling out of scope

That is the right current behavior for an unimplemented pass that still matters to parity-oriented documentation.

### 2. The active pipeline rejects the pass honestly

The same file's `run_hot_pipeline_expand_passes(...)` path returns a specific removed-pass error when a user requests `const-hoisting`.
That matters because it keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI and API surface do not imply the pass already exists locally
- the removed classification remains executable documentation rather than dead metadata

For this pass family, that is currently the most important in-repo behavior after name tracking.

### 3. The repo has preserved planning context, but not yet an active execution slice

`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still records `const-hoisting` among the removed-until-hot-implementation passes.
But `agent-todo.md` still has no dedicated `const-hoisting` section with deliverables and exit criteria.

That mismatch is worth keeping explicit.
It means the local story today is real preserved planning, but not yet active execution.

## The right future Starshine implementation shape

The current docs and the reviewed upstream contract strongly suggest that a future local `const-hoisting` port should be taught as a **small HOT literal-size pass**, not as a boundary/module transform.

Why:

- upstream Binaryen runs it per function and marks it function-parallel
- the pass only rewrites repeated `Const` nodes into one fresh local plus a prelude `local.set`
- correctness depends on exact byte-size accounting and stable ordering, not module-wide global facts
- the neighboring local dossiers already describe the main size-oriented ecosystem this pass belongs to

So the local strategy should be thought of as:

1. scan one function for repeated literal nodes
2. group candidates by exact literal identity, including float sign-bit and NaN-payload distinctions
3. compute the same byte-profitability rule that Binaryen uses today
4. keep `v128` unsupported unless the local port intentionally widens scope beyond reviewed `version_129`
5. emit one deterministic entry prelude plus fresh local for each profitable bucket
6. validate in isolated `--pass const-hoisting` mode against Binaryen before worrying about broader preset placement

That is a much tighter and safer future plan than the vague idea “deduplicate constants later.”

## The most important local dependency map

### `precompute` is the clearest local upstream-neighbor analogy

See [`../precompute/index.md`](../precompute/index.md).

Why it matters locally:

- `precompute` and `const-hoisting` are both size-relevant and both operate on literal-heavy opportunities
- but they solve different problems
- `precompute` materializes more literal `Const` nodes
- `const-hoisting` decides whether already-materialized repeated literals are cheaper as one `local.set` plus many `local.get`s

A future Starshine port should preserve that split instead of blurring the pass into generic constant folding.

### `optimize-added-constants` is a nearby size pass, not a substitute

See [`../optimize-added-constants/index.md`](../optimize-added-constants/index.md).

Why:

- that pass shortens the encoding of arithmetic expressions like repeated additions
- `const-hoisting` does not rewrite arithmetic structure at all
- it only acts after literal materialization, and only when repeated literal payloads themselves become expensive enough to hoist

So the relationship is “neighboring size pass with a different trigger,” not “same optimization under a different name.”

### `merge-similar-functions` is another literal-sharing neighbor, but at a different scope

See [`../merge-similar-functions/index.md`](../merge-similar-functions/index.md).

Why:

- `const-hoisting` is strictly intra-function
- `merge-similar-functions` is whole-function structural deduplication
- keeping that scope distinction explicit helps avoid over-designing a future local `const-hoisting` port into something larger than the reviewed upstream contract

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `const-hoisting`
- pass-specific literal-bucket collection code
- local byte-profitability helpers mirroring Binaryen's LEB-size accounting for this pass
- deterministic prelude emission logic for this pass
- pass-specific reduced tests or replay lanes
- a dedicated active backlog slice in `agent-todo.md`

So the current repo status is best summarized as:

- name tracked
- runtime rejection tracked
- planning bucket tracked
- active slice still missing
- transform itself not yet landed

## Validation plan for the eventual port

The current docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the reviewed upstream families
   - signed-LEB `i32` threshold positives and negatives
   - `i64` threshold positives and negatives
   - `f32` and `f64` threshold families
   - `+0.0` versus `-0.0` and distinct NaN-payload bucket splits
   - unsupported `v128` preservation
2. structural-output tests
   - deterministic fresh-local ordering
   - entry-prelude insertion shape
   - preservation of later original-body structure after the prelude block
3. oracle comparison
   - compare isolated `--pass const-hoisting` output against Binaryen rather than assuming any default preset slot
4. only then consider broader local scheduling questions
   - because the current repo does not yet treat `const-hoisting` as part of the active no-DWARF default parity queue

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the exact proof families the reviewed upstream test file already exposes.

## Bottom line

Current Starshine `const-hoisting` strategy is honest removed-registry tracking plus a compact port map:

- the upstream spelling is intentionally preserved in `src/passes/optimize.mbt`
- the active pipeline rejects the pass honestly rather than pretending it already exists
- the repo still keeps `const-hoisting` in the removed-until-implemented planning roster
- the active backlog still does **not** have a dedicated `const-hoisting` slice, and this page keeps that planning gap explicit
- the surrounding `precompute`, `optimize-added-constants`, and `merge-similar-functions` dossiers already define the practical implementation neighborhood for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear runtime honesty**
- **clear neighboring size-pass map**
- **clear warning that the active backlog still needs a real `const-hoisting` slice before implementation work begins**
