---
kind: entity
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md
  - ../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
  - ../../../../../src/passes/local_subtyping.mbt
  - ../../../../../src/passes/local_subtyping_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# `local-subtyping`

## Role

- `local-subtyping` is an upstream Binaryen GC/local cleanup pass **and** an active Starshine module pass.
- Starshine's current implementation is narrower than Binaryen's: it narrows reference-typed body locals from write-site evidence, but it does not yet implement get-aware non-null dominance, get/tee retagging, or iterative refinalization.
- The pass matters because it sits in the GC/local cleanup cluster after `heap2local` and `optimize-casts`, before `coalesce-locals` and `local-cse`.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` local-cleanup cluster runs `local-subtyping` in the middle of the reference-local family.
- Starshine ships the pass as a direct `--local-subtyping` module pass, with registry, dispatcher, CLI, and preset coverage.
- The current gap is parity, not absence: the Starshine version is assignment-only narrowing, while Binaryen's contract also includes get-aware safety and repeated refinement.

## Beginner summary

A good first model is:

1. inspect reference-typed body locals;
2. collect the values written by `local.set` / `local.tee`;
3. choose the most specific safe common reference supertype;
4. rewrite body-local declarations when that type is narrower;
5. rebuild the module only if something changed.

That is enough to explain current Starshine behavior without pretending it already matches the full upstream Binaryen contract.

## Current durable takeaways

- `src/passes/local_subtyping.mbt` is the owner file.
- `src/passes/local_subtyping_test.mbt` proves active registry status and the two shipped narrowing shapes.
- `src/cmd/cmd_wbtest.mbt` proves the `--local-subtyping` CLI path works on wasm inputs.
- `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, `src/passes/registry_test.mbt`, and `src/passes/optimize_test.mbt` prove registry, dispatcher, and preset-slot wiring.
- The current implementation only looks at write-site evidence; it does not yet inspect gets for dominance or repair.
- The tracked parity gap is explicit, not accidental, so the active implementation can keep moving while the Binaryen delta stays visible.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Binaryen `version_129` contract: scan/get/refinalize refinement, dominance-gated non-nullability, body-local rewrite, and scheduler placement.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source map for the upstream contract and the current Starshine owner/test/CLI/registry surfaces.
- [`./lubs-and-dominance.md`](./lubs-and-dominance.md)
  - Semantic guide to LUBs, gets, dominance, nullability, and iteration.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog for narrowing, common-parent LUBs, tees, and dominance boundaries.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine implementation and parity-gap map.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Validation ladder for the active subset and the missing upstream behaviors.

## Maintenance rule

- Keep this folder as the canonical home for both the upstream contract and the active Starshine subset.
- Update the strategy, implementation map, shape catalog, and validation bridge together whenever the Starshine implementation grows new behavior or fixes a parity gap.
- Record any divergence from Binaryen explicitly instead of hiding it behind a future-port label.

## Sources

- [`../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md`](../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md)
- [`../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md)
- [`../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md`](../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md)
- [`../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md`](../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md)
- [`../../../../../src/passes/local_subtyping.mbt`](../../../../../src/passes/local_subtyping.mbt)
- [`../../../../../src/passes/local_subtyping_test.mbt`](../../../../../src/passes/local_subtyping_test.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/ir/hot_core.mbt`](../../../../../src/ir/hot_core.mbt)
- Binaryen current-main and version_129 source URLs embedded in the raw source manifests above
