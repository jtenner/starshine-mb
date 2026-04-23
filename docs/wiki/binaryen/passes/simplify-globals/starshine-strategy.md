---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md
  - ../../../raw/research/0275-2026-04-23-simplify-globals-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../simplify-globals-optimizing/index.md
  - ../propagate-globals-globally/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./plain-vs-optimizing-and-safety.md
  - ./wat-shapes.md
  - ../simplify-globals-optimizing/index.md
  - ../propagate-globals-globally/index.md
---

# Starshine Strategy For `simplify-globals`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md`](../../../raw/binaryen/2026-04-23-simplify-globals-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`simplify-globals` is still **unimplemented** in Starshine.
There is no `src/passes/simplify_globals.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is boundary-only status plus a concrete port map:

- keep the pass spelling tracked in the registry surface
- keep the boundary-only classification explicit, because the pass needs whole-module global analysis, startup-order reasoning, and function-boundary rewrites rather than HOT-region local rewrites
- keep active pipeline requests honest by rejecting the pass name instead of pretending it already exists
- keep the shared-engine relation to `simplify-globals-optimizing` and `propagate-globals-globally` explicit
- keep the current planning gap explicit: unlike the optimizing sibling, the repo still has **no dedicated plain-`simplify-globals` backlog slice** in `agent-todo.md`

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked boundary-only pass-name status
  - [`src/passes/optimize.mbt#L127-L141`](../../../../../src/passes/optimize.mbt#L127-L141)
    - `pass_registry_boundary_only_names()` includes `"simplify-globals"`
