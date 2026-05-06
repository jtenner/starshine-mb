---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-global-effects-current-main-recheck.md
  - ../../../raw/research/0480-2026-05-05-global-effects-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-global-effects-current-main-line-anchor-refresh.md
  - ../../../raw/research/0490-2026-05-05-global-effects-current-main-line-anchor-refresh.md
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
  - ./metadata-naming-and-consumers.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../discard-global-effects/index.md
  - ../simplify-locals/implementation-structure-and-tests.md
  - ../vacuum/effect-pruning-and-traps-never-happen.md
---

# Upstream implementation structure and tests for `global-effects`

## Main reviewed files

| File | What it proves | Why it matters |
| --- | --- | --- |
| `src/passes/GlobalEffects.cpp` | The actual pass algorithm: shallow per-function effect scan, static-call reachability / current-main SCC propagation (confirmed again on 2026-05-05), conservative unknown-call and recursion handling, and storage into `Function.effects` | This is the main implementation oracle. |
| `src/passes/pass.cpp` | Public pass registration under the upstream name `generate-global-effects`, sibling [`discard-global-effects`](../discard-global-effects/index.md), and the explicit note that the pass is not currently scheduled in the default optimization sequence | This is the main scheduler and naming oracle. |
| `src/ir/effects.h` | Consumer-side handoff: `EffectAnalyzer` on a direct `Call` may incorporate a callee's stored `effects` summary | This explains why the pass matters downstream. |
| `src/wasm.h` | `Function` really stores an optional `effects` pointer as explicit metadata | This proves the pass is metadata-producing, not IR-rewriting. |
| `test/lit/passes/vacuum-global-effects.wast` | A real downstream consumer case where generated summaries make later `vacuum` cleanup stronger | This is the clearest reviewed behavior proof for the pass's cleanup value. |
| `test/lit/passes/global-effects_simplify-locals.wast` | A direct comparison of `simplify-locals` with and without generated summaries | This proves a movement/locals-cleanup consumer family beyond `vacuum`. |

## Current-main source anchors

- `GlobalEffects.cpp#L1006-L1035` - stale `PassOptions` comment, `FuncInfo` setup, and the shallow per-function summary shell
- `GlobalEffects.cpp#L1046-L1155` - parallel body scan plus direct-call and unknown-call classification
- `GlobalEffects.cpp#L1329-L1530` - SCC/component propagation, recursive-cycle trap marking, and per-function writeback
- `pass.cpp#L2475-L2480` - the cleanup sibling registration block
- `pass.cpp#L2558-L2561` - the producer registration block
- `pass.cpp#L3687-L3692` - the explicit note that the pass is still not part of the default optimize sequence
- `effects.h#L3479-L3525` - direct-call consumer lookup on `Call` nodes

## Exact local Starshine code-map refresh

The 2026-05-05 line-anchor refresh keeps these exact local surfaces explicit for the living dossier:

- `src/passes/optimize.mbt:127-137, 315-318, 525-531`
- `src/cli/cli_test.mbt:207-210`
- `src/cmd/cmd.mbt:1721-1731, 1919-1923`
- `src/passes/pass_common.mbt:118-120, 318-338`
- `src/ir/analysis_cache.mbt:19-23, 34-35, 70-72, 220-222`
- `src/passes/simplify_locals.mbt:4413-4607`
- `src/passes/heap_store_optimization.mbt:2224-2234`

## `GlobalEffects.cpp`

This file establishes the pass contract.

The most important structural points are:

1. **parallel shallow scan first**
   - the pass builds a per-function `FuncInfo` from shallow `EffectAnalyzer` data
2. **direct-call and unknown-effect split next**
   - direct static calls become call-graph facts; imports, indirect calls, and unresolved call surfaces stay conservative
3. **transitive propagation after that**
   - `version_129` uses deferred reachability, while current `main` refactors this through SCC component aggregation
4. **recursive-cycle conservatism**
   - recursive call chains are treated as trapping rather than silently optimistic
5. **metadata writeback at the end**
   - the summary lives in `Function.effects`

That is why the right high-level summary is:

