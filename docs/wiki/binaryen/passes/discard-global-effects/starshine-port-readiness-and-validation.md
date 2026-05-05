---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-discard-global-effects-current-main-recheck.md
  - ../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-discard-global-effects-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ../../../raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/ir/analysis_cache.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../global-effects/index.md
  - ../global-effects/starshine-port-readiness-and-validation.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./metadata-shapes.md
  - ./starshine-strategy.md
  - ../global-effects/index.md
  - ../global-effects/starshine-port-readiness-and-validation.md
---

# Starshine port-readiness and validation for `discard-global-effects`

## Current status

Starshine does **not** currently implement or register `discard-global-effects`.

That is intentional. The local codebase currently has only a revision-keyed HOT effect-cache analogue, not persistent module-level `Function.effects` metadata to clear.

## Exact local code map

Current relevant local surfaces:

- [`../../../../../src/passes/optimize.mbt:127-134`](../../../../../src/passes/optimize.mbt)
  - lists boundary-only names such as `global-effects`, but not `discard-global-effects`.
- [`../../../../../src/passes/optimize.mbt:307-310`](../../../../../src/passes/optimize.mbt)
  - installs those boundary-only names into the registry.
- [`../../../../../src/passes/optimize.mbt:518-524`](../../../../../src/passes/optimize.mbt)
  - rejects boundary-only and removed pass names during hot-pipeline expansion.
- [`../../../../../src/ir/effects.mbt:5-32`](../../../../../src/ir/effects.mbt)
  - defines the HOT effect-mask vocabulary used by local movement-sensitive passes.
- [`../../../../../src/ir/analysis_cache.mbt:19-35`](../../../../../src/ir/analysis_cache.mbt)
  - defines `HotEffectsSummary` and stores the cached summary entry.
- [`../../../../../src/ir/analysis_cache.mbt:70-81`](../../../../../src/ir/analysis_cache.mbt)
  - builds local node, block, and root-region effect summaries.
- [`../../../../../src/ir/analysis_cache.mbt:217-227`](../../../../../src/ir/analysis_cache.mbt)
  - rebuilds cached effects when the HOT revision changes.
- [`../../../../../src/passes/pass_common.mbt:318-324`](../../../../../src/passes/pass_common.mbt)
  - exposes `pass_require_effects(...)` for local passes that need HOT effect information.

## Why no local cleanup pass is needed yet

Binaryen's cleanup sibling matters because Binaryen stores persistent per-function summaries on the module `Function` object and uses pass lifecycle rules to clear those summaries before an effect-adding transform.

Current Starshine effect summaries are different:

- they are function-local HOT analysis-cache entries,
- they are keyed by HOT revision,
- the pass manager invalidates the cache after a function changes,
- they are not durable module metadata for unrelated later passes.

So Starshine's current invalidation analogue is revision-keyed cache rebuilding, not a public `discard-global-effects` cleanup pass.

## Future port strategy

If Starshine ever adds persistent module-level global-effect summaries, a cleanup decision becomes meaningful again.

At that point the implementation should choose one of two honest shapes:

1. keep cleanup internal to the summary cache, or
2. mirror Binaryen's public `discard-global-effects` pass name for CLI parity.

Either way, the cleanup step should stay a metadata-invalidation action, not a Wasm rewrite.

## Validation plan for a future implementation

A useful future test suite should include:

- requesting `--discard-global-effects` is either a known no-op cleanup pass or a deliberately documented unsupported name,
- generated summaries disappear after the cleanup step,
- modules with no summaries are unchanged,
- effect-sensitive consumers no longer use cleared facts,
- effect-adding passes cannot leave stale summaries behind,
- printed WAT equality is not treated as proof of correctness.

## Cross-links for the pass dossier

Read this page with:

- [`./index.md`](./index.md) for the overview, purpose, invariants, inputs/outputs, and validation story
- [`./metadata-shapes.md`](./metadata-shapes.md) for the transformed metadata/module/function shapes and caveats
- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream cleanup algorithm and lifecycle contract
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the owner-file / pass-runner / consumer test map
- [`./starshine-strategy.md`](./starshine-strategy.md) for the current local non-implementation and code-map details
- [`../global-effects/index.md`](../global-effects/index.md) for the producer-side `generate-global-effects` dossier
- [`../global-effects/starshine-port-readiness-and-validation.md`](../global-effects/starshine-port-readiness-and-validation.md) for the producer-side local implementation ladder

## Non-goals for current Starshine

Until a module-level persistent producer exists, do not claim that Starshine:

- computes Binaryen-compatible persistent `Function.effects` metadata,
- makes later calls less conservative using interprocedural summaries,
- implements upstream `discard-global-effects`,
- includes `discard-global-effects` in `optimize` or `shrink` presets,
- has a dedicated active backlog slice for this pass.
