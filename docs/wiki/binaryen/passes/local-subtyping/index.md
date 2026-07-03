---
kind: entity
status: supported
last_reviewed: 2026-07-03
sources:
  - ../../../raw/research/0534-2026-05-06-local-subtyping-direct-revalidation.md
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
- Starshine's current implementation is narrower than Binaryen's: it narrows reference-typed body locals from write-site evidence and has first non-null dominance slices for straight-line bodies, `local.tee` non-null assignment/use validation, branch-free `block` bodies entered after a dominating write, branch-free block writes that dominate later outer gets, terminal `br` / `br_table` blocks whose local gets are already dominated before the branch, `loop` bodies entered after a dominating write including the source-backed `br_if` backedge-at-tail subset, branch-free nested `if` arms inside dominated blocks/loops, branch-free root `if` arms whose gets are dominated by the pre-`if` write, a source-backed conditional-`return` branch subset where the returning path cannot reach the later write/get, a source-backed direct `throw` path-skip subset where the throwing `if` arm cannot reach a later dominating write/get, and source-backed root/block terminal-`return`, nested block terminal-`return` and terminal-`throw` subsets inside return/throw-skipped `if` arms, plus root/block terminal-`throw` subsets where a dominated get appears before final terminal control, and a `try_table` body subset where the get is dominated inside the try body, including the source-backed terminal-body-`return`/`throw` cases. Source-backed fallbacks now pin nullable post-state behavior for loop writes, all-arm `if` writes, block writes with branch flow before a later outside get, `try_table` body writes before a later outside get, `br_if` paths that can skip a write, direct block-return flow that Starshine's validator cannot yet prove unreachable after non-defaultable-local narrowing, and parameter writes: local Binaryen v130 keeps function parameters at their declared signature types. Starshine still does not implement full structural get-aware non-null dominance, broad explicit get/tee retagging, or iterative refinalization.
- The pass matters because it sits in the GC/local cleanup cluster after `heap2local` and `optimize-casts`, before `coalesce-locals` and `local-cse`.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` local-cleanup cluster runs `local-subtyping` in the middle of the reference-local family.
- Starshine ships the pass as a direct `--local-subtyping` module pass, with registry, dispatcher, CLI, and preset coverage.
- The current gap is parity, not absence: the Starshine version is assignment-only narrowing, while Binaryen's contract also includes get-aware safety and repeated refinement.

## Beginner summary

A good first model is:

1. inspect reference-typed body locals while preserving parameters as ABI/signature types;
2. collect the values written by `local.set` / `local.tee`;
3. use a conservative read-before-write scan over straight-line roots, branch-free `block` bodies including writes propagated to later outer gets, terminal `br` / `br_table` blocks whose gets are already dominated before the branch, `loop` bodies entered after prior writes including the narrow safe `br_if` backedge-at-tail subset, branch-free nested `if` arms inside dominated regions, branch-free root `if` arms, conditional-`return` branches and direct `throw` arms that skip the later write/get path, and root/block terminal `return`, if-arm nested block terminal `return`/`throw`, root/block terminal `throw`, or a `try_table` body (non-throwing or ending in terminal body `return`/`throw`) after dominated gets to decide whether nullable-to-non-null narrowing is safe, while keeping source-backed nullable fallbacks for loop/if/branch-flow post-state boundaries, direct block-return tooling boundaries, try-table body post-state boundaries, and branch paths that can skip writes;
4. choose the most specific safe common reference supertype;
5. rewrite body-local declarations when that type is narrower;
6. rebuild the module only if something changed.

That is enough to explain current Starshine behavior without pretending it already matches the full upstream Binaryen contract.

## Current durable takeaways

- `src/passes/local_subtyping.mbt` is the owner file.
- `src/passes/local_subtyping_test.mbt` proves active registry status plus the shipped narrowing and fallback shapes.
- `src/cmd/cmd_wbtest.mbt` proves the `--local-subtyping` CLI path works on wasm inputs.
- `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, `src/passes/registry_test.mbt`, and `src/passes/optimize_test.mbt` prove registry, dispatcher, and preset-slot wiring.
- The current implementation uses write-site evidence plus a raw `local.get` pre-scan for straight-line roots, non-null `local.tee` assignment/use validation, branch-free `block` bodies and block writes that dominate later outer gets, terminal `br` / `br_table` block bodies whose gets are dominated before the branch while not propagating branch-carried writes to outer post-state, `loop` bodies entered after a dominating write including a source-backed tail-`br_if` backedge case, branch-free nested `if` arms inside those dominated regions, branch-free root `if` arms entered after a dominating write, conditional-`return` branches and direct `throw` arms that skip the later write/get path, and root/block terminal `return`, if-arm nested block terminal `return`/`throw`, and root/block terminal `throw` after dominated gets, and `try_table` bodies whose gets are dominated inside the try body, including terminal body `return`/`throw`. It also has source-backed fallback guards for branch-free loop writes before an outside get, all-arm `if` writes before an outside get, block writes followed by branch flow before an outside get, `try_table` body writes before an outside get, `br_if` paths that can skip a later block write, direct block-return flow that remains nullable until Starshine validation models Binaryen's unreachable non-defaultable-local proof, and parameter writes that leave the function signature nullable; broader `try_table`/EH flow, branch/return/throw dominance beyond these narrowed branch/return/if-arm terminal-return-or-throw/terminal-control subsets, broader loop/control-flow dominance and loop post-state non-null propagation, broader `if` post-state joins, and broad expression-type repair are still open.
- The 2026-05-06 direct revalidation lane for `--local-subtyping` reached 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group command failures under seed `0x5eed`.
- The tracked full-contract parity gap is explicit, not accidental, so the active implementation can keep moving while the Binaryen delta stays visible.

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

- [`../../../raw/research/0534-2026-05-06-local-subtyping-direct-revalidation.md`](../../../raw/research/0534-2026-05-06-local-subtyping-direct-revalidation.md)
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
