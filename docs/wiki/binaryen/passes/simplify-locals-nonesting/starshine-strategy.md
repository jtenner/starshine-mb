---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md
  - ../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-variant-boundaries.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../simplify-locals/starshine-hot-ir-strategy.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nostructure/index.md
  - ../flatten/index.md
  - ../dataflow-optimization/index.md
  - ../souperify/index.md
  - ../tracker.md
---

# Starshine `simplify-locals-nonesting` status and port strategy

## Current status

Starshine does **not** currently implement upstream Binaryen `simplify-locals-nonesting`.

The precise local state is:

- upstream Binaryen spelling: `simplify-locals-nonesting`
- local Starshine compatibility spelling: `simplify-locals-no-nesting`
- registry category today: **removed**, not active
- CLI help today: hidden
- explicit CLI request today: rejected before pipeline execution
- lower-level pipeline request today: rejected as removed from the active hot pipeline registry
- owner file today: none
- active backlog slice today: none found in `agent-todo.md`

That means the active Starshine `simplify-locals` pass is reusable context, but it is **not** a nonesting sibling implementation.

## Why the local spelling matters

Binaryen publishes the pass as `simplify-locals-nonesting`.
Starshine tracks only the local alias `simplify-locals-no-nesting` in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).

This distinction affects users and future ports:

- `--simplify-locals-nonesting` is not a recognized local registry name today.
- `--simplify-locals-no-nesting` is recognized by the registry as a removed compatibility name, but [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt) only accepts active hot/module/preset categories as executable CLI pass flags.
- The lower-level pipeline expansion in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) still has a more specific removed-pass error if the name reaches that layer.

A future port should decide deliberately whether to:

1. keep only the local alias,
2. add the upstream spelling as an alias, or
3. migrate to the upstream spelling while preserving compatibility.

Do not silently conflate the names in docs or tests.

## Exact code-location map

| Surface | Current local code location | What it proves |
| --- | --- | --- |
| Removed alias registry | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 145-151, `pass_registry_removed_names()` | `simplify-locals-no-nesting` is tracked only as a removed local compatibility name. |
| Preset omission | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 384-410, `optimize_preset_passes(...)` / `shrink_preset_passes(...)` | Public `optimize` / `shrink` presets run active full `simplify-locals`, not the nonesting sibling. |
| Lower-level request rejection | [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lines 451-489, `run_hot_pipeline_expand_passes(...)` | Removed registry entries are rejected before dispatch. |
| CLI category gate | [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt) lines 1910-1977, `cmd_resolve_pipeline_steps(...)` | Only active hot/module/preset categories become pipeline steps; removed names are surfaced as unknown pass flags to CLI users. |
| Help visibility | [`src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt) lines 2849-2967, `cmd_build_help_text()` | Help lists hot passes and presets only, so the removed alias is intentionally hidden. |
| Active hot dispatcher | [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) lines 8667-8704, `hot_pass_run(...)` | The dispatcher has a case for active full `simplify-locals` only. |
| Raw full-pass bypass | [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) lines 4298-4306, `run_hot_pipeline_raw_simplify_locals(...)` | Existing raw fallback/gating is keyed to descriptor name `simplify-locals`, not a sibling mode. |
| Reusable implementation surface | [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt) lines 1-24 and 3637-4485, `simplify_locals_descriptor()` / `simplify_locals_run_structure_rewrites(...)` / `simplify_locals_run(...)` | This is the likely future landing zone, but today it implements the full local pass rather than an `allowNesting = false` variant. |
| Existing active-pass proof | [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt) lines 1-95 | Tests classify active full `simplify-locals`; they do not currently prove the removed alias or upstream spelling behavior directly. |

## What a faithful Starshine port must preserve

The Binaryen contract summarized in [`./binaryen-strategy.md`](./binaryen-strategy.md) and [`./flatness-variant-boundaries.md`](./flatness-variant-boundaries.md) gives the future local acceptance criteria.

A faithful Starshine port must preserve all of these at once:

1. **No fresh tees.** Multi-use sinking cannot be implemented by creating `local.tee` nodes.
2. **No structure synthesis.** The full `simplify-locals` block / `if` / loop result-lifting families must be disabled.
3. **No ordinary new nesting.** Non-copy values must not be pushed into arbitrary consumer operands such as `drop`, calls, arithmetic, branch payloads, or control conditions.
4. **Copy cleanup remains active.** Local-copy retargeting and same-`local.set` value-position rewrites should still happen where they preserve flatness.
5. **Late cleanup remains active.** Equivalent-copy cleanup and dead-set cleanup are still part of the useful pass contract, not optional extras.
6. **Flatness-sensitive pipeline role remains explicit.** The pass is a cleanup after `flatten`, not a replacement for `flatten`.

## Best local landing zone

The most likely implementation shape is to add an explicit policy mode to [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt), because that file already owns the active local-sinking, structure, equivalent-copy, and dead-cleanup phases.

A future mode could model Binaryen's axes directly:

- `allow_tee`
- `allow_structure`
- `allow_nesting`

For this pass, all three would be false.
That is preferable to copying the full pass into a new unrelated file, because the nonesting variant is a **shared-engine sibling** upstream.

## Current full-`simplify-locals` differences

The active Starshine `simplify-locals` pass currently does more than a nonesting sibling would be allowed to do.
In particular, the current implementation includes:

- main local-set sinking cycles
- dead local write cleanup
- structure rewrites
- late equivalent-copy cleanup for selected functions
- raw fallback and lower/writeback hygiene keyed to the full `simplify-locals` descriptor

Those are valuable implementation assets, but a future `simplify-locals-nonesting` mode would need to disable or gate parts of them.
The exact danger is advertising full-pass behavior as a flatness-preserving sibling.

## Suggested future tests

Add tests before implementing the port.
Minimum focused coverage:

- registry/category tests for whichever spelling policy is chosen
- CLI request behavior while the pass is removed, then active behavior after implementation
- positive flat copy-chain retargeting
- positive direct rewrite into another `local.set` value position
- preserved `drop (local.get $tmp)` when `$tmp` is a non-copy computed value
- preserved `call` / arithmetic consumer nesting for non-copy values
- preserved multi-use value that would require a fresh tee
- preserved `if` / block / loop result-carrier synthesis negatives
- late dead-set cleanup after a flat rewrite
- a small `flatten -> simplify-locals-nonesting -> dfo`-style fixture once the neighboring flatness pipeline exists locally

## Validation strategy

For a future implementation, use the normal pass workflow:

- focused MoonBit tests for the policy-mode split
- registry and CLI request tests
- direct pass compare against Binaryen using the canonical upstream spelling if the harness supports aliases
- a dedicated sibling compare lane before adding the pass to any preset
- explicit negative tests showing the pass is not equivalent to full `simplify-locals` or `simplify-locals-notee-nostructure`

Until those tests exist and pass, keep this page as a **status/port-strategy page**, not as an implementation guide for an active pass.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md)
- [`../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md`](../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md`](../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
