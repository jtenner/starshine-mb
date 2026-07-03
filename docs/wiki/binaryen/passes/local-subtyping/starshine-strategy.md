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
The current implementation is a narrower subset that narrows body locals from write-site evidence, with early nullable-to-non-null declaration narrowing when every observed `local.get` is after a dominating write in a straight-line root, inside a branch-free `block` or `loop` entered after that write, inside branch-free nested `if` arms in such a dominated region, or inside branch-free root `if` arms entered after that write.

## Exact local code map today

- `src/passes/local_subtyping.mbt:1-19`
  - summary and public pass description.
- `src/passes/local_subtyping.mbt:143-581`
  - heap subtype helpers, assignment collection, candidate narrowing, straight-line/branch-free block/loop/nested-if/root-if dominance scanning, and function-local rewrite.
- `src/passes/local_subtyping.mbt:582-613`
  - active module-pass entrypoint and module rebuild.
- `src/passes/registry_test.mbt:78-82`
  - registry category proof: `local-subtyping` is a module pass.
- `src/passes/optimize.mbt:284-285, 296-312`
  - registry entry plus `optimize` / `shrink` preset inclusion.
- `src/passes/pass_manager.mbt:8937-8940`
  - active hot-pass dispatcher case.
- `src/passes/optimize_test.mbt:491-495, 522-526`
  - preset honesty plus exact local-subtyping slot placement in the optimize preset.
- `src/passes/local_subtyping_test.mbt:41-431`
  - direct active-pass tests for registry lookup, write-site narrowing, tee assignments, straight-line non-null dominance, branch-free block/loop dominance/fallback, branch-free nested block-if dominance, and branch-free root-if dominance/fallback.
- `src/cmd/cmd_wbtest.mbt:4376-4439`
  - CLI integration test for `--local-subtyping` on wasm inputs.

## What the current implementation actually does

The current Starshine code path is intentionally small:

1. lift each function into HOT form;
2. collect assignment result types from `local.set` and `local.tee`;
3. pre-scan the raw straight-line body, branch-free `block`/`loop` bodies, branch-free nested `if` arms inside such dominated regions, and branch-free root `if` arms to decide where a nullable local may safely become non-null because reads are dominated by an earlier write;
4. pick the most specific safe common reference subtype, falling back to nullable when dominance is not proven;
5. rewrite body-local declarations only;
6. rebuild the module if any body local changed.

That gives Starshine a real, active `local-subtyping` pass without pretending to have the whole upstream contract yet.

## What is still missing versus Binaryen

Compared with the upstream Binaryen strategy, Starshine still lacks:

- full structural get-site dominance analysis for loops with backedges or post-state joins, EH bodies, `block`/`if` bodies with branch/return/throw control flow, and broader `if` join/post-state cases;
- broad non-null fallback based on Binaryen's structural-dominance proof rather than the current straight-line, branch-free block/loop, and root branch-free-`if` subset;
- get/tee expression retagging after declaration narrowing;
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

The newest LS audit slices add focused coverage for direct `local.tee` assignments, straight-line nullable-to-non-null narrowing after a dominating write, branch-free `block` and `loop` gets dominated by an earlier write, gets inside a branch-free nested `if` in a dominated region, branch-free root `if` gets dominated by an earlier write, and nullable fallback when a `local.get` can observe the default value before the first write or inside an earlier block/if arm. The straight-line, block, loop, nested block-if, and root-if non-null positives were red before implementation; optimized modules are validated after narrowing.

The next full-contract parity tests should cover:

1. structured-control dominance positives and negatives beyond branch-free `block`/`loop` bodies and branch-free root `if` arms;
2. `local.get` / `local.tee` expression retagging after declaration narrowing;
3. repeated refinement after a pass change;
4. parameter preservation versus body-local rewrite scope;
5. pass-specific GenValid profile coverage for LS assignment/dominance families.

## Bottom line

`local-subtyping` in Starshine is real and active today.
The ongoing work is now parity expansion, not first landing.