- analysis pass
- metadata output
- interprocedural fixed point

not:

- peephole pass
- local tree walk
- one-shot rewrite

## `pass.cpp`

This file proves three separate facts that are all easy to blur together:

### 1. Public name

Upstream registers the pass as `generate-global-effects`.

### 2. Sibling lifecycle pass

Upstream also registers [`discard-global-effects`](../discard-global-effects/index.md).
That is strong evidence that Binaryen expects this metadata to have a lifecycle.

### 3. Default-pipeline policy

The registration comment says Binaryen is **not** adding `generate-global-effects` to the default optimize sequence today.
That is the key scheduler fact the landing page must keep explicit.

## `effects.h`

This file answers the most important “why” question.

The call-handling logic can consult a target function's stored `effects` summary when one exists.
So the pass is not an isolated side table.
It is directly connected to later effect reasoning.

That one fact explains why neighboring passes can gain precision without `generate-global-effects` itself changing any WAT.

## `wasm.h`

This file proves where the data lives.

A `Function` owns an optional `std::unique_ptr<EffectAnalyzer>` field named `effects`.
That matters for two reasons:

- it confirms this is official per-function metadata, not an ad hoc temporary cache hidden inside one pass
- it explains why later passes and lifecycle passes can observe, clear, or reuse the same summaries

## Reviewed upstream test surface

## `vacuum-global-effects.wast`

This is the clearest cleanup-consumer test surface.
Its value is not that it tests `generate-global-effects` in isolation.
Its value is that it proves the pass changes what a later consumer can safely do.

The beginner takeaway is:

- before generated summaries, some calls are treated conservatively
- after generated summaries, `vacuum` can identify some unused calls as removable

So the test is a consumer proof rather than a pretty before/after rewrite demo for the pass itself.

## `global-effects_simplify-locals.wast`

This test compares `simplify-locals` alone with `generate-global-effects` followed by `simplify-locals`.
It proves a second consumer family: generated summaries can let local simplification reason more precisely across calls that read globals versus calls that write or otherwise affect globals.

The important boundary remains the same: the visible rewrite belongs to `simplify-locals`; `generate-global-effects` supplies metadata.

## Beginner-friendly file map summary

If you only remember one source role per file, remember this:

- `GlobalEffects.cpp` = **how the summaries are computed**
- `pass.cpp` = **what the public pass is called and where it is scheduled**
- `effects.h` = **how later passes consume the summaries**
- `wasm.h` = **where the summaries live**
- `vacuum-global-effects.wast` = **proof that the metadata changes downstream cleanup behavior**
- `global-effects_simplify-locals.wast` = **proof that the metadata changes downstream local-simplification behavior**

## What a future Starshine port must preserve

A future port should preserve:

- the public-vs-local naming split
- the shallow-summary plus transitive/SCC propagation structure
- conservative handling for imports, indirect calls, unknown effects, and recursive cycles
- the metadata storage site
- the downstream consumer contract
- the explicit possibility that summaries may need later invalidation/discard

For the exact local owner-file, registry, dispatcher, summary-model, and validation sequencing proposal, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Sources

- [`../../../raw/binaryen/2026-05-05-global-effects-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-global-effects-current-main-recheck.md)
- [`../../../raw/research/0480-2026-05-05-global-effects-current-main-recheck.md`](../../../raw/research/0480-2026-05-05-global-effects-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-global-effects-current-main-line-anchor-refresh.md`](../../../raw/binaryen/2026-05-05-global-effects-current-main-line-anchor-refresh.md)
- [`../../../raw/research/0490-2026-05-05-global-effects-current-main-line-anchor-refresh.md`](../../../raw/research/0490-2026-05-05-global-effects-current-main-line-anchor-refresh.md)
- [`../../../raw/binaryen/2026-05-04-global-effects-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-global-effects-current-main-recheck.md)
- [`../../../raw/research/0438-2026-05-04-global-effects-current-main-recheck.md`](../../../raw/research/0438-2026-05-04-global-effects-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md)
- [`../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md`](../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md)
- [`../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md`](../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md`](../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md)
