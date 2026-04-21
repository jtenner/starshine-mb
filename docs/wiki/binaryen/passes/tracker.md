---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../../src/passes/optimize.mbt
  - ../no-dwarf-default-optimize-path.md
  - ../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md
  - ../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md
  - ../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md
  - ../../raw/research/0132-2026-04-20-precompute-binaryen-research.md
  - ../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md
  - ../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md
  - ../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md
  - ../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
  - ../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md
  - ../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md
  - ../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md
  - ../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md
  - ../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md
  - ../../raw/research/0142-2026-04-20-reorder-locals-binaryen-research.md
  - ../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md
  - ../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md
  - ../../raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md
  - ../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md
  - ../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md
  - ../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md
  - ../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
  - ../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md
  - ../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md
  - ../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md
  - ../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md
  - ../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md
  - ../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md
  - ../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md
  - ../../../../agent-todo.md
related:
  - ./index.md
  - ./late-pipeline-dispatch.md
  - ../no-dwarf-default-optimize-path.md
---

# Binaryen Pass Wiki / Implementation Tracker

This page is the durable answer to two recurring questions:

1. which Binaryen-adjacent passes are already **implemented** in Starshine?
2. which passes have already been **wiki-ified** enough to guide more work?

## Source-of-truth rule

Use these files in this order:

- `src/passes/optimize.mbt`
  - source of truth for whether a pass is currently `HotPass`, `ModulePass`, `Removed`, or `BoundaryOnly`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - source of truth for which passes matter for the canonical no-DWARF `-O` / `-Os` Binaryen parity path
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
  - source of truth for which unimplemented passes were actually observed as skipped in the saved generated-artifact `-O4z` replay
- `docs/wiki/binaryen/passes/`
  - source of truth for whether a pass has a dedicated living wiki surface yet
- `agent-todo.md`
  - source of truth for current backlog slice ids and implementation intent

If these ever disagree, update this tracker in the same change.

## Status vocabulary

### Implementation status

- `implemented` = active `HotPass` or `ModulePass` in `src/passes/optimize.mbt`
- `removed` = known pass name, but not implemented in the active pipeline yet
- `boundary-only` = tracked legacy/upstream name that still needs wider module/boundary work before it can be a real hot/module pass in-tree

### Wiki status

- `deep` = dedicated landing page plus multiple living supporting pages
- `landing` = dedicated living landing page, but not yet a full dossier
- `dossier` = unimplemented pass, but already has a dedicated living folder or page worth treating as the canonical research home
- `none` = no dedicated living wiki page yet

## Current summary counts

- Active implemented passes in the registry: `19`
- Active implemented passes with a dedicated living wiki page: `19 / 19`
- Active implemented passes with a deep multi-page dossier: `19 / 19`
- Unique unimplemented passes observed in the saved generated-artifact `-O4z` audit: `19`
- Those unimplemented `-O4z` passes with a dedicated living dossier today: `19 / 19` (`coalesce-locals`, `code-folding`, `code-pushing`, `dae-optimizing`, `directize`, `duplicate-import-elimination`, `flatten`, `inlining-optimizing`, `local-cse`, `local-subtyping`, `merge-blocks`, `merge-locals`, `optimize-casts`, `reorder-globals`, `rse`, `simplify-globals-optimizing`, `simplify-locals-notee-nostructure`, `simplify-locals-nostructure`, `string-gathering`)
- Unique unimplemented passes in the canonical no-DWARF `-O` / `-Os` path: `16`
- Those no-DWARF-missing passes with a dedicated living dossier today: `16 / 16` (`coalesce-locals`, `code-folding`, `code-pushing`, `dae-optimizing`, `directize`, `duplicate-import-elimination`, `inlining-optimizing`, `local-cse`, `local-subtyping`, `merge-blocks`, `optimize-casts`, `reorder-globals`, `rse`, `simplify-globals-optimizing`, `simplify-locals-nostructure`, `string-gathering`)

## Active implemented passes

