---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-global-effects-current-main-recheck.md
  - ../../../raw/research/0480-2026-05-05-global-effects-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-04-global-effects-current-main-recheck.md
  - ../../../raw/research/0438-2026-05-04-global-effects-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md
  - ../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md
  - ../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../discard-global-effects/index.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
---

# Naming, metadata, and downstream consumers

## The name split is real

The local Starshine registry uses the short name `global-effects`.
Upstream Binaryen publishes the actual pass as `generate-global-effects`.

That distinction matters because a future port needs to keep at least three names straight:

- local registry placeholder: `global-effects`
- upstream producer pass: `generate-global-effects`
- upstream lifecycle sibling: `discard-global-effects`

If the wiki collapses those together, later implementation or CLI work will get confusing quickly.

## The pass changes metadata, not printed WAT

This is the single most important teaching point.

`wasm.h` shows that a `Function` can store optional `effects` metadata.
`generate-global-effects` writes that field.

One source wording caveat is now explicit in the raw manifests: the `GlobalEffects.cpp` header still says the pass stores effects on `PassOptions`, but the reviewed implementation and `wasm.h` model show `Function.effects` writeback. The 2026-05-05 recheck did not change that teaching call; treat the `PassOptions` wording as stale unless upstream changes the actual data model.

So the pass may leave the visible WAT unchanged while still changing later optimizer decisions.

That is why this folder exists at all:

- without a dedicated page, readers can see later passes mention “generated global effects” and still not know where they came from
- because there is often no immediate WAT diff, it is easy to assume nothing important happened

## Why `discard-global-effects` exists

The existence of [`../discard-global-effects/index.md`](../discard-global-effects/index.md) is a quiet but important clue about Binaryen's design.

It means:

- the summaries are explicit pass-managed state
- they are not treated as permanently valid ambient truth
- later transforms may need to clear them if they become stale or if a pipeline no longer wants to rely on them

So a future Starshine port should think about both production and lifecycle, not just production. Use the dedicated sibling page for the cleanup pass's own metadata-shape, Binaryen-strategy, and Starshine-status details.

## How later passes benefit

The reviewed `effects.h` source shows that later `EffectAnalyzer` queries on direct `Call` nodes may use the target function's stored summary.

That enables more precise answers to questions like:

- does this call write a specific global?
- is it only reading globals?
- can a `global.get` move across it?
- can an unused call be dropped?

This is why neighboring optimizer pages already care about the pass.

## Consumer family 1: `simplify-locals`

The dedicated upstream `global-effects_simplify-locals.wast` test compares `simplify-locals` alone with `generate-global-effects` followed by `simplify-locals`.
That proves the intuitive consumer example:

- some motion is unsafe across a call that writes globals
- some motion is safe across a call that only reads globals
- `generate-global-effects` can supply exactly that distinction to later effect reasoning

## Consumer family 2: `vacuum`

The directly reviewed `vacuum-global-effects.wast` test proves another consumer family:

- after generated summaries exist, some calls become effect-free enough for `vacuum` to erase when unused

That is a good beginner example because it makes the indirect payoff visible:

- `generate-global-effects` itself does not erase the call
- it makes a later pass confident enough to do so

## Easy misunderstandings

### “If there is no WAT diff, the pass did nothing.”

Wrong.
The pass may have produced only metadata, but that metadata can materially change later optimizer behavior.

### “This pass is a global version of DCE.”

Wrong.
It is not a direct cleanup pass.
It is an interprocedural effect-summary producer.

### “Once the summaries exist, they are just always correct forever.”

Wrong.
The sibling [`discard-global-effects`](../discard-global-effects/index.md) pass is explicit evidence that Binaryen treats summary lifecycle seriously.

### “This is obviously part of the default optimization path.”

Wrong.
`pass.cpp` explicitly says it is not added to the default pipeline today.

## Porting rule of thumb

When porting this family, think in three steps:

1. **produce** summaries honestly
2. **consume** them in later effect reasoning honestly
3. **invalidate or discard** them honestly when later rewrites would make them stale

Skipping any one of those will drift away from Binaryen's real contract. The future-Starshine sequencing in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) keeps those steps separated: summary production first, consumer use second, invalidation/discard design throughout.

## Sources

- [`../../../raw/binaryen/2026-05-04-global-effects-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-global-effects-current-main-recheck.md)
- [`../../../raw/research/0438-2026-05-04-global-effects-current-main-recheck.md`](../../../raw/research/0438-2026-05-04-global-effects-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md)
- [`../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md`](../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md)
- [`../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md`](../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md`](../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md)
