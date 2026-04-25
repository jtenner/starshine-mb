# Binaryen `merge-locals` current-main source correction

_Capture date:_ 2026-04-25  
_Status:_ immutable source-correction manifest for `docs/wiki/binaryen/passes/merge-locals/`

## Scope

This manifest captures the primary online sources re-read after the living `merge-locals` dossier still taught a stale 2026-04-23 algorithm story.
The correction is substantive: the reviewed Binaryen `version_129` and current-`main` implementation is the older **single-set local grouping / optional fresh-temp** pass, not the later dossier's **simple-root-set plus EquivalentCopies / LocalStructuralDominance** proof.

Use the living dossier pages for the maintained explanation:

- `docs/wiki/binaryen/passes/merge-locals/index.md`
- `docs/wiki/binaryen/passes/merge-locals/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/merge-locals/local-graph-and-copy-influences.md`
- `docs/wiki/binaryen/passes/merge-locals/wat-shapes.md`
- `docs/wiki/binaryen/passes/merge-locals/starshine-strategy.md`

## Official sources consulted

### Release / source anchors

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Re-checked on 2026-04-25.
  - The release page had already been observed in this repo as published on **2026-04-01**.
- `MergeLocals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/local-graph.h>

### Official lit tests

- `merge-locals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-locals.wast>

## Durable source-backed corrections

- `merge-locals` is a function pass whose implementation still starts by skipping functions with local names. The earlier 2026-04-23 dossier claim that the local-name bailout was gone and replaced by an `invalidatesDWARF()` contract was wrong for the reviewed sources.
- The implementation constructs `LocalGraph graph(getFunction(), false)` and calls `computeInfluences()` plus `computeSetInfluences()`. The source comment records that non-lazy graph construction was chosen because laziness missed opportunities and had worse benchmark behavior.
- The candidate locals are locals with exactly one set in `graph.sets`, where the set has a value and all influenced gets point back to that same set. This is a one-set-local rule, not a root-set plus `EquivalentCopies` rule.
- The value safety gate is `FunctionUtils::isSimple(set->value)`. Complex or effectful producers stay out of the pass.
- If the one set is a `local.get` from a chain small enough to reuse, Binaryen can reuse that existing source local as the group's target. Otherwise it creates a fresh temp via the module builder, emits a new `local.set` to that temp, rewrites influenced gets to the temp, and removes redundant sets.
- The reviewed `MergeLocals.cpp` does not use `LocalStructuralDominance`, an `EquivalentCopies` helper, or `pass-utils.h` for the living-dossier algorithm. Those names belonged to the repo's prior overread, not the source-backed `version_129` / current-main contract.
- `pass.cpp` still inserts `merge-locals` only when `options.optimizeLevel >= 3 || options.shrinkLevel >= 2`, after `heap2local` and before `optimize-casts`, `local-subtyping`, `coalesce-locals`, `local-cse`, and `simplify-locals` in the default function-optimization cluster.
- The official `merge-locals.wast` file directly covers the main families the corrected living pages now teach: simple single-set positives, branching / arity and ordering-sensitive cases, complex-value bailouts, loop and DAG-like influence cases, and the `between-unreachable` conservative case.
- A focused current-`main` recheck on 2026-04-25 found no teaching-relevant drift from the corrected `version_129` description.

## Contradictions and supersession

This manifest supersedes the interpretive claims in:

- `docs/wiki/raw/research/0128-2026-04-20-merge-locals-binaryen-research.md` where they describe a local-name bailout plus one-set/fresh-temp strategy only partly and without the later dossier context.
- `docs/wiki/raw/research/0272-2026-04-23-merge-locals-primary-sources-and-source-correction-followup.md` where they reject the one-set/fresh-temp and local-name-bailout story in favor of a non-source-backed `EquivalentCopies` / `LocalStructuralDominance` model.
- `docs/wiki/raw/binaryen/2026-04-23-merge-locals-primary-sources.md` only for its “durable observations” section. Keep that older file as provenance for the URLs it captured, but do not use its algorithm summary as the maintained explanation.

## Consumability rule

Future `merge-locals` updates should cite this manifest together with the living dossier and should not reintroduce the `EquivalentCopies` / `LocalStructuralDominance` story unless a future Binaryen source change actually adds that machinery to `MergeLocals.cpp`.
