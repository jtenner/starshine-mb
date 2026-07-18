---
kind: entity
status: supported
last_reviewed: 2026-07-18
sources:
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
- Starshine's current implementation is narrower than Binaryen's: it narrows reference-typed body locals from write-site evidence and has first non-null dominance slices for straight-line bodies, `local.tee` non-null assignment/use validation, branch-free `block` bodies entered after a dominating write, branch-free block writes that dominate later outer gets, terminal `br` / `br_table` blocks whose local gets are already dominated before the branch, `loop` bodies entered after a dominating write including the source-backed `br_if` backedge-at-tail subset, branch-free nested `if` arms inside dominated blocks/loops, branch-free root `if` arms whose gets are dominated by the pre-`if` write, a source-backed conditional-`return` branch subset where the returning path cannot reach the later write/get, source-backed direct `return_call`, `return_call_indirect`, and `return_call_ref` path-skip subsets where the tail-call `if` arm cannot reach a later dominating write/get, a source-backed direct `throw` and `throw_ref` path-skip subsets where the throwing `if` arm cannot reach a later dominating write/get, and source-backed root/block terminal-`return`, direct `return_call`, `return_call_indirect`, and `return_call_ref`, source-backed root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` unreachable-tail-get subsets, nested block terminal-`return` and terminal-`throw` subsets inside return/return_call/throw-skipped `if` arms, plus root/block terminal-`throw`/`throw_ref` subsets where a dominated get appears before final terminal control, and a `try_table` body subset where the get is dominated inside the try body, including the source-backed terminal-body-`return`/`throw`/`throw_ref` cases and the non-final body-`return`/`throw`/`throw_ref` tail subset where later tail gets are already dominated. Source-backed fallbacks now pin nullable post-state behavior for loop writes, all-arm `if` writes, block writes with branch flow before a later outside get, `try_table` body writes before a later outside get, `br_if` paths that can skip a write, direct block-return flow that Starshine's validator cannot yet prove unreachable after non-defaultable-local narrowing, and parameter writes: local Binaryen v130 keeps function parameters at their declared signature types. Starshine now repeats declaration rewriting enough to cover the Binaryen `multiple-iterations` local-get assignment chain: a later iteration re-lifts the rebuilt module so a `local.get` assignment observes the narrowed source local. It also covers the Binaryen `multiple-iterations-refinalize` adjacent-local-get `select`/LUB shape by annotating or sharpening the select result after source locals narrow, so the dependent local can narrow to non-null `(ref func)`. The follow-up `call_ref` refinalization slice covers the represented zero-param adjacent-local-get `multiple-iterations-refinalize-call-ref` and bottom-call-ref lit surfaces by rewriting a sharpened `call_ref` type immediate or replacing a bottom target with a `(ref none)` unreachable value block. The 2026-07-04 retag representation slice shows broad explicit get/tee retagging is representation-satisfied for emitted Starshine lib instructions, while Binaryen's raw-unreachable-before-write tee/get lit shape remains a narrow validator/tooling boundary that Starshine keeps nullable. The ref-catch raw-assignment slice now closes the concrete `catch_ref` / `catch_all_ref` skipped-write parity residual by matching Binaryen's nullable exact-child local narrowing without enabling non-null dominance through ref-catch flow.
- The pass matters because it sits in the GC/local cleanup cluster after `heap2local` and `optimize-casts`, before `coalesce-locals` and `local-cse`.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` local-cleanup cluster runs `local-subtyping` in the middle of the reference-local family.
- Starshine ships the pass as a direct `--local-subtyping` module pass, with registry, dispatcher, CLI, and preset coverage.
- The current gap is parity, not absence: the Starshine version covers write-site narrowing plus a growing set of source-backed dominance subsets, while Binaryen's full contract also includes broader structural get-aware safety and repeated refinement.

## Beginner summary

A good first model is:

