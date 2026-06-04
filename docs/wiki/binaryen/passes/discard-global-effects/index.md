---
kind: entity
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-05-05-discard-global-effects-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-02-binaryen-v125-current-trunk-release-horizon.md
  - ../../../raw/binaryen/2026-05-05-discard-global-effects-current-main-line-anchor-refresh.md
  - ../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md
  - ../../../raw/research/0493-2026-05-05-discard-global-effects-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-04-26-discard-global-effects-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md
  - ../../../raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md
  - ../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/ir/analysis_cache.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./metadata-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../global-effects/index.md
---

# `discard-global-effects`

## Role

`discard-global-effects` is Binaryen's public cleanup sibling for [`../global-effects/index.md`](../global-effects/index.md) / upstream `generate-global-effects`.

It is not a normal code-shrinking rewrite. Its job is to clear stored per-function global-effect summaries so later passes do not trust stale interprocedural effect knowledge.

## Beginner summary

A beginner-friendly model:

1. `generate-global-effects` can annotate functions with summaries such as “this callee has no global writes.”
2. Later passes may use those summaries to remove or reorder calls more aggressively.
3. If another pass changes a function body, those summaries may become stale.
4. `discard-global-effects` erases the summaries so future passes recompute or behave conservatively.

So the pass usually has **no standalone WAT diff**. The changed state is Binaryen's in-memory metadata.

## Inputs and outputs

Inputs:

- a Binaryen module,
- zero or more defined/imported functions,
- optional per-function global-effect summaries previously written by `generate-global-effects` or another analysis step.

Outputs:

- the same module bodies, imports, exports, globals, tables, memories, element segments, and data segments,
- the same function declarations and types,
- cleared stored global-effect summaries on each function.

## Correctness constraints

- Do not rewrite Wasm instructions, declarations, or ABI-visible names.
- Clear summaries on every function, not just functions changed by the immediately previous pass.
- Treat clearing already-empty summaries as a no-op.
- Preserve validation: the pass should not affect stack types, section order, or feature requirements.
- Preserve optimization safety: later passes must see no stale summary after this cleanup.

## Important caveats

- This is a **pass-state cleanup transformation**, not an instruction optimizer.
- The dedicated source set did not reveal a standalone `discard-global-effects.wast` lit file; the pass is source-confirmed through `GlobalEffects.cpp` / `pass.cpp` / `pass.h` and lifecycle-confirmed through `generate-global-effects` consumers.
- Starshine does **not** currently expose a `discard-global-effects` registry name. Its local `global-effects` entry is boundary-only and covers the producer-side compatibility name, not this cleanup sibling.
- The 2026-05-05 current-main recheck and line-anchor refresh left the cleanup contract unchanged.
- The repo-wide Binaryen release horizon now reaches `version_130`; this page stays anchored to the reviewed `version_129` cleanup surfaces because the cleanup contract itself did not drift.

## Validation guidance

For Binaryen parity work:

- inspect in-memory function metadata after the pass if possible,
- compose producer/cleanup/consumer sequences rather than expecting a plain WAT diff,
- verify that downstream passes behave conservatively after summaries are cleared,
- check that modules with no summaries stay unchanged.

For Starshine work:

- do not add a public cleanup pass until there is persistent module-level global-effect metadata to clear,
- keep local HOT effect-cache invalidation separate from Binaryen's persistent `Function.effects` lifecycle,
- if a persistent producer lands, add tests that prove stale summaries cannot survive effect-adding rewrites.

## Page map

- [`./metadata-shapes.md`](./metadata-shapes.md) covers the transformed metadata/module/function states with concrete before/after shapes.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) explains the upstream source strategy and lifecycle relation to `generate-global-effects`.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) maps the owner files, pass-runner invalidation hook, indirect consumer tests, and no-standalone-WAT-diff caveat.
- [`./starshine-strategy.md`](./starshine-strategy.md) maps the current local non-implementation, exact code locations, and future port decision.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) adds the missing future cleanup bridge: cache-vs-metadata split, local code map, and validation ladder for the still-unregistered sibling.

## Sources

- [`../../../raw/binaryen/2026-05-05-discard-global-effects-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-discard-global-effects-current-main-recheck.md)
- [`../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md`](../../../raw/research/0460-2026-05-05-discard-global-effects-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-discard-global-effects-implementation-test-map.md`](../../../raw/binaryen/2026-04-26-discard-global-effects-implementation-test-map.md)
- [`../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md)
- [`../../../raw/research/0383-2026-04-26-discard-global-effects-implementation-test-map.md`](../../../raw/research/0383-2026-04-26-discard-global-effects-implementation-test-map.md)
- [`../../../raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md`](../../../raw/research/0353-2026-04-25-discard-global-effects-source-dossier.md)
- [`../global-effects/index.md`](../global-effects/index.md)
