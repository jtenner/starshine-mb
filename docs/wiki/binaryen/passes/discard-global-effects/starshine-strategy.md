---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-discard-global-effects-current-main-recheck.md
  - ../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md
  - ../../../raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/ir/analysis_cache.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../global-effects/starshine-strategy.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./metadata-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../global-effects/starshine-strategy.md
---

# Starshine strategy for `discard-global-effects`

## Current status

Starshine does **not** currently implement or register `discard-global-effects`.

The 2026-07-11 current-main/local-source recheck did not change that status. It also sharpens the upstream comparison: Binaryen's public cleanup resets persistent per-function `Function.effects` summaries, while Starshine currently has only revision-keyed function-local HOT cache entries.

This is different from [`../global-effects/starshine-strategy.md`](../global-effects/starshine-strategy.md): Starshine has a boundary-only `global-effects` compatibility name for the producer-side concept, but no public cleanup sibling name.

## Exact local code map

Current relevant local surfaces:

- [`../../../../../src/passes/optimize.mbt:129-133`](../../../../../src/passes/optimize.mbt)
  - lists boundary-only names including `global-effects`, but not `discard-global-effects`.
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - owns pass expansion and the boundary-only/unknown-name rejection paths; an unregistered `discard-global-effects` request remains an unknown pass rather than the producer's boundary-only path.
- [`../../../../../src/ir/effects.mbt:5-32`](../../../../../src/ir/effects.mbt)
  - defines Starshine's function-local HOT effect-mask bits.
- [`../../../../../src/ir/effects.mbt:131-279`](../../../../../src/ir/effects.mbt)
  - derives effect masks from HOT nodes and exposes effect query helpers.
- [`../../../../../src/ir/analysis_cache.mbt:34`](../../../../../src/ir/analysis_cache.mbt)
  - stores an optional cached `HotEffectsSummary` in the function-local analysis cache.
- [`../../../../../src/ir/analysis_cache.mbt:70-81`](../../../../../src/ir/analysis_cache.mbt)
  - builds local node/block/root-region effect summaries.
- [`../../../../../src/ir/analysis_cache.mbt:217-227`](../../../../../src/ir/analysis_cache.mbt)
  - rebuilds cached effects when the HOT revision changes.
- [`../../../../../src/passes/pass_common.mbt:318-324`](../../../../../src/passes/pass_common.mbt)
  - provides `pass_require_effects(...)` for local passes that need HOT effect information.
- [`../../../../../src/passes/pass_manager.mbt:102826-102830`](../../../../../src/passes/pass_manager.mbt)
  - invalidates the local analysis cache when a hot function revision changes after a pass.

## Why no local pass is needed yet

Binaryen's cleanup sibling matters because Binaryen stores persistent per-function global-effect summaries on module functions and uses a pass-runner `addsEffects()` capability hook to discard those summaries before effect-adding transforms.

Current Starshine effect summaries are different:

- they are function-local HOT analysis-cache entries,
- they are keyed by HOT revision,
- the pass manager invalidates the cache after a function changes,
- they are not stored as durable module metadata for later unrelated passes.

That means Starshine's current invalidation analogue is revision-keyed cache rebuilding, not a public `discard-global-effects` no-op.

So a public `discard-global-effects` pass would have nothing Binaryen-equivalent to clear today. In particular, do not manufacture parity by clearing `HotAnalysisCache.effects` through a public pass: that cache is already invalidated/rebuilt by the HOT revision protocol and is not a persistent interprocedural summary visible across unrelated module passes.

## Future port strategy

A faithful future Starshine implementation should be conditional on first adding a real persistent producer:

1. implement or design `global-effects` as module-level interprocedural metadata,
2. decide where summaries live: module fields, pass-manager side table, or module-analysis cache,
3. teach downstream passes how to consult those summaries safely,
4. add invalidation rules for transforms that can add effects,
5. then expose `discard-global-effects` if public Binaryen CLI parity is required.

If summaries remain purely internal and revision-keyed, Starshine can keep cleanup as cache invalidation rather than a public pass.

## Validation plan for a future implementation

A useful future test suite should include:

- requesting `--discard-global-effects` is either a known no-op cleanup pass or a deliberately documented unsupported name,
- generated summaries disappear after the cleanup pass,
- modules with no summaries are unchanged,
- effect-sensitive consumers no longer use cleared facts,
- effect-adding passes cannot leave stale summaries behind.

Do not validate this pass only by printed WAT equality. Equality is expected even when the metadata cleanup worked.

## Current recommendation

Keep `discard-global-effects` as upstream-only wiki research until Starshine has persistent global-effect summaries. Cross-link it from `global-effects` so future implementers see the lifecycle requirement before designing the producer.

## Source refresh

The focused current-main reconciliation is [`../../../raw/binaryen/2026-07-11-discard-global-effects-current-main-recheck.md`](../../../raw/binaryen/2026-07-11-discard-global-effects-current-main-recheck.md). It rechecks the upstream owner, public registration, `addsEffects()` lifecycle, and exact local cache boundary; no executable behavior changed.