1. inspect reference-typed body locals while preserving parameters as ABI/signature types;
2. collect the values written by `local.set` / `local.tee`;
3. use a conservative read-before-write scan over straight-line roots, branch-free `block` bodies including writes propagated to later outer gets, terminal `br` / `br_table` blocks whose gets are already dominated before the branch, `loop` bodies entered after prior writes including the narrow safe `br_if` backedge-at-tail subset, branch-free nested `if` arms inside dominated regions, branch-free root `if` arms, conditional-`return` branches, direct `return_call` / `return_call_indirect` / `return_call_ref` arms, and direct `throw` / `throw_ref` arms that skip the later write/get path, and root/block terminal `return`/direct `return_call` / `return_call_indirect` / `return_call_ref`, root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` tails before already-dominated unreachable-tail gets, if-arm nested block terminal `return`/`throw`, root/block terminal `throw`/`throw_ref`, or a `try_table` body (non-throwing, ending in terminal body `return`/`throw`/`throw_ref`, or containing a source-backed non-final body `return`/`throw`/`throw_ref` before already-dominated unreachable-tail gets) after dominated gets to decide whether nullable-to-non-null narrowing is safe, while keeping source-backed nullable fallbacks for loop/if/branch-flow post-state boundaries, direct block-return tooling boundaries, try-table body post-state boundaries, and branch paths that can skip writes;
4. choose the most specific safe common reference supertype;
5. rewrite body-local declarations when that type is narrower;
6. repair source-backed adjacent-local-get `select`/LUB annotations and zero-param adjacent-local-get `call_ref` immediates when narrowed local declarations make a sharper expression type available;
7. replace the represented bottom-call-ref target case with a `(ref none)` unreachable value block;
8. repeat the module rewrite/re-lift loop until no declarations change, so dependent `local.get`, select/LUB, and call_ref assignments see the rebuilt local and expression types;
9. rebuild the module only if something changed.

That is enough to explain current Starshine behavior without pretending it already matches the full upstream Binaryen contract.

## Current durable takeaways

- `src/passes/local_subtyping.mbt` is the owner file.
- `src/passes/local_subtyping_test.mbt` proves active registry status plus the shipped narrowing and fallback shapes.
- `src/cmd/cmd_wbtest.mbt` proves the `--local-subtyping` CLI path works on wasm inputs.
- `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, `src/passes/registry_test.mbt`, and `src/passes/optimize_test.mbt` prove registry, dispatcher, and preset-slot wiring.
- The current implementation uses write-site evidence plus a raw `local.get` pre-scan for straight-line roots, non-null `local.tee` assignment/use validation, branch-free `block` bodies and block writes that dominate later outer gets, terminal `br` / `br_table` block bodies whose gets are dominated before the branch while not propagating branch-carried writes to outer post-state, `loop` bodies entered after a dominating write including a source-backed tail-`br_if` backedge case, branch-free nested `if` arms inside those dominated regions, branch-free root `if` arms entered after a dominating write, conditional-`return` branches, direct `return_call` / `return_call_indirect` / `return_call_ref` arms, and direct `throw` / `throw_ref` arms that skip the later write/get path, and root/block terminal `return`/direct `return_call` / `return_call_indirect` / `return_call_ref`, root non-final `return`/`return_call`/`return_call_indirect`/`return_call_ref` tails before already-dominated unreachable-tail gets, if-arm nested block terminal `return`/`throw`, and root/block terminal `throw`/`throw_ref` after dominated gets, and `try_table` bodies whose gets are dominated inside the try body, including terminal body `return`/`throw`/`throw_ref`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/`throw_ref`/tail-call tails with already-dominated tail gets. It also has source-backed fallback guards for branch-free loop writes before an outside get, all-arm `if` writes before an outside get, block writes followed by branch flow before an outside get, `try_table` body writes before an outside get, `br_if` paths that can skip a later block write, direct block-return flow whose Binaryen non-null output is currently rejected by `wasm-tools` and Starshine validation, raw-unreachable-before-write tee/get flow whose reduced Binaryen non-null output is rejected by `wasm-tools`, and parameter writes that leave the function signature nullable; broader `try_table`/EH flow beyond the raw assignment subset, branch/return/tail-call/throw dominance beyond these narrowed branch/return/tail-call/if-arm terminal-return-or-throw/terminal-control subsets, broader loop/control-flow dominance and loop post-state non-null propagation, broader `if` post-state joins, and the two nondefaultable-local validator boundaries are still open. The dedicated `local-subtyping-all` GenValid aggregate now exists for closeout evidence and samples straight-line, branch-free structured, and root return/unreachable-tail dominance trigger modules.
- The 2026-07-04 final closeout refresh after the ref-catch raw-assignment fix passed focused LS tests (`73/73`), `moon info`, `moon fmt`, `moon test src/passes` (`3983/3983`), full `moon test` (`7390/7390`), and native `src/cmd` build with pre-existing warnings. Direct regular GenValid `.tmp/pass-fuzz-local-subtyping-genvalid-100000-20260704-refcatch` compared/normalized `100000/100000` with zero failures. Explicit wasm-smith `.tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260704-refcatch` compared `9956/10000`, normalized `9955`, had zero validation/generator/property failures, `44` Binaryen/tool command failures, and one raw mismatch; the mismatch is agent-classified as pass-independent `drop(unreachable)` cleanup debris and becomes the sole cleanup-normalized match in `.tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260704-refcatch-unreachable-normalized`. Dedicated `local-subtyping-all` `.tmp/pass-fuzz-local-subtyping-genvalid-all-10000-20260704-refcatch` and broad random-all-profiles `.tmp/pass-fuzz-local-subtyping-random-all-profiles-10000-20260704-refcatch` both compared/normalized `10000/10000` with zero failures. The 2026-07-04 ordered GC/local neighborhood rerun `.tmp/pass-fuzz-local-subtyping-gc-local-neighborhood-10000-local-cleanup-20260704` remains cleanup-normalized with `634` raw normalized matches plus `9366` cleanup-normalized matches and zero failures, routing that residual to downstream local-cleanup representation owners rather than LS.
- The 2026-07-04 behavior-family matrix refreshed Binaryen `version_130` primary sources for `LocalSubtyping.cpp`, `local-subtyping.wast`, and `local-structural-dominance.h`, confirmed they are byte-identical to the earlier `version_129` sources used by this dossier, and reduced the previous broad blocker list. Implemented/protected families cover body-local assignment LUB narrowing, parameter preservation, conservative non-reference/nondefaultable no-rewrite handling, straight-line/unnamed/branch-free structured dominance, terminal-control and try-body dominated-get subsets, repeated local-get/select/call_ref refinalization, ref-catch skipped-write nullable exact-child raw assignment collection, source-backed nullable post-state fallbacks, and cleanup-normalized residual routing. The two remaining non-implemented LS surfaces are precise validator/tooling boundaries, not Starshine wins: direct block-return nondefaultable-local unreachable-tail and raw-unreachable-before-write nondefaultable-local tee/get. In both reductions Binaryen v130 narrows to non-null, but `wasm-tools` rejects the Binaryen output with `uninitialized local: 1`; Starshine emits validating nullable output. Reopen either boundary if the non-null output starts validating, Starshine validation intentionally adopts a spec-backed proof, Binaryen repairs the shape, or LS can safely repair/avoid the later get while preserving valid wasm. Reopen ref-catch under LS only for a reduced case outside the current raw-assignment skipped-write subset, such as a catch-payload result join or an unknown producer that must narrow without falling back to the declared type.
- The 2026-05-06 direct revalidation lane for `--local-subtyping` reached 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group command failures under seed `0x5eed`.
- The active v0.1.0 `-O4z` LS audit scope is closed as of `1440`: remaining LS deltas are explicit validator/tooling boundaries with reopening criteria, and the known direct wasm-smith / ordered-neighborhood residuals are cleanup-normalized representation debris rather than LS semantic mismatches or measured Starshine wins.

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

- research note 0534
- research note 0507
- research note 0447
- research note 0362
- research note 0261
- research note 0116
- research note 1429
- research note 1430
- research note 1431
- research note 1432
- research note 1433
- research note 1434
- research note 1435
- research note 1438
- research note 1439
- research note 1440
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
