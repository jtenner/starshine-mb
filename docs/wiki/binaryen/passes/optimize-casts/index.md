---
kind: entity
status: supported
last_reviewed: 2026-07-03
sources:
  - ../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md
  - ../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/research/0469-2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../raw/research/0537-2026-05-06-optimize-casts-direct-revalidation.md
  - ../../../raw/research/0551-2026-05-08-optimize-casts-ordered-slot-replay.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../late-pipeline-dispatch.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./two-phase-dataflow.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./fuzzing.md
  - ../heap2local/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# `optimize-casts`

## Role

- `optimize-casts` is an upstream Binaryen GC/local cleanup pass.
- Starshine now has an active source-reviewed HOT implementation in [`../../../../../src/passes/optimize_casts.mbt`](../../../../../src/passes/optimize_casts.mbt), dispatcher coverage in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt), registry coverage in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt), focused tests in [`../../../../../src/passes/optimize_casts_test.mbt`](../../../../../src/passes/optimize_casts_test.mbt), and dedicated `optimize-casts-all` GenValid coverage.
- Despite the broad CLI name, Binaryen `version_130` uses it for a narrower job: improve how nearby `ref.cast` and `ref.as_non_null` values are moved or reused through locals. Starshine implements reasonable v0.1.0 coverage for that local-flow surface plus intentional direct static folds for `ref.test`, descriptor tests/casts, and branch casts; the extra static-fold surface is documented separately from Binaryen's narrower `OptimizeCasts.cpp` contract.
- The dossier now also has immutable raw primary-source manifests for the earlier `version_129` review, a 2026-07-02 `version_130` recursive audit/source refresh, and living pages tying upstream owner/helper/test surfaces to current local registry, backlog, scheduler, fuzz, and GC/local-neighbor code locations.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `optimize-casts` in the GC/local cleanup cluster after `heap2local` and before `local-subtyping` plus `coalesce-locals`.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `28`
- The saved Binaryen debug log also shows many more `optimize-casts` executions later in the same full run, which matches the nested rerun story from `opt-utils.h`.
- The 2026-05-08 ordered-slot replay proved the exact `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighborhood, so public `optimize` / `shrink` now schedule `optimize-casts` in that slot; remaining broader GC/local follow-up now lives under neighboring backlog slices instead of a standalone `OC` gate.

## Beginner summary

A safe beginner mental model is:

- if one use of a local has already been narrowed by a cast,
- try to reuse that narrower value instead of going back to the wider local,
- and if a better cast appears a little later in straight-line code,
- duplicate it earlier only when that move is clearly safe.

That is narrower than “optimize all casts.”

## Current durable takeaways

- Binaryen only runs this pass when GC is enabled.
- For reviewed Binaryen `version_130`, the pass handles only local-flow:
  - `ref.cast`
  - `ref.as_non_null`
- The pass is really **two** algorithms:
  1. move the best cast earlier inside a strict linear-execution window
  2. save and reuse the best already-computed cast later in a slightly wider adjacent-block window
- Extern-conversion `ref.as` forms are deliberately ignored here.
- The pass adds new locals and `local.tee`s; it does not try to delete every redundant old cast immediately.
- `ReFinalize` runs after both rewrite phases because the new locals and gets become more refined than before.
- The implementation comment explicitly positions `optimize-casts` next to `simplify-locals`, `rse`, and `local-cse` as related work, but not the same work.
- The 2026-07-02/2026-07-03 recursive audit refreshed the Binaryen `version_130` source/lit inventory, implemented and documented reasonable Starshine coverage for strict early motion, later reuse, best-cast selection, `ref.as_non_null`, tee/fallthrough, repeated/moved-cast, and barrier families, and fixed the initialized exact fresh-local blocker needed for Binaryen-shaped carrier locals.
- The dedicated `optimize-casts-all` GenValid aggregate is the pass-specific closeout lane and is green at `10000/10000`; direct regular GenValid is green at `100000/100000`; broad/random `10000` has only the accepted measured fresh exact-struct `heap2local-ref` `ref.test` Starshine win; explicit wasm-smith is accepted at `10000` requested cases with `--normalize unreachable-control-debris` for a single non-OC cleanup-debris mismatch.
- Direct O4z-repro pass-local timing is within the `<= 2x` target, and ordered GC/local prefix replay localizes the checked-in neighborhood size/shape drift to `coalesce-locals` rather than direct OC or the `heap2local -> optimize-casts -> local-subtyping` prefixes.
- The current v0.1.0 OC audit is closed with explicit non-goals: Binaryen's own `past-basic-block` arbitrary-dominance TODO, extern conversions, whole-CFG cast propagation, immediate deletion of every redundant old cast, and unmeasured generic cast-optimizer broadening.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_130` implementation: GC gate, early cast motion, later cast reuse, effect barriers, helper utilities, scheduler placement, and the final source/docs review table.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-location map for `OptimizeCasts.cpp`, scheduler/helper surfaces, the official `optimize-casts.wast` proof families, and exact current Starshine prerequisite code locations.
- [`./two-phase-dataflow.md`](./two-phase-dataflow.md)
  Dedicated guide to the easiest part of the pass to misunderstand: why moving a cast earlier is stricter than reusing it later, and why Binaryen therefore splits the pass into two internal dataflow phases.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the positive, negative, bailout, and interaction families that matter most.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status and closeout bridge: active HOT implementation, source-reviewed local-flow coverage, closeout-scale evidence, retained static-fold Starshine wins, explicit non-goals, and the now-public `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` slot.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Dedicated implementation-readiness bridge: first-slice scope, exact local code surfaces, validation ladder, and the explicit non-goals that keep the port narrower than the backlog wording.
- [`./fuzzing.md`](./fuzzing.md)
  Dedicated GenValid aggregate documentation for `optimize-casts-all`, its selected-profile leaves, aliases, closeout-scale matrix evidence, accepted residual policies, and reopening criteria.

## Current maintenance rule

- Treat this folder as the canonical home for future `optimize-casts` research and port planning.
- Keep the active Starshine implementation status and direct parity evidence current; the 2026-05-08 ordered-slot replay revalidated direct `optimize-casts` parity, replayed `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` on the checked-in debug artifact with normalized-WAT plus canonical-function equality, and moved the proven slot into public `optimize` / `shrink`.
- New `optimize-casts` findings should update the Binaryen strategy page, implementation/test-map page, shape pages, Starshine status page, and port-readiness bridge together so the upstream algorithm, concrete examples, source proof, validation ladder, and local port story stay aligned.

## Sources

- [`../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md`](../../../raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md)
- [`../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md`](../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md`](../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md)
- [`../../../raw/research/0469-2026-05-05-optimize-casts-current-main-recheck.md`](../../../raw/research/0469-2026-05-05-optimize-casts-current-main-recheck.md)
- [`../../../raw/research/0500-2026-05-06-optimize-casts-starshine-port-readiness.md`](../../../raw/research/0500-2026-05-06-optimize-casts-starshine-port-readiness.md)
- [`../../../raw/research/0537-2026-05-06-optimize-casts-direct-revalidation.md`](../../../raw/research/0537-2026-05-06-optimize-casts-direct-revalidation.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeCasts.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-casts.wast>