- active request guard for not-yet-ported boundary passes
  - [`src/passes/optimize.mbt#L458-L463`](../../../../../src/passes/optimize.mbt#L458-L463)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- boundary-only portfolio planning
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L56-L59`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L56-L59)
    - `simplify-globals` is grouped with type/global/signature shaping and whole-module transforms, not HOT-local cleanup
- scheduler context for the shared optimizing sibling
  - [`../../no-dwarf-default-optimize-path.md#L35-L41`](../../no-dwarf-default-optimize-path.md#L35-L41)
    - the canonical no-DWARF late path uses `simplify-globals-optimizing`, not plain `simplify-globals`, and the optimizing sibling owns the extra nested default-function rerun
- current backlog reality
  - [`../../../../../agent-todo.md#L535-L547`](../../../../../agent-todo.md#L535-L547)
    - the repo has an `SGO` slice for `simplify-globals-optimizing`, but no separate plain-`simplify-globals` slice today
- neighboring living dossiers a future port must line up with
  - [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md)
  - [`../propagate-globals-globally/index.md`](../propagate-globals-globally/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `simplify-globals` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `simplify-globals` in `pass_registry_boundary_only_names()`.
That means:

- the project still treats `simplify-globals` as a real known pass
- the spelling is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and planning work instead of silently falling out of scope
- the current local classification already teaches an important semantic fact: this is not expected to fit naturally into the existing HOT-only function pipeline

That is the right current behavior for an unimplemented whole-module late-global pass.

### 2. The active pipeline rejects the pass honestly

The same file's `run_hot_pipeline_expand_passes(...)` path returns a specific boundary-only error when a user requests `simplify-globals`.
That matters because it keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI and API surface do not imply the pass already exists locally
- the boundary-only classification remains executable documentation rather than dead metadata

For this pass family, that is currently the most important in-repo behavior after name tracking.

### 3. The current local planning story is intentionally thinner than the optimizing sibling's

Unlike `simplify-globals-optimizing`, plain `simplify-globals` does **not** currently have a dedicated backlog slice in `agent-todo.md`.
That absence is worth teaching explicitly because it prevents two common mistakes:

- assuming the optimizing `SGO` slice already covers the plain pass contract exactly
- assuming the repo has already committed to shipping both siblings separately rather than landing shared machinery first

The honest status is:

- boundary-only name tracked
- request guard tracked
- planning bucket tracked
- sibling relation tracked
- dedicated plain-pass backlog slice still absent

That gap should stay explicit until the repo chooses a concrete local landing sequence.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `simplify-globals` port should be taught as a **boundary/module pass**, not as a HOT peephole and not as a scheduler wrapper only.

Why:

- Binaryen runs it as a whole-module global analysis and rewrite pass
- correctness depends on module-wide global traffic facts, startup-order reasoning, and function-boundary substitutions
- the public contract includes startup rewrites into later global initializers and active offsets, not just ordinary function-body cleanup
- the same upstream engine also underlies `simplify-globals-optimizing` and `propagate-globals-globally`
- the pass sits conceptually beside `duplicate-import-elimination`, `remove-unused-module-elements`, `string-gathering`, `reorder-globals`, and `directize`, where boundary/module scheduling matters as much as local instruction rewriting

So the local strategy should be thought of as:

1. build whole-module global fact summaries
2. implement startup-only folding and offset propagation first
3. implement runtime cheap-trace substitution in function bodies with the same conservative barriers
4. preserve `drop(value)` when erasing dead or same-as-init writes
5. keep the exact `read-only-to-write` legality and actual-node matching rules explicit
6. repair affected function types after refined substitutions
7. stop there, without accidentally inheriting the optimizing sibling's nested default-function rerun

That is a much tighter and safer future plan than the vague mental model “add global constant propagation later.”

## The most important local dependency map

### Plain `simplify-globals` is the shared-engine sibling of `simplify-globals-optimizing`, but the public contract is smaller

See:

- [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md)

Why it matters locally:

- both public passes come from the same upstream `SimplifyGlobals.cpp` engine
- a future Starshine port should likely share most low-level global-analysis and rewrite machinery between the siblings
- the most important semantic difference to preserve is the stop point: plain `simplify-globals` stops after global rewrites and type repair, while `simplify-globals-optimizing` continues into the nested default-function rerun
- the current repo already has planning coverage only for the optimizing sibling, so a future contributor must decide whether to land shared primitives first or expose only the optimizing wrapper initially

### `propagate-globals-globally` is the startup-only sibling, not a random helper

See:

- [`../propagate-globals-globally/index.md`](../propagate-globals-globally/index.md)

Why it matters locally:

- plain `simplify-globals` includes the startup-only propagation surface but also owns more than that
- `propagate-globals-globally` is a useful design hint for decomposition: startup propagation is a real sub-algorithm with a meaningful stop point
- a future port can use that split to stage implementation work without pretending the startup-only subset already covers the full plain pass

### Late-global neighbors define the eventual boundary landing zone

The eventual local pass will need to compose with the same late-global neighborhood already documented elsewhere:

- [`../duplicate-import-elimination/index.md`](../duplicate-import-elimination/index.md)
- [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)
- [`../string-gathering/index.md`](../string-gathering/index.md)
- [`../reorder-globals/index.md`](../reorder-globals/index.md)
- [`../directize/index.md`](../directize/index.md)

Why it matters locally:

- this is another reason the port belongs in boundary/module scheduling rather than the HOT-only pipeline
- these passes consume and reshape the same late-boundary surfaces
- validation should eventually check both isolated `--simplify-globals` behavior and its surrounding late-tail neighborhood

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit owner file for `simplify-globals`
- module-wide global fact collection for the plain pass
- startup initializer / active-offset rewrite code for this family
- runtime global-value substitution logic for this family
- `read-only-to-write` matcher code or dead-`global.set` cleanup code for this family
- targeted type-repair code tied to a plain-`simplify-globals` boundary transform
- reduced plain-`simplify-globals` regression tests or artifact replay coverage
- a dedicated plain-`simplify-globals` backlog slice distinct from the optimizing sibling's `SGO` work

So the current repo status is best summarized as:

- name tracked
- boundary-only status tracked
- request guard tracked
- planning neighborhood tracked
- transform itself not yet landed

## Validation plan for the eventual port

The existing dossier plus the local status surfaces imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced rewrite tests for the reviewed upstream plain-pass families
   - startup-only single-use folding into later globals
   - startup propagation into active data and elem offsets
   - dead and same-as-init write removal with `drop(value)` preservation
   - `read-only-to-write` positives and bailout families
   - cheap runtime-trace positives plus call / nonlinear-control barriers
   - GC/type-refinement cases that require post-rewrite repair
2. sibling-boundary tests
   - plain `simplify-globals` stops without the optimizing sibling's nested default-function rerun
   - any shared machinery also composes with a future `propagate-globals-globally` subset
3. oracle comparison
   - compare `--simplify-globals` output against Binaryen rather than only `--simplify-globals-optimizing`
4. late-neighborhood checks
   - verify that the local scheduler still composes with the surrounding late global passes once the boundary implementation exists

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the exact families the repo will need to prove.

## Bottom line

Current Starshine `simplify-globals` strategy is honest boundary-only tracking plus a concrete port map:

- preserve the name and classification in the registry
- reject the unimplemented boundary pass honestly at runtime
- keep the shared-engine split from `simplify-globals-optimizing` and `propagate-globals-globally` explicit
- keep the lack of a dedicated plain-pass backlog slice explicit
- land any future implementation as a boundary/module pass with startup and runtime sub-algorithms, not as a HOT peephole

That is the clearest source-backed local story the repo can truthfully teach today.
