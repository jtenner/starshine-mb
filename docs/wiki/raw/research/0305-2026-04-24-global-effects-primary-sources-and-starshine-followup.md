# `global-effects` primary sources and Starshine follow-up

Date: 2026-04-24

## Scope

This follow-up refreshes the existing `global-effects` / upstream `generate-global-effects` dossier after the broader pass-wiki campaign established a repeatable pattern for source manifests and Starshine status bridges.

The existing folder already had the required overview, Binaryen strategy, implementation/test map, metadata-consumer guide, and shape catalog. The durable gaps were:

- no immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`
- no dedicated Starshine status / future-port strategy page
- direct online-source citations still embedded in living pages instead of going through a committed manifest
- no current-`main` drift note for the owner-file propagation refactor

## Sources reviewed

### Local repo sources

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/0168-2026-04-21-global-effects-binaryen-research.md`
- `docs/wiki/binaryen/passes/global-effects/`
- `src/passes/optimize.mbt`
- `src/cli/cli_test.mbt`
- `src/ir/effects.mbt`
- `src/ir/analysis_cache.mbt`
- `src/passes/pass_common.mbt`
- `src/passes/simplify_locals.mbt`
- `src/passes/heap_store_optimization.mbt`
- `agent-todo.md`

### Primary online sources

Captured in [`../binaryen/2026-04-24-global-effects-primary-sources.md`](../binaryen/2026-04-24-global-effects-primary-sources.md):

- official Binaryen `version_129` release page
- `src/passes/GlobalEffects.cpp` at `version_129` and current `main`
- `src/passes/pass.cpp` at `version_129`
- `src/ir/effects.h` at `version_129`
- `src/wasm.h` at `version_129`
- `test/lit/passes/vacuum-global-effects.wast` at `version_129`
- `test/lit/passes/global-effects_simplify-locals.wast` at `version_129`

## Main findings

## 1. The existing high-level dossier was directionally right, but the raw-source layer was missing

The 2026-04-21 dossier already captured the right reader-facing model:

- upstream public name: `generate-global-effects`
- local compatibility name: `global-effects`
- metadata producer rather than direct code rewriter
- downstream value through later effect-sensitive passes
- not part of the current canonical no-DWARF default path

The 2026-04-24 improvement is mostly provenance and follow-along completeness: the new raw manifest gives future readers a stable source checklist, records current-main drift, and centralizes the source-backed contradiction around the stale owner-file comment that mentions `PassOptions` despite the implementation writing `Function.effects`.

## 2. `version_129` has a more concrete algorithm than the older summary implied

The older dossier described a shallow scan plus reverse-call-graph fixed point. That remains useful for beginners, but the reviewed owner file supports a sharper implementation map:

1. analyze defined functions in parallel
2. build a `FuncInfo` record with a shallow `EffectAnalyzer`, direct callees, and an `unknownEffects` flag
3. clear ordinary call effects from the shallow summary while recording direct static calls separately
4. mark unknown / indirect-call effects conservatively
5. compute transitive static callees
6. mark callers of recursive chains as trapping
7. merge callee summaries into each caller
8. write the result into `Function.effects`

This is still metadata-only, but it is not merely “copy callee masks backward.” Unknown effects and recursion/trap behavior are part of the real contract.

## 3. Current Binaryen `main` changed the propagation implementation shape

A narrow 2026-04-24 current-`main` spot check found teaching-relevant owner-file drift:

- `version_129` uses a deferred reachability queue over function infos and then merges effects from computed transitive callees.
- current `main` builds an explicit call graph, runs SCC discovery, processes components in reverse topological order, aggregates component effects, and applies them back to member functions.

This is a source-structure drift, not a discovered semantic contradiction in the reviewed surfaces. The living Binaryen strategy page now teaches the `version_129` algorithm first, then warns current-`main` readers about the SCC refactor.

## 4. Starshine has local effect-mask infrastructure, but not the Binaryen pass

Local status after the 2026-04-24 recheck:

- `src/passes/optimize.mbt` includes `global-effects` in `pass_registry_boundary_only_names()`.
- Request expansion rejects boundary-only passes before a pipeline run.
- `src/cli/cli_test.mbt` only proves `--global-effects` is accepted as a pass flag.
- `src/ir/effects.mbt` classifies HOT nodes into coarse masks including `EFFECT_MASK_GLOBAL_STATE`, `EFFECT_MASK_CALL`, traps, memory, table, and local state.
- `src/ir/analysis_cache.mbt` and `src/passes/pass_common.mbt` cache function-local `HotEffectsSummary` data by HOT revision.
- `src/passes/simplify_locals.mbt` and `src/passes/heap_store_optimization.mbt` consume local effect masks for reordering safety.
- No Starshine module-level summary store equivalent to Binaryen `Function.effects` was found.
- No dedicated owner file, module dispatcher case, active preset slot, or backlog slice was found.

So the correct local bridge is: Starshine has reusable local effect-mask ingredients, but a faithful `global-effects` port would require new module-level interprocedural metadata production and lifecycle handling.

## 5. Future-port rule

A future Starshine implementation should not be added as a HOT peephole. The pass's real unit of work is the module call graph plus per-function metadata:

- discover direct calls from module functions
- model imported / indirect / unknown call surfaces conservatively
- compute transitive or SCC-propagated summaries
- expose those summaries to later effect queries
- invalidate or discard them when later transforms mutate effects

Until that exists, `global-effects` should remain boundary-only.

## Pages updated

- [`../../binaryen/passes/global-effects/index.md`](../../binaryen/passes/global-effects/index.md)
- [`../../binaryen/passes/global-effects/binaryen-strategy.md`](../../binaryen/passes/global-effects/binaryen-strategy.md)
- [`../../binaryen/passes/global-effects/implementation-structure-and-tests.md`](../../binaryen/passes/global-effects/implementation-structure-and-tests.md)
- [`../../binaryen/passes/global-effects/metadata-naming-and-consumers.md`](../../binaryen/passes/global-effects/metadata-naming-and-consumers.md)
- [`../../binaryen/passes/global-effects/wat-shapes.md`](../../binaryen/passes/global-effects/wat-shapes.md)
- [`../../binaryen/passes/global-effects/starshine-strategy.md`](../../binaryen/passes/global-effects/starshine-strategy.md)
- [`../../binaryen/passes/index.md`](../../binaryen/passes/index.md)
- [`../../binaryen/passes/tracker.md`](../../binaryen/passes/tracker.md)
- [`../../index.md`](../../index.md)
- [`../../log.md`](../../log.md)

## Remaining questions

- Should a future Starshine pass store interprocedural effects in the module data model, in a pass-manager side table, or in an analysis cache keyed by module revision?
- Should Starshine mirror upstream's `discard-global-effects` public lifecycle sibling or treat summary invalidation as internal pass-manager behavior?
- If Starshine eventually ports this, should it follow `version_129`'s deferred transitive-closure shape for parity with release oracle tests, or the current-`main` SCC component shape for maintainability?
