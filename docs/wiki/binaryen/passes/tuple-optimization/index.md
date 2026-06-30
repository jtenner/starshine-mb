---
kind: entity
status: supported
last_reviewed: 2026-06-30
sources:
  - ../../../raw/research/1384-2026-06-30-tuple-optimization-root-elision-fast-path.md
  - ../../../raw/research/1383-2026-06-30-tuple-optimization-no-copy-payload-fast-path.md
  - ../../../raw/research/1382-2026-06-30-tuple-optimization-no-scalar-forward-fast-path.md
  - ../../../raw/research/1381-2026-06-29-tuple-optimization-no-result-link-fast-path.md
  - ../../../raw/research/1380-2026-06-29-tuple-optimization-local-set-root-fast-path.md
  - ../../../raw/research/1379-2026-06-29-tuple-optimization-no-scalarized-prescan-performance.md
  - ../../../raw/research/1378-2026-06-29-tuple-optimization-no-new-local-cleanup-performance.md
  - ../../../raw/research/1377-2026-06-29-tuple-optimization-no-tee-cleanup-performance.md
  - ../../../raw/research/1376-2026-06-29-tuple-optimization-payload-facts-performance.md
  - ../../../raw/research/1375-2026-06-29-tuple-optimization-source-fast-path-performance.md
  - ../../../raw/research/1374-2026-06-29-tuple-optimization-elision-mask-performance.md
  - ../../../raw/research/1373-2026-06-29-tuple-optimization-targeted-root-removal.md
  - ../../../raw/research/1372-2026-06-29-tuple-optimization-use-def-reuse.md
  - ../../../raw/research/1371-2026-06-29-tuple-optimization-batched-root-removal.md
  - ../../../raw/research/1370-2026-06-29-tuple-optimization-aggregate-rewrite-timers.md
  - ../../../raw/research/1369-2026-06-29-tuple-optimization-scalarized-cleanup-fast-skip.md
  - ../../../raw/research/1368-2026-06-29-tuple-optimization-root-removal-rejected.md
  - ../../../raw/research/1367-2026-06-29-tuple-optimization-detached-delete-performance.md
  - ../../../raw/research/1366-2026-06-29-tuple-optimization-drop-only-elision-performance.md
  - ../../../raw/research/1365-2026-06-29-tuple-optimization-root-slot-lookup.md
  - ../../../raw/research/1364-2026-06-29-tuple-optimization-performance-attribution.md
  - ../../../raw/research/1363-2026-06-29-tuple-optimization-broader-profile-and-performance.md
  - ../../../raw/research/1362-2026-06-29-tuple-optimization-residual-scalar-spelling.md
  - ../../../raw/research/1358-2026-06-29-tuple-optimization-genvalid-profile.md
  - ../../../raw/research/0542-2026-05-06-tuple-optimization-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/research/0434-2026-05-04-tuple-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md
  - ../../../raw/research/0254-2026-04-22-tuple-optimization-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0239-2026-04-21-tuple-optimization-starshine-code-map-followup.md
  - ../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md
  - ../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md
  - ../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./implementation-map.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./scheduler-and-gates.md
  - ./reduced-repros-and-evidence.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `tuple-optimization`

## Role

- `tuple-optimization` is an active implemented **hot pass** on Starshine's explicit pass surface.
- In upstream Binaryen `version_129`, it is a narrow tuple-local cleanup pass that splits safe tuple scratch locals into scalar locals before later local-cleanup passes run.
- The pass is easy to overstate.
  - It is **not** a general multivalue optimizer.
  - It is **not** a broad CFG-driven tuple dataflow pass.
  - It is **not** the pass that folds direct `tuple.extract(tuple.make(...))`; Binaryen does that earlier in `optimize-instructions`.

## Why this dossier still needed a refresh

The tracker no longer had any pass with wiki status `none`, so this thread had to justify an already-`deep` fallback.
`tuple-optimization` was the best major-gap fallback because:

- it still matters on the canonical no-DWARF function path:
  - `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure`
- it also still appears repeatedly in the saved generated-artifact optimize log, including later nested `precompute-propagate -> code-pushing -> tuple-optimization` reruns
- the existing folder already had the required living pass pages, but it still lacked an immutable raw primary-source manifest tying the reviewed official release page, source files, and dedicated lit file together in the raw-source system
- several living pages still relied on 2026-04-20 / 2026-04-21 freshness wording without one compact 2026-05-04 provenance anchor that connected those upstream surfaces directly to the exact Starshine code map
- this refresh therefore closes a provenance-and-navigation gap, not a missing-overview or missing-strategy gap

