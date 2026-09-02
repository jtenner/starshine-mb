---
kind: entity
status: supported
last_reviewed: 2026-09-01
sources:
  - ../../release-horizon-and-oracles.md
  - ../code-pushing/index.md
  - ../../../../../src/passes/tuple_optimization.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/tuple_optimization_wbtest.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_lower_wbtest.mbt
  - ../../../../../src/passes_perf_long/tuple_optimization_perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../late-pipeline-dispatch.md
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

## 2026-09-01 production candidate-free raw gate

The canonical 4,977,401-byte artifact contained thousands of scalar-only functions that could not form a TupleOptimization seed group, but the dispatcher still lifted each function, built use-def, and ran both root-group scans. A new fail-closed raw classifier recursively checks every nested instruction sequence for a static multi-result producer. It resolves direct and indirect/reference call signatures plus type-indexed `block`, `loop`, `if`, and `try_table` results through the cached module context; any unresolved signature is treated as a possible candidate and falls back to the full HOT path.

The candidate-free check runs before the older ownership-hazard probes, making scalar-only functions one-scan no-ops while preserving the hazard fallbacks whenever a real multivalue producer exists. On the production artifact, 11,767 functions take the candidate-free skip, 86 retain the effect-bracketed-call skip, 13 retain the load/call/set skip, and only 133 enter HOT lifting and the pass. Red-first tests lock both the scalar hazard ordering and the multivalue hazard fallback. A production-derived 2,000-function native-release benchmark fail-closes unless every scalar function takes the raw skip and measures `1.34ms ± 9.46us` on the AMD Ryzen 7 8845HS with MoonBit `0.1.20260713`.

Matched clean-HEAD/current one-warmup/three-sample medians reduce no-trace command `2,502.949ms -> 897.562ms` (`2.789x`, `-64.140%`), pass-local `302.034ms -> 8.113ms` (`37.228x`), HOT lift `642.690ms -> 8.197ms` (`78.406x`), and the optimizer pipeline `1,772.302ms -> 181.221ms` (`9.780x`). Paired current Binaryen v131 is `501.621ms` command / `3.709ms` pass-local; Starshine's `1.789x` command ratio clears the `<=1.053s` absolute gate by `155.438ms`. The remaining low-absolute candidate-heavy pass ratio remains covered by the existing 2026-06-30 soft acceptance.

Every measured output is byte-identical to the pre-change 4,976,841-byte result at SHA-256 `4b616a392d85a2c2dbf52ea08b27ad99cc07351a166838c0eaab2d9d6733d172`. Regular explicit-v131 GenValid is `10000/10000` normalized with equal canonical bytes and zero failures. The dedicated 10,000-case profile still produces the established pure/drop-only scalar-spelling family: all cases validate, Starshine is canonically smaller in all 10,000, and there are no property, generator, or command failures. `[P0-WALL-TUPLE]` is closed.

Evidence lives under `.tmp/tuple-production-baseline-matched-20260901-*`, `.tmp/tuple-production-final-clean-20260901-*`, `.tmp/pass-fuzz-tuple-final-clean-regular-10000-20260901`, and `.tmp/pass-fuzz-tuple-final-clean-dedicated-10000-20260901`. The final native binary is SHA-256 `bbfa580e0e1fdcf267a1e0c313498df8f90a911b923dedd0cd40fe6c36c71cca`.

## 2026-09-01 Moon component benchmark and shared HOT lower suffix index

A reusable native-release benchmark now reconstructs the established candidate-heavy contract as one function with 2,000 independent two-lane type-indexed pure/drop-only spills. It separately measures HOT lift, lowering after TupleOptimization, and the registry-dispatched pipeline. Across five matched clean-`04adcce0e`/current runs, median mean lift is neutral (`39.14ms -> 39.18ms`), HOT lower improves `467.70ms -> 11.41ms` (`-97.560%`, `40.990x`), and the complete pass pipeline improves `522.63ms -> 88.72ms` (`-83.024%`, `5.891x`).

The lowerer owner was the future-root dependency proof: every local-reading root could rescan all later roots even when no later root contained an effectful value created before the current root. Large regions now build one memoized minimum dependency id per node and one suffix minimum over region roots. The minimum deliberately traverses beneath later impure parents because the original threshold-sensitive collector does so when the parent itself is not old enough; regions below 64 roots retain the original exact scan. Red-first white-box coverage locks pure roots, direct earlier effects, nested earlier effects beneath later impure parents, and the region local-read gate. The first incomplete fallback experiment changed call order on the production artifact and was rejected; the final optional-index fallback restores exact bytes.

This is a synthetic shared-lowerer win, not a production-artifact speedup. Final one-warmup/three-pair production medians preserve the 4,976,841-byte raw output at SHA-256 `4b616a392d85a2c2dbf52ea08b27ad99cc07351a166838c0eaab2d9d6733d172`: clean/current no-trace is `1945.067ms -> 1955.632ms`, pass-local `268.023ms -> 272.397ms`, lift `568.033ms -> 575.643ms`, and lower `9.572ms -> 9.675ms`, all neutral host noise. Paired Binaryen v131 was `510.266ms` process / `3.713ms` pass-local, so `[P0-WALL-TUPLE]` remained open at this checkpoint; the production candidate-free raw gate documented above supersedes that status and closes it. Regular explicit-v131 GenValid is `10000/10000` normalized with zero failures and equal canonical bytes; the shared RUB recheck is `278` normalized plus `9722` cleanup-normalized with zero residual mismatches or failures.

