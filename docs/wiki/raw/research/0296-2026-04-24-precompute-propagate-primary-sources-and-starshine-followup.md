# Binaryen `precompute-propagate` primary sources and Starshine follow-up

Date: 2026-04-24

## Scope

This note records the 2026-04-24 follow-up for the `precompute-propagate` dossier.

The folder already had the required upstream overview, Binaryen strategy, transformed-shape catalog, and a focused local-worklist page. It still had two durable gaps:

- no immutable raw primary-source manifest for the official Binaryen sources reviewed for this pass, and
- no dedicated Starshine status / port-strategy page tying the upstream contract back to exact local code locations.

This follow-up closes those gaps without changing the pass's implementation status.

## Candidate selection result

Chosen pass: `precompute-propagate`

Why it was still eligible:

- it is a real public upstream Binaryen pass name;
- it is named in Starshine's local removed-name registry;
- it already influences neighboring `precompute`, `dae-optimizing`, `inlining-optimizing`, and `simplify-globals-optimizing` docs through the nested-rerun rule;
- it had a mature dossier, but lacked the same raw-source and Starshine-follow-along bridge already added to many neighboring folders.

## Sources reviewed

### Local repo sources

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/raw/research/`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/precompute-propagate/`
- `docs/wiki/binaryen/passes/precompute/`
- `src/passes/optimize.mbt`
- `src/passes/precompute.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/registry_test.mbt`
- `src/passes/optimize_test.mbt`
- `src/passes/precompute_test.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`

### Official Binaryen online sources

- Binaryen GitHub release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen GitHub releases index: <https://github.com/WebAssembly/binaryen/releases>
- `src/passes/Precompute.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
- `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/local-graph.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- `src/ir/properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `src/wasm-interpreter.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
- `test/lit/passes/precompute-propagate-partial.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
- `test/lit/passes/precompute-propagate_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>

A narrow current-`main` spot check covered the same owner/helper/test URLs under the `main` branch and did not surface a teaching-relevant drift for the selected sibling beyond the living pages' current claims.

## Main findings

## 1. The upstream provenance gap is now closed

Added `docs/wiki/raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md`.

The manifest captures:

- the official `version_129` release page and releases index reviewed on 2026-04-24;
- the owner file `Precompute.cpp`;
- public registration / scheduling sources `pass.cpp` and `opt-utils.h`;
- helper files `local-graph.h`, `properties.h`, and `wasm-interpreter.h`;
- the two dedicated propagate lit files;
- the current-`main` spot-check result.

The manifest also records that the official release page showed publish date **2026-04-01 14:31** on 2026-04-24.

## 2. The Starshine status is removed-name-only, not an active variant of local `precompute`

The exact local status is:

- `src/passes/optimize.mbt` lists `precompute-propagate` in `pass_registry_removed_names()`.
- `src/passes/precompute.mbt` exposes only `precompute_descriptor()` and `precompute_run(...)`; there is no separate descriptor, mode flag, or `precompute-propagate` entry point.
- `src/passes/pass_manager.mbt` dispatches only the active hot pass name `precompute`; a direct `precompute-propagate` run is rejected through the removed-name registry path before any hot dispatch.
- `src/passes/registry_test.mbt` proves the active `precompute` descriptor and the generic removed-name rejection lane, but it does not claim an active sibling implementation.

That local truth matters because several upstream-neighbor docs mention `precompute-propagate` as a nested cleanup. Those mentions should not imply Starshine already has the nested sibling locally.

## 3. Starshine's plain `precompute` is the reusable landing zone, but it is currently narrower than the upstream sibling

The active local code in `src/passes/precompute.mbt` is still useful future infrastructure:

- exact i32/i64 constant-source helpers;
- immutable scalar/global folding;
- trap-averse unary/binary integer folds;
- constant-`if` arm picking;
- pure dropped-value cleanup;
- region/root cleanup; and
- a local HOT fixpoint driver.

But a future `precompute-propagate` port would still need to add a new local-flow layer, not just register an alias.

Missing pieces include:

- `LazyLocalGraph`-equivalent get/set influence analysis;
- fallthrough-value extraction for set values;
- all-reaching-sets consensus for gets;
- defaultable-local entry constants with param/nondefaultable bailouts;
- a get-values map visible to a second evaluator walk;
- a shared semantic evaluator broad enough to consume those facts;
- a nested optimizing-rerun scheduler for `dae-optimizing` / `inlining-optimizing`-style rewrites.

## 4. The local scheduler distinction stays important

Local preset tests still prove that `optimize` and `shrink` replay plain `precompute` in both modeled PC slots.

That is different from upstream aggressive or nested optimizing schedules, where Binaryen uses `precompute-propagate` as the more aggressive sibling. The Starshine strategy page now records that distinction so future scheduler work has one page to read before wiring nested reruns.

## 5. Existing `precompute` artifact-hardening work should not be misattributed to `precompute-propagate`

The `precompute` dossier already records generated-artifact slot-19 and rooted slot-43 hardening. This follow-up keeps the ownership explicit:

- those are local plain-`precompute` / HOT-lower / writeback-validation facts;
- they do not mean Starshine already implements Binaryen's `precompute-propagate` local-flow phase;
- they do give a future port a tested writeback-safety environment to reuse.

## Living-doc consequences

This follow-up supports:

- adding the raw primary-source manifest;
- adding `docs/wiki/binaryen/passes/precompute-propagate/starshine-strategy.md`;
- refreshing the landing, Binaryen strategy, implementation/test map, local-worklist, and WAT-shape pages to cite the manifest and status page;
- updating the pass catalog, tracker, global wiki index, changelog, and log.

## Open questions / uncertainties

- The follow-up did not run a full semantic diff between Binaryen `version_129` and current `main`; it only performed a narrow current-`main` source/test spot check on the owner/helper/test surfaces used by this dossier.
- The future local design still has an unresolved shape question: whether to generalize the existing scalar HOT `precompute` evaluator first or build a separate local-flow propagation layer first. The strategy page recommends keeping the public registry split honest either way.
- Starshine does not yet have a dedicated backlog slice for `precompute-propagate`; nearby `[PC]`, `[DAE]`, and `[INL]` notes mention it only as a distinction or nested-rerun dependency.

## Source URLs

- Raw manifest added in this follow-up: `docs/wiki/raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md`
- Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` `Precompute.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` `precompute-propagate-partial.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
- Binaryen `version_129` `precompute-propagate_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate_all-features.wast>
