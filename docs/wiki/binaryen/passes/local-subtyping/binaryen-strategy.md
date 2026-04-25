---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# Binaryen `local-subtyping` strategy

## Upstream source rule

- Use Binaryen `version_129` as the tagged source oracle for this pass.
- Use [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md) as the strongest current provenance note.
- The 2026-04-25 recheck found no teaching-relevant current-main drift from `version_129`, but it did find that this repo's 2026-04-22 summary overcorrected the pass into a smaller set-only story.

Primary source URLs:

- Binaryen `version_129` `LocalSubtyping.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` `lubs.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- Binaryen `version_129` `local-structural-dominance.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-structural-dominance.h>
- Binaryen `version_129` `local-subtyping.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>

## High-level intent

Binaryen uses `local-subtyping` to refine eligible local declarations to narrower reference types when assignments prove that narrower type is safe.

The precise source-backed contract is:

- function-parallel, GC-gated pass
- scan relevant reference-typed locals
- collect both assigned sites and get sites
- compute candidate declaration types from set/tee value LUBs
- keep non-null candidates only when structural dominance proves the gets are safe
- rewrite **body-local** declarations, not parameters
- retag `local.get` and `local.tee` expression types
- refinalize and repeat while new declarations expose more precise evidence

It is not:

- a general all-value local type-inference pass
- a pass that rewrites parameters
- a tuple/multivalue local reshaper
- a generic `LocalUpdater` / copy-local insertion engine
- a pass whose get handling can be dismissed as nonexistent

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| GC gate | Skip unless GC is enabled | The pass is about reference locals and GC type precision. |
| Relevant-local scan | Mark locals whose current type is a reference | Avoids numeric/vector locals and most tuple-like locals. |
| Set/get collection | Store set/tee sites and get sites per relevant local | Assignments drive candidate types; gets drive dominance and repair. |
| Iterative refinalization | Refinalize between rounds after the first change | Earlier declaration changes can sharpen later set-value types. |
| LUB candidate | Compute a LUB over assigned value types | Picks one common safe declaration type. |
| Non-null gate | Require dominance for nondefaultable/non-null candidates | Prevents undominated gets from observing a null state through a non-null declaration. |
| Declaration rewrite | Rewrite locals from `getVarIndexBase()` onward | Preserves params while changing body locals. |
| Expression retagging | Retag gets and tees to the new declaration when safe | Keeps expression typing aligned with declarations. |

## Phase 1: scheduler placement and gating

Binaryen schedules `local-subtyping` inside the GC local-cleanup cluster:

`heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`

That placement is semantic, not cosmetic:

- `optimize-casts` can expose better reference assignment types first.
- `local-subtyping` tightens declarations before exact-type-only coalescing freezes opportunities.
- `coalesce-locals`, `local-cse`, and `simplify-locals` consume the cleaner local type traffic later.

## Phase 2: relevant locals are reference locals

The scanner looks for locals whose current type is a reference type. That is the practical support gate visible in the owner file.

Important nuance: the scanner currently has a TODO about ignoring parameters. So the scan surface can include params, but the rewrite phase later starts from `getVarIndexBase()` and leaves params unchanged.

## Phase 3: sets and gets are both recorded

This is the 2026-04-25 correction.

The pass records:

- `local.set` / `local.tee` sites for relevant locals
- `local.get` sites for relevant locals

The assigned sites feed candidate LUBs. The get sites are used for non-null dominance and for expression-type repair after a declaration changes.

So the right phrase is:

> set-fed LUBs plus get-aware dominance/type repair.

## Phase 4: candidate types come from assigned values

For each local with recorded sets, Binaryen creates a `LUBFinder` and observes each assigned value type.

That means:

- one set to a child type can narrow a wide local to that child type;
- two sibling child writes can narrow only to their common parent;
- gets by themselves do not ask for a narrower declaration;
- locals with no sets are skipped today, even though the source has a TODO that always-null locals could be optimized someday.

## Phase 5: non-nullability is dominance-gated

If the candidate is nondefaultable, Binaryen keeps it only when it is a non-null reference and all relevant gets are dominated by the writes that establish that non-null value.

The important helper is `LocalStructuralDominance(...).getNonDominatingIndices(...)`.

If any get is not dominated, Binaryen falls back to the nullable version for the declaration and remembers which gets must keep the old nullable expression type.

## Phase 6: only body-local declarations are rewritten

The declaration rewrite loop starts at the function's body-local base. That preserves the function signature and parameter ABI.

This split matters for future Starshine work:

- do not say “the pass ignores params entirely”;
- do say “params are not rewritten by the declaration update.”

## Phase 7: get and tee expression types are repaired

When a local's declaration changes, Binaryen updates expression types too:

- safe `local.get` sites take the new declaration type;
- non-dominated gets can keep the older nullable type;
- `local.tee` expression types are updated to the local declaration type.

That is why a port cannot stop at changing the local declaration table.

## Phase 8: repeated refinement is part of the contract

After a successful declaration rewrite, the pass refinalizes before rescanning. This can make assigned value types more precise, which can unlock another local's refinement.

The dedicated lit file includes repeated-refinement coverage, so this is not an implementation accident.

## What the pass does not do

A future Starshine port should avoid broadening the first implementation beyond the source-backed contract.

Binaryen `version_129` `local-subtyping` does **not**:

- rewrite params
- rewrite numeric/vector locals
- reshape tuple locals
- choose candidate types from gets alone
- insert helper copy locals
- use a generic `LocalUpdater(...).changeType(...)` pass body
- run outside the GC feature gate

## Porting lessons

If Starshine ports `local-subtyping`, preserve these first:

1. GC-gated scheduler placement after `optimize-casts` and before `coalesce-locals`.
2. relevant reference-local scan.
3. set/tee-fed LUB candidate selection.
4. get-aware dominance and expression-type repair.
5. parameter-preserving body-local declaration rewrite.
6. non-null candidates falling back to nullable when dominance fails.
7. iterative refinalization/reanalysis until stable.
8. exact tests for parameter, nondefaultable, tee, repeated-refinement, and scheduler-neighborhood behavior.

## Sources

- [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