| Pass | Category | Wiki status | Main living docs | Notes |
| --- | --- | --- | --- | --- |
| `duplicate-function-elimination` | implemented module | deep | [`duplicate-function-elimination/index.md`](duplicate-function-elimination/index.md) | Full dossier with Binaryen strategy, upstream implementation/test-map, WAT-shape catalog, Starshine strategy, upstream-vs-local-extra notes, and parity page. |
| `remove-unused-module-elements` | implemented module | deep | [`remove-unused-module-elements/index.md`](remove-unused-module-elements/index.md) | Full dossier with Binaryen strategy, implementation/test-map, roots/reference-only/nullification notes, WAT-shape catalog, retention/rewrite coverage, and parity page. |
| `memory-packing` | implemented module | deep | [`memory-packing/index.md`](memory-packing/index.md) | Full dossier with Binaryen strategy, segment-op/trap notes, WAT-shape catalog, current Starshine gap page, and parity notes. |
| `once-reduction` | implemented module | deep | [`once-reduction/index.md`](once-reduction/index.md) | Full dossier with Binaryen strategy, dominance/propagation/cycle-safety notes, WAT-shape catalog, and parity page. |
| `global-refining` | implemented module | deep | [`global-refining/index.md`](global-refining/index.md) | Full dossier with Binaryen strategy, export/public-type/retagging notes, WAT-shape catalog, and parity page. |
| `global-struct-inference` | implemented module | deep | [`global-struct-inference/index.md`](global-struct-inference/index.md) | Full dossier with Binaryen strategy, closed-world/unnesting notes, WAT-shape catalog, and parity page. |
| `reorder-locals` | implemented module | deep | [`reorder-locals/index.md`](reorder-locals/index.md) | Full dossier with Binaryen strategy, names/roundtrip/porting notes, WAT-shape catalog, parity page, and multivalue-scope decision. |
| `ssa-nomerge` | implemented hot | deep | [`ssa-nomerge/index.md`](ssa-nomerge/index.md) | Full dossier with Binaryen strategy, merge-policy/canonical-slot notes, WAT-shape catalog, and parity page. |
| `vacuum` | implemented hot | deep | [`vacuum/index.md`](vacuum/index.md) | Full dossier with Binaryen strategy, effect/TNH, WAT-shape, and current Starshine gap pages. |
| `dead-code-elimination` | implemented hot | deep | [`dead-code-elimination/index.md`](dead-code-elimination/index.md) | Full dossier with Binaryen strategy, typed-control / EH repair notes, WAT-shape catalog, and current Starshine HOT-strategy page. |
| `remove-unused-names` | implemented hot | deep | [`remove-unused-names/index.md`](remove-unused-names/index.md) | Full dossier with Binaryen strategy, control-name / implicit-block / delegate notes, WAT-shape catalog, and the existing parser-gap note. |
| `remove-unused-brs` | implemented hot | deep | [`remove-unused-brs/index.md`](remove-unused-brs/index.md) | Full dossier with Binaryen strategy, implementation/test-map, WAT-shape catalog, multiple family pages, and parity notes. |
| `optimize-instructions` | implemented hot | deep | [`optimize-instructions/index.md`](optimize-instructions/index.md) | Full dossier with Binaryen strategy, GC/call_ref/trap-sensitive notes, WAT-shape catalog, and current Starshine gap page. |
| `heap-store-optimization` | implemented hot | deep | [`heap-store-optimization/index.md`](heap-store-optimization/index.md) | Full dossier with Binaryen strategy, swap/control-flow safety, WAT-shape, and current Starshine gap page. |
| `heap2local` | implemented hot | deep | [`heap2local/index.md`](heap2local/index.md) | Full dossier with Binaryen strategy, validation/special-case, WAT-shape, current Starshine HOT-strategy, and parity pages. |
| `pick-load-signs` | implemented hot | deep | [`pick-load-signs/index.md`](pick-load-signs/index.md) | Full dossier with Binaryen strategy, WAT-shape, current Starshine HOT-strategy, and parity pages. |
| `tuple-optimization` | implemented hot | deep | [`tuple-optimization/index.md`](tuple-optimization/index.md) | Refreshed dossier now includes a dedicated upstream implementation/test-map page, makes explicit that Binaryen `version_129` is a conservative tuple-local splitter rather than a generic multivalue optimizer, and records that the tagged core pass plus dedicated lit file still match current `main`; exact preset slot is still blocked by missing neighbors. |
| `precompute` | implemented hot | deep | [`precompute/index.md`](precompute/index.md) | Full dossier with Binaryen strategy, propagation/partial-precompute/GC-identity notes, WAT-shape catalog, and current Starshine gap page. |
| `simplify-locals` | implemented hot | deep | [`simplify-locals/index.md`](simplify-locals/index.md) | Refreshed dossier now includes a dedicated upstream implementation/test-map page and an explicit public-variant/scheduler page, makes clear that Binaryen `version_129` is a staged five-variant family rather than one vague locals pass, and records that the checked current-main drift is only tiny container cleanup. |

## Unimplemented passes that still block fuller Binaryen parity

