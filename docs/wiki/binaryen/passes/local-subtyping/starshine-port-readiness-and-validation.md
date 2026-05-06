---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0507-2026-05-06-local-subtyping-starshine-active-implementation-correction.md
  - ../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
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
  - ./starshine-strategy.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# Starshine validation and parity gaps for `local-subtyping`

This bridge used to read like a future-port plan. That is stale.
Starshine already ships `local-subtyping`; this page now tracks the active subset and the remaining Binaryen parity gaps.

Use it with:

- [`./starshine-strategy.md`](./starshine-strategy.md) for current Starshine status;
- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream algorithm;
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for exact owner and test surfaces;
- [`./lubs-and-dominance.md`](./lubs-and-dominance.md) for the upstream semantics;
- [`./wat-shapes.md`](./wat-shapes.md) for before/after examples.

## Current local reality

Starshine `local-subtyping` is an active module pass.
The shipped implementation is narrower than Binaryen: it uses write-site evidence to narrow body locals, but it does not yet do get-aware dominance repair, get/tee retagging, or iterative refinalization.

## The current Starshine slice

The shipped slice is:

1. collect write-site types from `local.set` / `local.tee`;
2. compute a safe common reference subtype;
3. rewrite body-local declarations only;
4. rebuild the module only when a body local changes.

That is a valid Starshine pass, but it is only a subset of the upstream contract.

## Exact Starshine code surfaces

| Surface | Why it matters |
| --- | --- |
| `src/passes/local_subtyping.mbt:1-19` | summary and public pass description. |
| `src/passes/local_subtyping.mbt:143-314` | subtype helpers, assignment collection, candidate narrowing, and function rewrite. |
| `src/passes/local_subtyping.mbt:337-362` | active module-pass entrypoint and module rebuild. |
| `src/passes/registry_test.mbt:78-82` | registry category is `module_pass`. |
| `src/passes/optimize.mbt:284-285, 296-312` | registry entry and hot-preset inclusion. |
| `src/passes/pass_manager.mbt:8937-8940` | active dispatcher case. |
| `src/passes/local_subtyping_test.mbt:41-93` | active pass tests for registry lookup and the shipped narrowing cases. |
| `src/cmd/cmd_wbtest.mbt:4376-4439` | end-to-end CLI proof for `--local-subtyping`. |
| `src/passes/optimize_test.mbt:522-526` | preset slot proof in the late local-cleanup neighborhood. |

## What still needs parity work

Compared with Binaryen, Starshine still lacks:

- get-site dominance analysis;
- non-null fallback based on structural dominance;
- get/tee retagging after declaration narrowing;
- repeated refinalize/reanalyze rounds;
- broader shape coverage for parameters, tees, and non-null cases.

Those are the next parity slices, not the current shipped pass.

## Validation ladder

Current coverage should stay green first:

1. registry category proof;
2. body-local narrowing to a child heap type;
3. mixed-sibling common-parent narrowing;
4. CLI `--local-subtyping` end-to-end replay;
5. optimize-preset slot coverage.

Then grow coverage in this order:

1. nullable-to-non-null positives and failures;
2. `local.tee` retagging;
3. get-aware safety / dominance failures;
4. repeated refinement after a narrowing change;
5. parameter preservation and body-local-only scope checks.

## What to avoid saying

Do not call this pass "future-only" or "removed-registry-only".
That was the stale reading corrected by the 2026-05-06 repo-source note.

## Related pages

- [`./index.md`](./index.md) - folder overview
- [`./starshine-strategy.md`](./starshine-strategy.md) - active Starshine status and parity-gap map
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream algorithm and correction history
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - owner and test surface map
- [`./lubs-and-dominance.md`](./lubs-and-dominance.md) - semantics guide
- [`./wat-shapes.md`](./wat-shapes.md) - concrete shapes
- [`../optimize-casts/index.md`](../optimize-casts/index.md) - left neighbor
- [`../coalesce-locals/index.md`](../coalesce-locals/index.md) - right neighbor
- [`../local-cse/index.md`](../local-cse/index.md) - later consumer
