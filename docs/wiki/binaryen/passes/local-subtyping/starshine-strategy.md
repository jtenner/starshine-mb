---
kind: concept
status: supported
last_reviewed: 2026-07-03
sources:
  - ../../../raw/research/0534-2026-05-06-local-subtyping-direct-revalidation.md
  - ../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md
  - ../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
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
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
---

# Starshine strategy for `local-subtyping`

Use this page together with the corrected Binaryen source manifest in [`../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md), the source-correction note in [`../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md`](../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md), the upstream implementation/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), and the validation bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

The 2026-05-06 repo-source correction replaced an older stale reading: `local-subtyping` is already active in Starshine.

## Honest current status

`local-subtyping` is an active Starshine module pass.

It has:

- a real owner file;
- a registry entry;
- a dispatcher case;
- CLI support via `--local-subtyping`;
- preset-slot coverage in the default hot optimize path.

What it does **not** have yet is full Binaryen parity.
The current implementation is a narrower subset that narrows body locals from write-site evidence, with early nullable-to-non-null declaration narrowing when every observed `local.get` is after a dominating write in a straight-line root, inside a branch-free `block` or `loop` entered after that write, inside the source-backed loop tail-`br_if` backedge case entered after that write, after a branch-free `block` write that dominates a later outer get, before a terminal `br` / `br_table` whose branch does not need to propagate writes to an outer post-state, inside branch-free nested `if` arms in such a dominated region, inside branch-free root `if` arms entered after that write, inside direct `return_call`, `return_call_indirect`, `return_call_ref`, or `throw` if-arms that skip a later dominating write/get path, or before a root/block terminal `return`, direct `return_call`, `return_call_indirect`, or `return_call_ref`, a nested block terminal `return` or `throw` inside a return/return_call/throw-skipped `if` arm, root/block terminal `throw`, or a `try_table` body whose get is dominated by that write, including terminal body `return`/`throw`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/tail-call tails whose later gets are already dominated. It also has source-backed nullable fallback guards for loop writes before outside gets, all-arm `if` writes before outside gets, block writes followed by branch flow before outside gets, `try_table` body writes before outside gets, `br_if` paths that can skip a later block write, and parameter writes that leave signature params unchanged, plus focused validation for non-null `local.tee` assignment/use narrowing.

## Exact local code map today

- `src/passes/local_subtyping.mbt:1-19`
  - summary and public pass description.
- `src/passes/local_subtyping.mbt:143-590`
  - heap subtype helpers, assignment collection, candidate narrowing, straight-line/block/loop/nested-if/root-if dominance scanning including the narrow tail-`br_if` loop-backedge subset, branch-free block write post-state propagation, terminal `br` / `br_table` dominated-get admission without outer post-state propagation, root/block terminal-`return`/direct `return_call`/`return_call_indirect`/`return_call_ref`, if-arm nested block terminal-`return`/`throw`, root/block terminal-`throw`, and `try_table` body dominated-get admission including terminal body `return`/`throw`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/tail-call tails with already-dominated gets, and function-local rewrite.
- `src/passes/local_subtyping.mbt:591-622`
  - active module-pass entrypoint and module rebuild.
- `src/passes/registry_test.mbt:78-82`
  - registry category proof: `local-subtyping` is a module pass.
- `src/passes/optimize.mbt:284-285, 296-312`
  - registry entry plus `optimize` / `shrink` preset inclusion.
- `src/passes/pass_manager.mbt:8937-8940`
  - active hot-pass dispatcher case.
- `src/passes/optimize_test.mbt:491-495, 522-526`
  - preset honesty plus exact local-subtyping slot placement in the optimize preset.
- `src/passes/local_subtyping_test.mbt`
  - direct active-pass tests for registry lookup, write-site narrowing, tee assignments, straight-line non-null dominance, branch-free block/loop dominance/fallback, loop tail-`br_if` backedge dominance, terminal `br` / `br_table` dominated-get narrowing, branch-free block-write post-state propagation, branch-free nested block-if dominance, source-backed nullable loop/if/branch-flow/`br_if`-skipped-write post-state fallback, parameter preservation, branch-free root-if dominance/fallback, root/block terminal-return and direct return_call, direct if-arm return_call/throw-skip, if-arm nested block terminal-return/throw, and root/block terminal-throw dominance, and try_table body dominance including terminal body `return`/`throw`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/tail-call tails with already-dominated gets.
- `src/cmd/cmd_wbtest.mbt:4376-4439`
  - CLI integration test for `--local-subtyping` on wasm inputs.

## What the current implementation actually does

The current Starshine code path is intentionally small:

1. lift each function into HOT form;
2. collect assignment result types from `local.set` and `local.tee`;
3. pre-scan the raw straight-line body, branch-free `block` bodies, branch-free block writes before later outer gets, terminal `br` / `br_table` block bodies whose gets are already dominated before the branch, `loop` bodies entered after prior writes including the narrow source-backed tail-`br_if` backedge subset, branch-free nested `if` arms inside such dominated regions, branch-free root `if` arms, conditional-`return` branches, direct `return_call` / `return_call_indirect` / `return_call_ref` arms, and direct `throw` arms that skip a later write/get path, and root/block terminal `return`/direct `return_call` / `return_call_indirect` / `return_call_ref`, if-arm nested block terminal `return`/`throw`, root/block terminal `throw`, or a `try_table` body (non-throwing, ending in terminal body `return`/`throw`, or containing a source-backed non-final body `return`/`throw` before already-dominated unreachable-tail gets) after dominated gets to decide where a nullable body local may safely become non-null because reads are dominated by an earlier write, while keeping nullable fallbacks at the source-backed loop/if/branch-flow post-state boundaries, direct block-return validator boundary, try-table body post-state boundary, `br_if` paths that can skip writes, and preserving parameters as signature-owned locals;
4. pick the most specific safe common reference subtype, falling back to nullable when dominance is not proven;
5. rewrite body-local declarations only;
6. rebuild the module if any body local changed.

That gives Starshine a real, active `local-subtyping` pass without pretending to have the whole upstream contract yet.

## What is still missing versus Binaryen

Compared with the upstream Binaryen strategy, Starshine still lacks:

- full structural get-site dominance analysis for loops with backedges or post-state joins beyond the tail-`br_if` dominated-get subset, broader EH / `try_table` bodies, `block`/`if` bodies with branch/return/return_call/throw control flow beyond the terminal `br` / `br_table` dominated-get, conditional-`return`/direct-`return_call`/direct-`return_call_indirect`/direct-`return_call_ref`/direct-`throw` branch, root/block terminal-`return`/direct `return_call`/`return_call_indirect`/`return_call_ref`, if-arm nested block terminal-`return`/`throw`, root/block terminal-`throw`, and source-backed `try_table` non-final body-`return`/`throw` tail subsets, and broader `if` join/post-state cases; branch-free `block` write post-state propagation is covered, while loop write post-state, all-arm `if` write post-state, branch-skipped writes, branch-flow block post-state, try-table body post-state, and direct block-return flow are nullable/tooling fallbacks rather than non-null propagation cases;
- broad non-null fallback based on Binaryen's structural-dominance proof rather than the current straight-line, branch-free block/loop, block-write post-state, and root branch-free-`if` subset;
- broad get/tee expression retagging after declaration narrowing; a focused non-null `local.tee` assignment/use fixture validates with Starshine's current representation, but the wider Binaryen retagging contract remains open;
- repeated refinalize/reanalyze rounds;
- the broader set of official test shapes around params, structured tees, non-nullability, and repeated refinement.

So the right mental model is:

- **active pass**: yes;
- **full Binaryen parity**: no.

## Validation posture

Current shipped coverage proves:

- registry category is active module-pass;
- the pass narrows a body local to a child heap type;
- mixed sibling writes keep the common parent type;
- the CLI path accepts `--local-subtyping`;
- the default optimize preset keeps the pass in the `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` neighborhood.

The 2026-05-06 refreshed direct pass signoff ran `moon info`, `moon fmt`, `moon test`, and `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-subtyping --out-dir .tmp/pass-fuzz-local-subtyping`. The fuzz lane reported 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures.

The newest LS audit slices add focused coverage for direct `local.tee` assignments including non-null tee assignment/use validation, straight-line nullable-to-non-null narrowing after a dominating write, branch-free `block` and `loop` gets dominated by an earlier write, a source-backed loop tail-`br_if` backedge get dominated by an earlier write, branch-free `block` writes that dominate later outer gets, terminal `br` / `br_table` block bodies whose gets are already dominated before the branch, gets inside a branch-free nested `if` in a dominated region, branch-free root `if` gets dominated by an earlier write, conditional-`return` branches, direct `return_call`, `return_call_indirect`, and `return_call_ref` arms, and direct `throw` arms that skip the later write/get path, root/block terminal `return` and direct `return_call` / `return_call_indirect` / `return_call_ref` after a dominated get, if-arm nested block terminal `return`/`throw` after a dominated get, root/block terminal `throw` after a dominated get, `try_table` body dominated gets including terminal body `return`/`throw`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/tail-call tails with already-dominated tail gets, and nullable fallback when a `local.get` can observe the default value before the first write, inside an earlier block/if arm, after a branch-free loop write, after all-arm `if` writes, after a block write followed by branch flow before a later outside get, when a `br_if` can skip a later block write, or at the direct block-return validator boundary. The straight-line, block-entry, block-write post-state, terminal-branch, loop-entry, loop-backedge, nested block-if, root-if, conditional-return, direct return_call/return_call_indirect/return_call_ref skip, direct-throw skip, root/block terminal-return/return_call/return_call_indirect/return_call_ref, if-arm nested block terminal-return/throw, root/block terminal-throw, and try_table body non-null positives including terminal body `return`/`throw`/`return_call`/`return_call_indirect`/`return_call_ref` and non-final body `return`/`throw`/tail-call tails were red before implementation or source-backed and now protected; optimized modules are validated after narrowing.

The next full-contract parity tests should cover:

1. structured-control dominance positives and negatives beyond branch-free `block` bodies, branch-free `loop` entry bodies, branch-free root `if` arms, and the now-covered branch-free block-write post-state case;
2. `local.get` / `local.tee` expression retagging after declaration narrowing;
3. repeated refinement after a pass change;
4. broader body-local/parameter boundary coverage beyond the now-guarded source-backed parameter-preservation fixture;
5. pass-specific GenValid profile coverage for LS assignment/dominance families.

## Bottom line

`local-subtyping` in Starshine is real and active today.
The ongoing work is now parity expansion, not first landing.