This table is the main implementation queue tracker.

- `Relevance = both` means the pass appears in the canonical no-DWARF path **and** in the saved generated-artifact `-O4z` skipped-slot audit.
- `Relevance = O4z-only` means it was observed in the saved `-O4z` audit, but it is not currently listed on the no-DWARF `-O` / `-Os` page.

| Pass | Relevance | Registry status | Wiki status | Backlog slice | Current tracking note |
| --- | --- | --- | --- | --- | --- |
| `merge-blocks` | both | removed | dossier | `MB` | Dedicated dossier exists: [`merge-blocks/index.md`](merge-blocks/index.md). |
| `code-pushing` | both | removed | dossier | `CP` | Dedicated dossier exists: [`code-pushing/index.md`](code-pushing/index.md). |
| `simplify-locals-nostructure` | both | removed | dossier | `SLNS` | Dedicated dossier exists: [`simplify-locals-nostructure/index.md`](simplify-locals-nostructure/index.md); the current removed-name registry placeholder in `src/passes/optimize.mbt` is still spelled `simplify-locals-no-structure`. |
| `optimize-casts` | both | removed | dossier | `OC` | Dedicated dossier exists: [`optimize-casts/index.md`](optimize-casts/index.md). |
| `local-subtyping` | both | removed | dossier | `LS` | Dedicated dossier exists: [`local-subtyping/index.md`](local-subtyping/index.md). |
| `coalesce-locals` | both | removed | dossier | `CL` | Dedicated dossier exists: [`coalesce-locals/index.md`](coalesce-locals/index.md). |
| `local-cse` | both | removed | dossier | `LCSE` | Dedicated dossier exists: [`local-cse/index.md`](local-cse/index.md). |
| `code-folding` | both | removed | dossier | `CF` | Dedicated dossier exists: [`code-folding/index.md`](code-folding/index.md). |
| `rse` / `redundant-set-elimination` | both | removed | dossier | `RSE` | Dedicated dossier exists: [`rse/index.md`](rse/index.md); current Binaryen `version_129` scope is locals-only, while the saved `-O4z` audit uses `rse` and the registry still tracks `redundant-set-elimination`. |
| `dae-optimizing` | both | boundary-only | dossier | `DAE` | Dedicated dossier exists: [`dae-optimizing/index.md`](dae-optimizing/index.md); the folder also documents the relation between plain `dead-argument-elimination` and the optimizing nested-rerun variant. |
| `inlining-optimizing` | both | boundary-only | dossier | `INL` | Dedicated dossier exists: [`inlining-optimizing/index.md`](inlining-optimizing/index.md); the folder documents the whole-module planner, partial-inlining split strategy, and nested `optimizeAfterInlining` rerun contract. |
| `duplicate-import-elimination` | both | boundary-only | dossier | `DIE` | Dedicated dossier exists: [`duplicate-import-elimination/index.md`](duplicate-import-elimination/index.md); the folder documents the exact import-identity key, the first-import-wins rule, the broad per-kind user-remap surface, and the current tag/table-caveat notes. |
| `simplify-globals-optimizing` | both | boundary-only | dossier | `SGO` | Dedicated dossier exists: [`simplify-globals-optimizing/index.md`](simplify-globals-optimizing/index.md); the folder documents the single-use/global-write cleanup split, the `read-only-to-write` matcher, startup-vs-runtime propagation, and the nested default-function rerun without prepended `precompute-propagate`. |
| `string-gathering` | both | boundary-only | dossier | `SG` | Dedicated dossier exists: [`string-gathering/index.md`](string-gathering/index.md); the folder documents the whole-module `string.const` scan, reusable immutable-global rules, validity-first defining-global reorder before `reorder-globals`, and the current local registry-bookkeeping caveat. |
| `reorder-globals` | both | boundary-only | dossier | `RG` | Dedicated dossier exists: [`reorder-globals/index.md`](reorder-globals/index.md); the folder documents the count-plus-dependency search, the under-`128` public no-op rule, the `reorder-globals-always` internal/test variant, and the `string-gathering` handoff. |
| `directize` | both | boundary-only | dossier | `DIR` | Dedicated dossier exists: [`directize/index.md`](directize/index.md); the folder documents the table-info prepass, constant-vs-`select` target rewrite families, trap-to-`unreachable` replacements, and the `directize-initial-contents-immutable` mode. |
| `flatten` | O4z-only | removed | dossier | `—` | Dedicated dossier exists: [`flatten/index.md`](flatten/index.md); the folder documents the formal Flat IR contract, the `preludes` / `breakTemps` algorithm, the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` slot, and the current `BrOn*` / `TryTable` unsupported boundary. |
| `simplify-locals-notee-nostructure` | O4z-only | removed | dossier | `—` | Dedicated dossier exists: [`simplify-locals-notee-nostructure/index.md`](simplify-locals-notee-nostructure/index.md); the folder documents the exact `SimplifyLocals<false, false, true>` variant surface, the shared direct-single-use-sink plus late-cleanup contract, and the post-`flatten` aggressive handoff to `local-cse`. |
| `merge-locals` | O4z-only | removed | dossier | `—` | Dedicated dossier exists: [`merge-locals/index.md`](merge-locals/index.md); the folder documents the single-set-plus-simple-source LocalGraph contract, the direct-source-vs-fresh-temp canonical-slot split, and the current local-name bailout. |

## Additional upstream-only registry passes outside the main no-DWARF / saved-`-O4z` queue

These passes are not part of the current open-world no-DWARF path or the saved generated-artifact skipped-slot queue above.
They are still fair campaign targets because they are already named in the local registry or neighboring living docs.

| Pass | Why it matters | Registry status | Wiki status | Current tracking note |
| --- | --- | --- | --- | --- |
| `remove-unused-types` | Closed-world GC/type cleanup between `remove-unused-module-elements` and later type-tightening passes like `gsi` | boundary-only | dossier | Dedicated dossier now exists: [`remove-unused-types/index.md`](remove-unused-types/index.md). |
| `type-refining` | Closed-world pre-`global-refining` type-tightening pass already recorded in the `global-refining` dossier's scheduler notes | boundary-only | dossier | Dedicated dossier now exists: [`type-refining/index.md`](type-refining/index.md); the folder also documents the normal-vs-`type-refining-gufa` split, the closed-world-only scheduler slot, and the read/write fixup contract. |
| `signature-pruning` | Closed-world pre-`global-refining` signature cleanup pass that helps shrink the same module/type cluster as `type-refining` | boundary-only | dossier | Dedicated dossier now exists: [`signature-pruning/index.md`](signature-pruning/index.md); the folder also documents the heap-type-level DAE contract, constant-actual promotion, delayed `ChildLocalizer` reruns, and the public/tag/continuation/subtyping boundary matrix. |
| `signature-refining` | Closed-world pre-`global-refining` signature-tightening pass in the same GC/type cluster | boundary-only | dossier | Dedicated dossier now exists: [`signature-refining/index.md`](signature-refining/index.md); the folder also documents the param-LUB vs result-LUB split, the public-vs-params-only blocker matrix, and the `call.without.effects` repair contract. |
| `global-type-optimization` | Closed-world optional post-`global-refining` neighbor already recorded in current `global-refining` and `gsi` scheduler notes | boundary-only | dossier | Dedicated dossier now exists: [`global-type-optimization/index.md`](global-type-optimization/index.md); the folder also documents the upstream `gto` shorthand, the hard `--closed-world` requirement, the subtype-safe field-reorder contract, and the JS-descriptor plus trap-preservation boundaries. |
| `abstract-type-refining` | Closed-world post-`gsi` cleanup pass already recorded in current GC/type neighbor notes | boundary-only | dossier | Dedicated dossier now exists: [`abstract-type-refining/index.md`](abstract-type-refining/index.md); the folder also documents the TNH-only singleton-child refinement rule, the always-on never-created-to-bottom rewrite, and the descriptor/exact-cast preoptimization contract. |
| `unsubtyping` | Closed-world post-`gsi` cleanup pass in the same late GC/type cluster | boundary-only | dossier | Dedicated dossier now exists: [`unsubtyping/index.md`](unsubtyping/index.md); the folder also documents the minimal subtype-plus-descriptor fixed-point contract, the exact-vs-ordinary cast split, the descriptor-square and JS-boundary rules, and the allocation trap-preservation fixes. |
| `minimize-rec-groups` | Upstream-only type-section shrink pass already recorded in `late-pipeline-dispatch.md` and the local boundary-only registry | boundary-only | dossier | Dedicated dossier now exists: [`minimize-rec-groups/index.md`](minimize-rec-groups/index.md); the folder also documents the SCC-splitting-plus-identity-preservation contract, the permutation-vs-brand fallback logic, the public-group conflict rule, and the feature-sensitive exactness boundary. |
| `reorder-types` | Upstream-only type-layout pass already recorded in `late-pipeline-dispatch.md` and the local boundary-only registry | boundary-only | none | The current docs mention the release-note appearance of `ReorderTypes`, but there is still no dedicated living dossier. |

## Practical maintenance rules

When work lands, update this page as follows:

### If a pass becomes implemented

- Move it from the unimplemented table into the active implemented table.
- Update its implementation status from `removed` or `boundary-only` to `implemented`.
- If it enters public presets or the no-DWARF parity path honestly, mention that in the notes column.

### If a pass gets wiki-ified before implementation

- Change its wiki status from `none` to `dossier`.
- Add a dedicated folder or living page under `docs/wiki/binaryen/passes/`.
- Link that page in the tracker row.

### If an implemented pass gets deeper docs

- Change its wiki status from `landing` to `deep` once it has a real supporting set of living pages, not just one landing page.

## Suggested next wiki targets

The saved-audit `none` queue is still clear.

`remove-unused-names` was the last implemented pass that still only had a landing page.
That implemented-landing queue is now clear too.

So the next rule is different:

- do **not** assume another implemented pass is still missing its first real dossier
- re-check the active implemented table before choosing a pass
- only pick an already-`deep` implemented pass if you can point to a specific, major, source-backed documentation gap

Today there is still no default fallback that is as obviously correct as `remove-unused-names` was inside the original parity queue.
The old tuple-opt major-gap fallback is now closed, and the same is now true for `remove-unused-module-elements`: that folder now has a dedicated upstream implementation/test-map page plus a focused roots/reference-only/nullification page, so future threads should not treat its earlier teaching gap as still open either.
The same is now true for `remove-unused-brs`: that folder now has a dedicated upstream implementation/test-map page and a true WAT-shape catalog, so future threads should not treat its former official-source or shape-catalog gap as still open either.
The same is now true for `duplicate-function-elimination`: that folder now has a dedicated upstream implementation/test-map page and an explicit upstream-vs-Starshine-local-extra page, so future threads should not treat its former source-contract conflation gap as still open either.
The same is now true for `simplify-locals`: that folder now has a dedicated upstream implementation/test-map page and an explicit public-variant/scheduler page, so future threads should not treat its former `version_129` source-structure or variant-surface gap as still open either.
`remove-unused-types`, `type-refining`, `signature-pruning`, `signature-refining`, `global-type-optimization`, `abstract-type-refining`, `unsubtyping`, and `minimize-rec-groups` are now dossier-covered too, so future queue-expansion picks should move on to another upstream-only registry pass rather than reopening their first-dossier gaps.
A future thread that continues this campaign should therefore do one of two things explicitly:

- justify a new major-gap fallback inside an already-`deep` folder, **or**
- pick another still-`none` pass from the additional upstream-only registry table above, with `reorder-types` as the clearest current option.

## Sources

- [`../../../../src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)
- [`../no-dwarf-default-optimize-path.md`](../no-dwarf-default-optimize-path.md)
- [`../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md)
- [`../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md`](../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md)
- [`../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md`](../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md)
- [`../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md`](../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md)
- [`../../raw/research/0132-2026-04-20-precompute-binaryen-research.md`](../../raw/research/0132-2026-04-20-precompute-binaryen-research.md)
- [`../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md`](../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md)
- [`../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md`](../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md)
- [`../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md`](../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md)
- [`../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md`](../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md)
- [`../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md`](../../raw/research/0137-2026-04-20-memory-packing-binaryen-research.md)
- [`../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md`](../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md)
- [`../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md`](../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md)
- [`../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md`](../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md)
- [`../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md`](../../raw/research/0141-2026-04-20-ssa-nomerge-binaryen-research.md)
- [`../../raw/research/0142-2026-04-20-reorder-locals-binaryen-research.md`](../../raw/research/0142-2026-04-20-reorder-locals-binaryen-research.md)
- [`../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md`](../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md)
- [`../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md`](../../raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md)
- [`../../raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md`](../../raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md)
- [`../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md`](../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md)
- [`../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md`](../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md)
- [`../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md`](../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md)
- [`../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- [`../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md`](../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md)
- [`../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md`](../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md)
- [`../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md`](../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md)
- [`../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md`](../../raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md)
- [`../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md`](../../raw/research/0154-2026-04-21-unsubtyping-binaryen-research.md)
- [`../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md`](../../raw/research/0155-2026-04-21-abstract-type-refining-binaryen-research.md)
- [`../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md`](../../raw/research/0156-2026-04-21-minimize-rec-groups-binaryen-research.md)
- [`../../../../agent-todo.md`](../../../../agent-todo.md)
