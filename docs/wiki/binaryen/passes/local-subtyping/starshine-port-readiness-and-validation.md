---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
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
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# Starshine port-readiness and validation for `local-subtyping`

This bridge is for the future Starshine port, not the upstream algorithm.

Use it with:

- [`./starshine-strategy.md`](./starshine-strategy.md) for current local status;
- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream algorithm;
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for exact owner/test surfaces;
- [`./lubs-and-dominance.md`](./lubs-and-dominance.md) for the tricky semantics;
- [`./wat-shapes.md`](./wat-shapes.md) for before/after examples.

## Current local reality

`local-subtyping` is still removed-registry only in Starshine.
There is no owner file and no dispatcher case yet.
So the first port should be a measured module-local implementation, not a quick HOT peephole.

## The first safe slice

Start with a helper-only slice that can answer these questions:

1. Which body locals are reference-typed and eligible for narrowing?
2. What LUB does each local get from its assigned values?
3. Which gets block non-nullability?
4. Which gets and tees need retagging after a declaration change?
5. Does a second refinalize/reanalyze round expose more narrowing?

That slice should stay honest about the ABI boundary:

- parameters are preserved;
- body-local declarations are rewritten from the body-local base onward;
- non-reference and tuple/nondefaultable shapes stay out of the first rewrite surface.

## Exact Starshine code surfaces

| Surface | Why it matters |
| --- | --- |
| `src/passes/optimize.mbt:143-151` | `local-subtyping` is still in `pass_registry_removed_names()`. |
| `src/passes/optimize.mbt:272-278` | removed names become unsupported pass entries. |
| `src/passes/pass_manager.mbt:8688-8704` | the hot-pass dispatcher has no `local-subtyping` case. |
| `src/passes/optimize_test.mbt:390-395` | preset-honesty coverage keeps neighboring local passes out until the cluster is real. |
| `src/lib/types.mbt:55-65` | `RefType` / `ValType` model the reference-local types this pass rewrites. |
| `src/lib/types.mbt:230-238` | `Locals` stores the body-local declaration runs. |
| `src/lib/types.mbt:416-420` | `Func` pairs declaration runs with the expression body. |
| `src/lib/types.mbt:536-538` | `LocalGet`, `LocalSet`, and `LocalTee` are the relevant instruction nodes. |
| `src/validate/typecheck.mbt:535-558` | validator typing reads the current declaration type, so declaration rewrites must stay type-safe. |
| `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33` | canonical neighborhood: `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse`. |
| `agent-todo.md:372-383` | backlog slice `LS` is the durable planning anchor. |

## Why this cannot be a HOT-only patch

A faithful port has to touch module-local declaration state and validator-visible typing.
That means the implementation shape is probably:

1. analyze locals and candidate types;
2. rewrite `Locals`;
3. repair `local.get` / `local.tee` expression types;
4. repeat after refinalization;
5. only then consider whether any HOT helper should be reused.

If Starshine starts with HOT-only rewrite logic, it will miss the declaration table and the non-dominated-get fallback behavior.

## Validation ladder

A future port should land tests in this order:

1. body-local reference narrowing from assignments;
2. common-parent LUB selection;
3. `local.tee` retagging;
4. non-null positives and dominance failures;
5. repeated refinement after refinalization;
6. parameter preservation;
7. non-reference and tuple/nondefaultable preservation;
8. neighborhood ordering with `optimize-casts`, `coalesce-locals`, and `local-cse`.

Then add a Binaryen comparison lane for the implemented slice before widening to the next local-cleanup neighbor.

## Open question

The only unresolved shape question here is file ownership: the repo currently proves the absence of an implementation file, but not the eventual filename or whether the first landing is split across a helper module plus dispatcher wiring.

## Related pages

- [`./index.md`](./index.md) - folder overview
- [`./starshine-strategy.md`](./starshine-strategy.md) - current removed-registry / no-dispatcher status
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream algorithm and correction history
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - owner and test surface map
- [`./lubs-and-dominance.md`](./lubs-and-dominance.md) - semantics guide
- [`./wat-shapes.md`](./wat-shapes.md) - concrete shapes
- [`../optimize-casts/index.md`](../optimize-casts/index.md) - left neighbor
- [`../coalesce-locals/index.md`](../coalesce-locals/index.md) - right neighbor
- [`../local-cse/index.md`](../local-cse/index.md) - later consumer
