---
kind: concept
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
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# `local-subtyping`: implementation structure and tests

This page is the source-map companion for the `local-subtyping` dossier. It explains which upstream files own the pass, which Starshine files implement the active subset, and which tests prove the current contract.

## Correction status

Use [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md) as the strongest tagged-source correction for the Binaryen side.
Use [`../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md`](../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md) as the current Starshine source correction.

The older wiki reading was wrong in one important way: Starshine `local-subtyping` is already active.
The current implementation is still narrower than Binaryen, but it is not future-only.

## Upstream owner map

| File | Role |
| --- | --- |
| `src/passes/LocalSubtyping.cpp` | Binaryen owner file. Defines the full upstream contract: reference-local scan, set/get collection, LUB candidate selection, dominance-gated non-nullability, body-local rewrite, get/tee retagging, and iterative refinalization.
| `src/passes/pass.cpp` | Registers the Binaryen pass and places it before `coalesce-locals` in the GC/local cleanup neighborhood.
| `src/passes/opt-utils.h` | Shows where the default function optimization helper can rerun the local-cleanup neighborhood after inlining-style rewrites.
| `src/ir/lubs.h` and `src/ir/lubs.cpp` | Provide the `LUBFinder` used to compute one common target type from the values assigned to a local.
| `src/ir/local-structural-dominance.h` | Provides the non-null dominance proof and non-dominating-get list used to decide whether gets may take the non-null declaration type.
| `test/lit/passes/local-subtyping.wast` | Dedicated Binaryen proof surface for narrowing, non-null dominance, loops, tees, repeated refinement, named-type LUBs, parameter preservation, tuple/nondefaultable preservation, and local-cleanup interactions.

## Starshine owner map

| File | Role |
| --- | --- |
| `src/passes/local_subtyping.mbt` | Active owner file. Implements the current subset: helper subtype checks, write-site collection, candidate narrowing, body-local rewrite, and module rebuild.
| `src/passes/local_subtyping_test.mbt` | Direct Starshine tests for registry status plus the two shipped narrowing cases.
| `src/cmd/cmd_wbtest.mbt` | CLI integration test proving `--local-subtyping` runs on wasm input and writes the rewritten module.
| `src/passes/registry_test.mbt` | Registry category proof that `local-subtyping` is a module pass.
| `src/passes/optimize.mbt` | Registry entry and preset inclusion for `local-subtyping`.
| `src/passes/pass_manager.mbt` | Active hot-pass dispatcher entry.
| `src/passes/optimize_test.mbt` | Optimize-preset slot proof for the `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` neighborhood.

## Starshine phase map

A faithful read-along of `src/passes/local_subtyping.mbt` should follow these phases:

1. **Summary and pass registration context**
   - The pass summary describes narrowing reference-typed body locals to the most specific safe supertype of their writes.
2. **Module context and imported-function count**
   - The implementation lifts each function with a `HotModuleContext` and computes the imported-function offset so `FuncIdx` values stay aligned.
3. **Heap subtype helpers**
   - The helper set checks exact heap equality, abstract heap relationships, subtype-parent chains, and reference exactness / nullability rules.
4. **Assignment collection**
   - `local.set` and `local.tee` sites feed assignment result types when the child expression produces exactly one value.
5. **Candidate narrowing**
   - The pass chooses the most specific safe common reference subtype from the collected write-site values.
6. **Body-local rewrite**
   - Only body locals are rewritten; parameters are preserved.
7. **Module rebuild**
   - If nothing changed, the input module is returned unchanged; otherwise the code section is rebuilt with rewritten functions.

## Official lit-test map

The active Starshine tests are small but meaningful.

| Test / file | What it proves |
| --- | --- |
| `src/passes/local_subtyping_test.mbt:41-49` | `local-subtyping` is registered as an active module pass. |
| `src/passes/local_subtyping_test.mbt:52-70` | A body local narrows to an assigned child heap type. |
| `src/passes/local_subtyping_test.mbt:74-93` | Mixed sibling assignments keep the common supertype. |
| `src/cmd/cmd_wbtest.mbt:4376-4439` | The CLI path accepts `--local-subtyping` and writes an optimized wasm module. |
| `src/passes/optimize_test.mbt:491-495` | The pass is intentionally absent from the stale `reorder-locals` gating test; that test is about neighboring local-passes not yet being scheduled in a different slot. |
| `src/passes/optimize_test.mbt:561-568` | The optimize preset includes `local-subtyping` immediately after `optimize-casts` in the late GC/local cleanup neighborhood. |
| `src/passes/registry_test.mbt:78-82` | Registry category is `module_pass`. |
| `src/passes/optimize.mbt:284-285, 296-312` | Registry and preset wiring exist in the main optimize registry. |
| `src/passes/pass_manager.mbt:8937-8940` | The active dispatcher has a `local-subtyping` case. |

## What this page is *not*

This page is not a claim of full Binaryen parity.
The current Starshine implementation does not yet include:

- get-aware non-null repair;
- get/tee expression retagging after narrowing;
- iterative refinalization;
- dominance-sensitive fallback for nullable declarations.

Those gaps belong on the strategy and validation pages, not in the owner/test map.

## Sources

- [`../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md`](../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md)
- [`../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md)
- [`../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md`](../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md)
- Binaryen `version_129` owner: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
- Binaryen current-main owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalSubtyping.cpp>
- Binaryen current-main lit test: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-subtyping.wast>
- Starshine current source files listed above
