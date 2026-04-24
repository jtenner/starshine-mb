---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md
  - ../../../raw/research/0329-2026-04-24-simplify-locals-notee-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/simplify_locals_wbtest.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-boundaries-and-registry-aliases.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../untee/index.md
---

# Starshine Strategy For `simplify-locals-notee`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, naming mismatch, local code surfaces, and future port shape for the no-tee locals-family sibling.

## Honest current status

`simplify-locals-notee` is **not implemented** as an active Starshine pass today.
There is no `src/passes/simplify_locals_notee.mbt` owner file and no active dispatcher case for the upstream spelling.

The exact local status has two names:

| Surface | Name | Current Starshine status |
| --- | --- | --- |
| Binaryen public pass | `simplify-locals-notee` | not registered locally |
| Starshine compatibility placeholder | `simplify-locals-no-tee` | removed registry name |

So the pass is not forgotten, but the current registry tracks a local descriptive alias rather than the upstream public spelling.

## Exact local code map today

The fastest read-along path through the current Starshine state is:

- registry and active-request behavior
  - `src/passes/optimize.mbt`
    - `pass_registry_removed_names()` includes `"simplify-locals-no-tee"`
    - `pass_registry_category("simplify-locals-no-tee")` is therefore `Removed`
    - `pass_registry_category("simplify-locals-notee")` is not a local registry hit today
    - `run_hot_pipeline_expand_passes(...)` rejects removed names with `"removed from the active hot pipeline registry"`
- CLI parse behavior
  - `src/cmd/cmd.mbt`
    - pass-flag parsing accepts only `HotPass`, `ModulePass`, and `Preset` categories
    - removed names are rejected as `UnknownPassFlag`, so `--pass simplify-locals-no-tee` is deliberately not advertised as runnable
    - the exact upstream spelling is also rejected because it is not registered
- active full-pass implementation surface
  - `src/passes/simplify_locals.mbt`
    - `simplify_locals_descriptor()` publishes only active `"simplify-locals"`
    - `simplify_locals_summary()` already describes the broad local behavior: local-set sinking, structured block/if/loop returns, equivalent-copy canonicalization, and dead-write cleanup
    - the current implementation has reusable concepts for sinkables, effect conflicts, branch exits, stacked forwarders, structure lifting, equivalent copies, and final cleanup
    - it does not expose an `allowTee = false` mode today
- active dispatcher surface
  - `src/passes/pass_manager.mbt`
    - hot-pass dispatch handles `"simplify-locals" => simplify_locals_run(ctx, func)`
    - raw / writeback special cases also key on descriptor name `"simplify-locals"`
    - there is no `"simplify-locals-no-tee"` or `"simplify-locals-notee"` dispatch path
- tests and replay surfaces
  - `src/passes/registry_test.mbt`
    - proves active `simplify-locals` classification and removed-name rejection mechanics, but does not have a focused assertion for the local no-tee alias
  - `src/passes/optimize_test.mbt`
    - proves default presets run the active full `simplify-locals`, not the no-tee sibling
  - `src/passes/simplify_locals_test.mbt` and `src/passes/simplify_locals_wbtest.mbt`
    - cover the active full pass and many local traffic shapes, but not a sibling-specific “no newly introduced tee” policy
  - `src/passes/pass_manager_wbtest.mbt`
    - contains raw/writeback lanes and artifact-shaped full-pass coverage keyed to `simplify-locals`
- planning surfaces
  - `agent-todo.md`
    - no active dedicated `simplify-locals-notee` / `simplify-locals-no-tee` backlog slice was found in this run
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - canonical no-DWARF default path uses `simplify-locals-nostructure` early and full `simplify-locals` later, not this sibling

## What Starshine currently does for the pass name

### 1. The local alias is tracked as removed

The local registry entry `simplify-locals-no-tee` means the project knows about the upstream sibling family.
That is useful for docs, tracker coverage, and future compatibility work.

But the category is still `Removed`, so Starshine does not claim a runnable transform.

### 2. The exact upstream spelling is not registered

`src/passes/optimize.mbt` does not currently include `simplify-locals-notee` in active, boundary-only, or removed names.
That is the most important local-vs-upstream naming caveat for future CLI or registry cleanup.

A future compatibility decision should be explicit:

- normalize the registry to the upstream spelling, or
- keep the local descriptive alias but document it at the CLI / registry boundary, or
- support both names with one canonical implementation entry

What should not happen is a silent implementation under the wrong variant semantics.

### 3. Full `simplify-locals` is implemented, but that is not the same as this pass

The active full pass is the closest local implementation surface, but it is not equivalent because it may perform tee-enabled rewrite families that upstream `simplify-locals-notee` intentionally disables.

The future local distinction is not whether Starshine can simplify locals at all.
It is whether Starshine can run the same family with a policy that refuses fresh tee creation while still preserving structure formation and late cleanup.

## Future Starshine implementation shape

The most natural local implementation is a parameterized HOT locals-family mode rather than a separate module pass.

A future port should preserve these source-backed semantics:

1. keep the pass function-local / HOT-level
   - this is not a whole-module declaration pass
2. reuse as much active full-`simplify-locals` machinery as possible
   - sinkable tracking
   - effect invalidation
   - branch-exit and structured-result handling
   - equivalent-copy cleanup
   - final dead-set cleanup
3. add one explicit no-tee policy boundary
   - direct single-use sinking remains legal
   - structure formation remains legal
   - existing tees may still be analyzed as ordinary input syntax
   - new `local.tee` materialization for multi-use sinking must be disabled
4. keep descriptor and dispatcher naming honest
   - decide whether canonical Starshine pass spelling is upstream `simplify-locals-notee`, local `simplify-locals-no-tee`, or both
   - wire the chosen name through `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, and CLI help only when the behavior really exists
5. add sibling-specific tests
   - a positive single-use sink
   - a positive structured `if` / block result rewrite
   - a negative multi-use case that full `simplify-locals` might solve with a tee but no-tee mode must preserve
   - an effect/EH barrier inherited from the full family

## Do not confuse with neighboring passes

### Full `simplify-locals`

Full `simplify-locals` is active and broader.
It may introduce tees; the no-tee sibling may not.

### `simplify-locals-nostructure`

The no-structure sibling disables structured result formation but can still allow tee-enabled sinking.
This is the opposite axis from no-tee.

### `simplify-locals-notee-nostructure`

The no-tee/no-structure sibling disables both surfaces.
It is stricter than this pass.

### `untee`

`untee` desugars existing tees into set/get shapes.
It is not a general local-sinking pass and should not be treated as an implementation substitute for `simplify-locals-notee`.

## Current docs action

This follow-up intentionally keeps the pass as a docs/planning bridge, not as an implementation claim:

- the raw primary-source manifest closes the provenance gap
- this page closes the Starshine status gap
- the implementation/test-map page makes the upstream proof surfaces explicit
- the index/tracker/log updates should prevent future threads from rediscovering the old “working dossier with direct URLs only” gap as still open