## Binaryen v131 renewal status

Closed on July 28, 2026. `TupleOptimization.cpp` is byte-identical between v130 and v131 at SHA-256 `2809e78bb844a8a910c68def6caabaa7ddfcb8df4e3103d5d83ae9beb474e264`. The dedicated lit delta changes four bottom-valued `local.tee` expectations to `local.set` in the unreachability families; the tuple-local analysis and scalarization owner did not change.

A focused v131 source-WAT probe confirmed the new Binaryen `local.set` spelling. After wasm serialization, both Binaryen and Starshine canonicalize the reduced `unreachable.tuple.extract` probe to the same valid 30-byte `unreachable` function. Focused tuple tests pass `56/56`; explicit-v131 ordinary GenValid is `1000/1000` exact. A 100-case dedicated profile reproduces only the already approved pure/drop-only scalar-spelling wins: all 100 cases have zero effects/traps, Starshine is smaller in every case (`-22` bytes for spill; `-20` for tee and copy-chain), and there are no validation, property, generator, or command failures. No implementation slice is opened.

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
- Direct tagged source URLs plus the retained 2026-05-04 current-main recheck record that the reviewed official Binaryen `version_129` release page observed on 2026-04-22 showed publish date **2026-04-01**.

## Current status summary

- The explicit Starshine pass exists and is wired into the pass manager and CLI.
- The public `optimize` and `shrink` presets now include the pass in the documented `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> heap2local` neighborhood. The historical large debug artifact is absent in this workspace, but the available candidate-heavy exact-slot neighborhood replay is green under normalized WAT and canonical function comparison.
- Final direct-pass closeout completed on 2026-06-30: regular GenValid `100000 / 100000` normalized with zero failures; random all-profiles `10000 / 10000` normalized with zero failures; wasm-smith had one unreachable-control-debris raw mismatch and known Binaryen/tool command failures, with the raw mismatch reduced by the documented normalizer.
- The dedicated `tuple-optimization-all` GenValid profile deliberately remains raw-red (`10000 / 10000`) but is now classified as a narrow measured Starshine-win scalar-spelling family for simple type-indexed pure/drop-only spill/tee/copy-chain cases: no effect/trap facts and uniform raw/text/local/op wins for Starshine across all sampled cases.
- Candidate-heavy pass-local performance is soft-accepted under the user's 2026-06-30 caveat after reasonable TO-owned optimizations were exhausted. Final measured direct timings are `0.122/0.037`, `0.460/0.148`, `0.892/0.301`, and `1.705/0.580` ms at 100/500/1000/2000 pairs.
- Raw normalized WAT text is still too strict to use as the only tuple-opt parity oracle.

## 2026-08-28 shared HOT lift checkpoint

The order-of-magnitude inventory attributed most artifact-scale command overhead around this pass to shared HOT lifting rather than the tuple transform alone. The retained IR checkpoint now:

- derives defined-function indices without rescanning imports;
- preserves compressed local declaration runs for validation;
- reuses known function results and builds one validation environment;
- allocates the initial all-initialized local bitmap by compressed length;
- caches repeated scalar and simple block-result type IDs without repeated string construction.

An alternating clean-HEAD/current comparison on the canonical 4,977,401-byte artifact reduces median HOT lift from `1,067.202ms` to `595.670ms` (`-44.2%`) and no-trace command from `2,762.360ms` to `2,264.276ms` (`-18.0%`), while tuple pass-local time remains neutral at about `285.3ms`. All paired outputs are byte-identical at 4,976,841 bytes, SHA-256 `4b616a392d85a2c2dbf52ea08b27ad99cc07351a166838c0eaab2d9d6733d172`.

The shared change also reduces single-sample lift attribution from the inventory baselines for RemoveUnusedNames (`822.383ms` to `432.602ms`), Heap2Local (`1,600.031ms` to `862.847ms`), and SimplifyLocalsNoNesting (`1,617.657ms` to `857.347ms`). These are cross-pass smoke comparisons, not replacement medians for each pass dossier.

Moon validation is 1,753/1,753 validate-package, 366/366 IR-package, 7,047/7,047 pass-package, and 10,737/10,737 full. The renewed ordinary tuple lane is 10,000/10,000 normalized with zero failures or mismatches; runtime-callable self semantics are exact 100/100. TupleOptimization remains an open wall-time P0 because its transform and function/pre-pass envelope still dominate the remaining gap.

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

- research note 0254
- research note 0239
- research note 0144
- research note 0076
- [research note 0115](../code-pushing/index.md)
- [`../../../../../src/passes/tuple_optimization.mbt`](../../../../../src/passes/tuple_optimization.mbt)
- [`../../../../../src/passes/tuple_optimization_wbtest.mbt`](../../../../../src/passes/tuple_optimization_wbtest.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../src/cmd/cmd_native_wbtest.mbt`](../../../../../src/cmd/cmd_native_wbtest.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [research note 0093](../late-pipeline-dispatch.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
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
