---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md
  - ../../../raw/research/0269-2026-04-23-duplicate-import-elimination-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../duplicate-function-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./identity-and-rewrite-surface.md
  - ./wat-shapes.md
  - ../duplicate-function-elimination/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
---

# Starshine Strategy For `duplicate-import-elimination`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`duplicate-import-elimination` is still **unimplemented** in Starshine.
There is no `src/passes/duplicate_import_elimination.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is boundary-only status plus corrected landing-zone planning:

- keep the pass spelling tracked in the registry surface
- keep the boundary-only classification explicit, because the pass needs module import and module-level function-reference rewrites rather than HOT-region local rewrites
- keep active pipeline requests honest by rejecting the pass name instead of pretending it already exists
- keep the canonical no-DWARF late slot documented
- keep the backlog slice visible, while also recording that its current wording is broader than reviewed Binaryen `version_129`
- teach the surrounding late-boundary dossiers a future port would have to compose with

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked boundary-only pass-name status
  - [`src/passes/optimize.mbt#L127-L131`](../../../../../src/passes/optimize.mbt#L127-L131)
    - `pass_registry_boundary_only_names()` includes `"duplicate-import-elimination"`
- active request guard for not-yet-ported boundary passes
  - [`src/passes/optimize.mbt#L446-L461`](../../../../../src/passes/optimize.mbt#L446-L461)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- backlog and delivery plan
  - [`agent-todo.md#L518-L526`](../../../../../agent-todo.md#L518-L526)
    - `DIE - Duplicate Import Elimination`
- canonical scheduler context
  - [`../no-dwarf-default-optimize-path.md#L35`](../no-dwarf-default-optimize-path.md#L35)
    - the canonical late-tail slot where `duplicate-import-elimination` follows `duplicate-function-elimination` and precedes `simplify-globals-optimizing`
- neighboring living dossiers a future port must line up with
  - [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md)
  - [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md)
  - [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `duplicate-import-elimination` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `duplicate-import-elimination` in `pass_registry_boundary_only_names()`.
That means:

- the project still treats `duplicate-import-elimination` as a real known pass
- the spelling is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning
- the current local classification already teaches an important semantic fact: this is not expected to fit naturally into the existing HOT-only function pipeline

That is the right current behavior for an unimplemented late boundary pass.

### 2. The active pipeline rejects the pass honestly

The same file's `run_hot_pipeline_expand_passes(...)` path returns a specific boundary-only error when a user requests `duplicate-import-elimination`.
That matters because it keeps three things honest at once:

- explicit pass selection does not silently no-op
- the CLI and API surface do not imply the pass already exists locally
- the boundary-only classification remains executable documentation rather than dead metadata

For this pass family, that is currently the most important in-repo behavior after name tracking.

### 3. The work is planned as a real parity slice, but the current backlog wording is broader than Binaryen `version_129`

`agent-todo.md` already gives the pass a real backlog slice under `DIE`.
That is good.
But the page also currently says future work should:

- compare import module, field, and external type exactly
- patch function, table, global, and memory import users consistently

That wording is broader than the reviewed Binaryen `version_129` contract.
The reviewed upstream pass is still:

- function-import-only
- keyed by `(module, base)` with exact function-type equality
- limited to the function-name rewrite surface described in [`./identity-and-rewrite-surface.md`](./identity-and-rewrite-surface.md)

So the honest Starshine strategy today is:

- keep `DIE` visible as the future landing slice
- keep the broader backlog wording explicit as a mismatch
- do **not** silently teach the backlog wording as if it already matched reviewed Binaryen behavior

That contradiction is important enough to record explicitly because it changes what a future parity port should actually implement first.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `duplicate-import-elimination` port should be taught as a **small late boundary/module pass**, not as a generic import deduplicator and not as a HOT peephole.

Why:

- Binaryen runs it late, after `duplicate-function-elimination`
- its correctness depends on module import declarations plus module-level function-reference rewriting
- the real upstream pass is tiny and structural rather than analysis-heavy
- the immediate downstream neighbor `simplify-globals-optimizing` expects the late-boundary module to be a little cleaner before it starts its own rewrite work

So the local strategy should be thought of as:

1. scan imported functions only
2. bucket candidates by `(module, base)`
3. require exact function-type equality before merging
4. preserve first-import-wins canonicalization
5. rewrite only the actual Binaryen function-name surfaces
6. remove duplicate imported functions immediately
7. leave broader all-import deduplication as future divergence work unless upstream itself widens the contract

That is a much tighter and safer future plan than the older broad “deduplicate every import kind” mental model.

## The most important local dependency map

### `duplicate-import-elimination` is downstream of `duplicate-function-elimination`

See:

- [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md)

Why it matters locally:

- the no-DWARF scheduler docs already place `duplicate-import-elimination` after a second `duplicate-function-elimination`
- a future Starshine port should validate not just `--duplicate-import-elimination` in isolation, but also the late-boundary neighborhood that feeds it
- the upstream pass itself is small, so getting the scheduler slot and neighboring state right matters more than building a large local framework around it

### `duplicate-import-elimination` feeds the later late-boundary cleanup tail

See:

- [`../simplify-globals-optimizing/index.md`](../simplify-globals-optimizing/index.md)
- [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)

Why it matters locally:

- the canonical no-DWARF scheduler places `duplicate-import-elimination` before both of those passes
- even though the pass is function-import-only, it still changes the module's import/function-name surface before later cleanup and reachability passes run
- a future Starshine port should therefore be validated in the real late-tail neighborhood, not only as a standalone import rewrite

### `duplicate-import-elimination` is boundary work, not a neighbor of the current HOT peephole cluster

This is one of the most important local teaching points.
The current active Starshine HOT cluster covers passes like:

- `dead-code-elimination`
- `remove-unused-names`
- `remove-unused-brs`
- `optimize-instructions`
- `precompute`
- `merge-blocks`

Those are useful neighboring dossiers for style and validation habits, but `duplicate-import-elimination` does not naturally belong in that cluster.
Its current boundary-only classification is not arbitrary bookkeeping.
It reflects the same architectural fact the Binaryen dossier teaches: this pass rewrites module import and function-reference surfaces, not HOT-region local patterns.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a `duplicate-import-elimination` MoonBit implementation file
- local imported-function bucketing or canonicalization logic for this pass
- a local equivalent to Binaryen's `OptUtils::replaceFunctions(...)` rewrite just for this pass
- reduced `duplicate-import-elimination` regression tests
- artifact replay coverage specific to the pass beyond the tracked backlog slice and scheduler docs

So the current repo status is best summarized as:

- name tracked
- boundary-only status tracked
- request guard tracked
- backlog tracked
- scheduler slot documented
- corrected Binaryen-vs-backlog mismatch recorded
- transform itself not yet landed

## Validation plan for the eventual port

The existing backlog plus the upstream dossier imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the real upstream families
   - duplicate imported-function positives
   - preserved different-signature negatives
   - `ref.func` and element-payload rewrites
   - `start` and export retargeting
2. scope-boundary negatives
   - imported globals, tables, memories, and tags remain untouched for strict `version_129` parity
3. scheduler-neighborhood interaction tests
   - the late boundary segment around `duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements`
4. artifact and oracle comparison
   - the `DIE` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact neighboring passes that should feed the port.

## Bottom line

Current Starshine `duplicate-import-elimination` strategy is honest boundary-only tracking plus a corrected port map:

- the pass name is intentionally preserved in [`src/passes/optimize.mbt#L127-L131`](../../../../../src/passes/optimize.mbt#L127-L131)
- the same file keeps the active pipeline honest by rejecting boundary-only requests at [`#L446-L461`](../../../../../src/passes/optimize.mbt#L446-L461)
- [`agent-todo.md#L518-L526`](../../../../../agent-todo.md#L518-L526) already treats it as a real late parity slice under `DIE`, while this page now makes the reviewed Binaryen-vs-backlog scope mismatch explicit
- the canonical slot is already documented in [`../no-dwarf-default-optimize-path.md#L35`](../no-dwarf-default-optimize-path.md#L35)
- the surrounding [`duplicate-function-elimination`](../duplicate-function-elimination/index.md), [`simplify-globals-optimizing`](../simplify-globals-optimizing/index.md), and [`remove-unused-module-elements`](../remove-unused-module-elements/index.md) dossiers already define the practical landing zone for a future port

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear late-boundary dependency story**
- **clear Binaryen-vs-backlog mismatch to avoid porting the wrong contract first**