So this refresh is not a tracker-status promotion.
It is a source-backed clarification pass over a real existing dossier.

## Most important durable takeaways

- Upstream Binaryen is optimizing **tuple locals**, not multivalue syntax in general.
- The pass approves only a narrow writer/reader surface:
  - writers from `tuple.make` or tuple-local copies
  - readers through `tuple.extract` or tuple-local copies
- Copy-connected tuple locals succeed or fail together.
  - If one member escapes, Binaryen poisons the whole component.
- Tee preservation is part of the core contract, not a corner case.
- The pass is deliberately lightweight.
  - It does **not** depend on CFG, effects, liveness, dominance, or refinalization helpers.
- The real payoff comes later.
  - `tuple-optimization` exposes scalar locals so later local passes can remove dead lanes and dead copies.
- A narrow 2026-05-04 freshness check found no current-main drift in the core upstream pass file, the dedicated lit suite, or the tuple-specific scheduler / peephole sections relevant to this dossier.
- The dossier now also has an immutable raw primary-source manifest recording that the reviewed official Binaryen `version_129` release page on 2026-04-22 showed publish date **2026-04-01**.

## Current status summary

- The explicit Starshine pass exists and is wired into the pass manager and CLI.
- The public `optimize` and `shrink` presets now include the pass in the documented `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> heap2local` neighborhood, but exact-slot evidence remains open.
- Current reduced native-compare coverage is green for committed regressions, a post-timer count-100 direct GenValid smoke compared `100 / 100` with `100` normalized matches and zero failures, and the root-slot lookup slice raised the ordinary direct smoke to `1000 / 1000` normalized matches.
- The dedicated `tuple-optimization-all` GenValid profile deliberately exposes active scalar-spelling residuals; the current simple type-indexed pure/drop-only profile surface is classified only as a narrow measured Starshine-win family, not final closeout.
- Candidate-heavy pass-local performance is an active closeout blocker. Detail timers attribute the dominant cost to TO-owned rewrite/cleanup work; use-def-bounded root-slot lookup, pure drop-only source elision, detached replacement deletes, a scalarized tuple-local cleanup fast-skip, aggregate rewrite timer emission, pass-level batched root removal, rewrite use-def reuse, targeted removable-root regions, fast root-region body replacement, precomputed pure/drop-only elision masks, source-only elision rewrite, no-copy rewrite-mask construction, precomputed payload facts, a no-local-tee cleanup fast path, a no-new-local cleanup fast path, a no-scalarized-prescan cleanup fast path, a local-set root elision fast path, a no-single-result-block result-link fast path, a no-scalar-forward link/rebuild fast path, a no-copy-payload exact-copy-link fast path, and now a narrow simple drop-only root-elision fast path improved the representative fixture trend to roughly `0.676ms`, `1.522ms`, and `2.933ms` at 500/1000/2000 pairs. A same-region root-removal experiment was rejected because per-group root splicing regressed the same fixtures; only the later pass-level batch/targeted cleanup was kept. Rewrite-mask construction, rewrite-time payload extraction, dropped-tee cleanup scanning, unused-body-local cleanup scanning, scalarized tuple-local cleanup pre-scanning, generic replacement for pure root-`local.set` elision, result-block copy linking for no-one-result-block fixtures, scalar-forward copy linking/rebuild for no-scalar-forward fixtures, exact block-payload copy linking for no-copy-payload fixtures, and now full query-summary/link/rewrite/precompute work for exact simple root-elision fixtures are no longer candidate-heavy owners for no-tee/no-copy/no-new-local/no-tuple-make/no-result-copy/no-scalar-forward/source-only fixtures; remaining seed collection, direct fast-path validation/root-region lookup, targeted root cleanup, and untraced pass overhead are still outside the pass-local target.
- Raw normalized WAT text is still too strict to use as the only tuple-opt parity oracle.

## Biggest beginner correction

The safe mental model is:

- Binaryen uses this pass to split **safe tuple scratch storage** into scalar locals early enough that later local-cleanup passes can do better work.

The unsafe mental model is:

- “tuple-optimization” is where Binaryen lowers all tuple or multivalue constructs.

That broader reading is not what the source file or test suite implement today.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Exact upstream `version_129` algorithm: early gates, `uses` / `validUses`, symmetric copy graph, badness propagation, contiguous scalar-local allocation, `MapApplier`, and tee-preserving rewrites.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - The upstream file map, helper dependencies, validation/finalize neighbors, official lit families, the immutable raw primary-source anchor, and the narrow current-main freshness note.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly catalog of the official positive and negative tuple-local shapes Binaryen rewrites or deliberately leaves alone, plus the HOT-native equivalents Starshine sees after lift.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - The current in-tree Starshine strategy page: exact direct-pass status, HOT-native strategy summary, and the shortest path to the code map.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - The deeper HOT-native implementation dossier, including the exact owner-file and line-location map for the main analysis, rewrite, wiring, and test surfaces.
- [`./implementation-map.md`](./implementation-map.md)
  - Exact MoonBit owner-file map for registry wiring, analysis clusters, rewrite clusters, cleanup clusters, and the focused wbtest / CLI / native-oracle lanes.
- [`./scheduler-and-gates.md`](./scheduler-and-gates.md)
  - Exact Binaryen slot, multivalue gate, and why the public Starshine presets still keep tuple-opt off even though the explicit pass exists.
- [`./reduced-repros-and-evidence.md`](./reduced-repros-and-evidence.md)
  - The reduced repro families that drove the Starshine implementation and the current evidence map for those families.
- [`./parity.md`](./parity.md)
  - The current signoff state: strong direct isolated parity, canonical full-artifact compare status, open preset-slot proof, and remaining runtime debt.

## Freshness note

The direct Starshine pass was revalidated on 2026-05-06 with the refreshed pass-fuzz harness, keeping explicit-pass parity green while leaving preset-slot proof separate.

The reviewed official Binaryen release page on 2026-05-04 still showed `version_129` as the stable oracle, and the fresh current-main bridge keeps that provenance explicit.
A narrow 2026-05-04 comparison against current GitHub `main` found:

- `src/passes/TupleOptimization.cpp` unchanged from `version_129`
- the relevant `pass.cpp` scheduler / registration lines unchanged
- the tuple-specific `OptimizeInstructions.cpp` peephole section unchanged, even though the file has unrelated drift elsewhere
- `test/lit/passes/tuple-optimization.wast` unchanged

That means the tuple-opt dossier does **not** currently need a current-main drift warning on its core upstream surfaces.

## Current maintenance rule

- Treat this folder as the canonical home for Binaryen tuple-opt behavior, scheduler meaning, Starshine HOT-native strategy, exact local code ownership, and parity notes.
- Keep the main beginner correction explicit:
  - upstream `tuple-optimization` is a tuple-local scratch-storage splitter, not a generic multivalue optimizer.
- Keep the division of labor explicit between:
  - `optimize-instructions` handling direct `tuple.extract(tuple.make(...))`
  - `tuple-optimization` splitting safe tuple locals
  - later local-cleanup passes realizing the scalarization payoff
- If new work only changes raw normalized WAT while canonical per-function compare stays green, classify that as compare-surface or materialization noise first, not immediately as a tuple-opt semantic regression.
- Keep [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) and [`./implementation-map.md`](./implementation-map.md) in sync whenever a fix moves the owning helper cluster or the owning local test lane.

## Sources

- [`../../../raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-22-tuple-optimization-primary-sources.md)
- [`../../../raw/research/0254-2026-04-22-tuple-optimization-primary-sources-and-code-map-followup.md`](../../../raw/research/0254-2026-04-22-tuple-optimization-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0239-2026-04-21-tuple-optimization-starshine-code-map-followup.md`](../../../raw/research/0239-2026-04-21-tuple-optimization-starshine-code-map-followup.md)
- [`../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md`](../../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md)
- [`../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md`](../../../raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md)
- [`../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md`](../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md)
- [`../../../../../src/passes/tuple_optimization.mbt`](../../../../../src/passes/tuple_optimization.mbt)
- [`../../../../../src/passes/tuple_optimization_wbtest.mbt`](../../../../../src/passes/tuple_optimization_wbtest.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../src/cmd/cmd_native_wbtest.mbt`](../../../../../src/cmd/cmd_native_wbtest.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast>
