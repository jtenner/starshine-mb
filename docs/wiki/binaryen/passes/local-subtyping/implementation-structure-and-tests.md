---
kind: concept
status: supported
last_reviewed: 2026-07-04
sources:
  - ../../../raw/research/1431-2026-07-04-local-subtyping-behavior-family-matrix.md
  - ../../../raw/research/1432-2026-07-04-local-subtyping-retag-representation-and-unreachable-boundary.md
  - ../../../raw/research/1433-2026-07-04-local-subtyping-iterative-refinalization.md
  - ../../../raw/research/1434-2026-07-04-local-subtyping-select-lub-refinalization.md
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
| `src/passes/local_subtyping.mbt` | Active owner file. Implements the current subset: helper subtype checks, write-site collection, candidate narrowing, adjacent-local-get select/LUB annotation repair, raw-unreachable-before-write nullable fallback, body-local rewrite, bounded iterative rewrite/re-lift for dependent local-get and select/LUB assignments, and module rebuild. |
| `src/passes/local_subtyping_test.mbt` | Direct Starshine tests for registry status, write-site narrowing, the current non-null dominance subsets, iterative local-get assignment refinement, iterative select/LUB refinalization, tee-parent retag-representation validation, and the raw-unreachable-before-write nullable boundary. |
| `src/validate/gen_valid.mbt` and `src/validate/gen_valid_tests.mbt` | Dedicated `local-subtyping-all` GenValid profile and tests. The aggregate samples straight-line, branch-free structured, and root return/unreachable-tail LS trigger modules for required closeout lanes. |
| `src/cmd/cmd_wbtest.mbt` | CLI integration test proving `--local-subtyping` runs on wasm input and writes the rewritten module. |
| `src/passes/registry_test.mbt` | Registry category proof that `local-subtyping` is a module pass. |
| `src/passes/optimize.mbt` | Registry entry and preset inclusion for `local-subtyping`. |
| `src/passes/pass_manager.mbt` | Active hot-pass dispatcher entry. |
| `src/passes/optimize_test.mbt` | Optimize-preset slot proof for the `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` neighborhood. |

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
6. **Dominance pre-scan**
   - The pass admits non-null candidates only when a raw scan proves all gets follow a dominating write in the straight-line root, branch-free `block` bodies, branch-free block writes that dominate later outer gets, terminal `br` / `br_table` block bodies whose gets are already dominated before the branch, branch-free `loop` bodies entered after prior writes, the source-backed loop tail-`br_if` backedge subset, branch-free nested `if` arms inside those dominated regions, branch-free root `if` arms, conditional-`return` branches, direct `return_call` / `return_call_indirect` / `return_call_ref` arms, and direct `throw` / `throw_ref` arms that skip the later write/get path, root/block terminal `return`/direct `return_call` / `return_call_indirect` / `return_call_ref`, root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` tails before already-dominated unreachable-tail gets, if-arm nested block terminal `return`/`throw`, and root/block terminal `throw`/`throw_ref` after dominated gets, or `try_table` body dominated gets, including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and source-backed non-final body `return`/`throw`/`throw_ref`/tail-call tails whose later gets are already dominated. Writes inside a nested loop, if arm, branch-terminated block, `try_table` body, or after a raw `unreachable` are not propagated to the outer or later initialization state; branch-free block writes are propagated because local Binaryen v130 narrows that shape. Focused fallback tests pin local Binaryen v130/Starshine validation boundary behavior where loop writes, all-arm `if` writes, block writes with branch flow before a later outside get, `br_if` paths that can skip a later block write, `try_table` body writes before a later outside get, direct block-return flow, and raw-unreachable-before-write tee/get shapes narrow only to nullable child for a later outside get.
7. **Body-local rewrite**
   - Only body locals are rewritten; parameters are preserved. A local Binaryen v130 probe of a nullable parameter written with a non-null child value kept the parameter signature nullable, and Starshine now has a direct guard for that boundary.
8. **Select/LUB annotation repair**
   - Before HOT assignment collection, the pass repairs the source-backed adjacent-local-get `select`/LUB shape when local declarations make a sharper reference LUB available. This covers Binaryen's `multiple-iterations-refinalize` select case without claiming broader expression retagging.
9. **Iterative refinalization-equivalent loop**
   - After any declaration or select-annotation rewrite, the pass rebuilds the module and re-lifts functions on the next iteration. This lets assignment collection see sharper `local.get` and select result types from already-narrowed declarations, matching the Binaryen `multiple-iterations` local-get chain and the focused select/LUB shape without adding emitted get/tee type metadata.
10. **Module rebuild**
   - If nothing changed, the input module is returned unchanged; otherwise the code section is rebuilt with rewritten functions.

## Official lit-test map

The active Starshine tests are small but meaningful.

| Test / file | What it proves |
| --- | --- |
| `src/passes/local_subtyping_test.mbt:78-86` | `local-subtyping` is registered as an active module pass. |
| `src/passes/local_subtyping_test.mbt:89-107` | A body local narrows to an assigned child heap type. |
| `src/passes/local_subtyping_test.mbt:111-130` | Mixed sibling assignments keep the common supertype. |
| `src/passes/local_subtyping_test.mbt` iterative fixtures | `local-subtyping iterates after local.get assignment refinalization` proves a dependent local assigned from `local.get` narrows after an earlier local declaration rewrite and module re-lift; `local-subtyping iterates after select LUB refinalization` proves the source-backed untyped select/LUB shape rewrites to a non-null `(ref func)` result and narrows the dependent local. |
| `src/passes/local_subtyping_test.mbt` local.tee fixtures | `local.tee` assignment evidence feeds narrowing, a non-null tee assignment/use validates after non-null declaration narrowing, a tee-parent shape validates without emitted retag repair, and the raw-unreachable-before-write tee/get shape stays nullable to avoid Starshine's nondefaultable-local validation boundary. |
| `src/passes/local_subtyping_test.mbt` parameter fixture | A source-backed nullable-parameter write/get guard proves the pass preserves signature params and rewrites only body locals. |
| `src/passes/local_subtyping_test.mbt` dominance fixtures | Straight-line, branch-free block/loop, loop tail-`br_if` backedge, terminal `br` / `br_table` dominated-get, branch-free block-write post-state, nested branch-free block-if, branch-free root-if, conditional-return/direct-return_call/direct-return_call_indirect/direct-return_call_ref/direct-throw/direct-throw_ref skip, root/block terminal-return/return_call/return_call_indirect/return_call_ref, root non-final return/tail-call unreachable-tail-get, if-arm nested block terminal-return/throw, root/block terminal-throw/throw_ref, try_table body dominated-get including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails with already-dominated tail gets, source-backed nullable loop/if/branch-flow/try-table-body/branch-skipped-write post-state, and direct block-return validator-boundary tests cover non-null positives and nullable fallbacks. |
| `src/validate/gen_valid_tests.mbt` local-subtyping profile fixtures | Profile resolution, aggregate leaf sampling, and validating module generation for `local-subtyping-straight-line`, `local-subtyping-structured`, and `local-subtyping-unreachable-tail`. |
| `src/cmd/cmd_wbtest.mbt:4376-4439` | The CLI path accepts `--local-subtyping` and writes an optimized wasm module. |
| `src/passes/optimize_test.mbt:491-495` | The pass is intentionally absent from the stale `reorder-locals` gating test; that test is about neighboring local-passes not yet being scheduled in a different slot. |
| `src/passes/optimize_test.mbt:561-568` | The optimize preset includes `local-subtyping` immediately after `optimize-casts` in the late GC/local cleanup neighborhood. |
| `src/passes/registry_test.mbt:78-82` | Registry category is `module_pass`. |
| `src/passes/optimize.mbt:284-285, 296-312` | Registry and preset wiring exist in the main optimize registry. |
| `src/passes/pass_manager.mbt:8937-8940` | The active dispatcher has a `local-subtyping` case. |

## What this page is *not*

This page is not a claim of full Binaryen parity.
The 2026-07-04 behavior-family matrix reduced the remaining owner/test-map gaps to precise residuals:

- focused `multiple-iterations-refinalize-call-ref` and bottom-call-ref probes beyond the now-implemented local-get chain and select/LUB subset;
- focused EH `catch_ref` / `catch_all_ref` handler-flow and handler post-state local-declaration probes/classification;
- the direct block-return nondefaultable-local unreachable-tail validator/tooling boundary;
- the raw-unreachable-before-write nondefaultable-local tee/get validator/tooling boundary.

Broad get/tee expression retagging is now classified as representation-satisfied for emitted Starshine lib instructions unless Starshine later adds emitted local expression type metadata or lowers a stale typed HOT graph.

The earlier broad structural-control list is now either implemented/protected in `local_subtyping_test.mbt`, source/probe-backed as nullable fallback behavior, or routed to downstream cleanup owners. Those remaining residuals belong on the strategy and validation pages, not as hidden owner/test-map uncertainty.

## Sources

- [`../../../raw/research/1431-2026-07-04-local-subtyping-behavior-family-matrix.md`](../../../raw/research/1431-2026-07-04-local-subtyping-behavior-family-matrix.md)
- [`../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md`](../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md)
- [`../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md)
- [`../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md`](../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md)
- [`../../../raw/research/1432-2026-07-04-local-subtyping-retag-representation-and-unreachable-boundary.md`](../../../raw/research/1432-2026-07-04-local-subtyping-retag-representation-and-unreachable-boundary.md)
- [`../../../raw/research/1433-2026-07-04-local-subtyping-iterative-refinalization.md`](../../../raw/research/1433-2026-07-04-local-subtyping-iterative-refinalization.md)
- [`../../../raw/research/1434-2026-07-04-local-subtyping-select-lub-refinalization.md`](../../../raw/research/1434-2026-07-04-local-subtyping-select-lub-refinalization.md)
- Binaryen `version_129` owner: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
- Binaryen current-main owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LocalSubtyping.cpp>
- Binaryen current-main lit test: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/local-subtyping.wast>
- Starshine current source files listed above
