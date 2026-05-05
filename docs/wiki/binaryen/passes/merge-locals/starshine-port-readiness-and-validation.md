---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-merge-locals-current-main-recheck.md
  - ../../../raw/research/0485-2026-05-05-merge-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/validate.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
---

# Starshine port readiness and validation for `merge-locals`

This bridge is for the future Starshine port, not the upstream algorithm.

Use it with:

- [`./index.md`](./index.md) for the folder overview;
- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the corrected upstream algorithm;
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the owner/test map;
- [`./local-graph-and-copy-influences.md`](./local-graph-and-copy-influences.md) for the graph/orientation proof;
- [`./wat-shapes.md`](./wat-shapes.md) for concrete before/after examples;
- [`./starshine-strategy.md`](./starshine-strategy.md) for current local status.

## Current local reality

`merge-locals` is still removed-registry only in Starshine.
There is no owner file, no active dispatcher case, and no dedicated backlog slice yet.
So the first port should be a measured module-local implementation, not a quick HOT peephole.

## The first safe slice

Start with a no-rewrite analyzer that can answer these questions:

1. Which local.set/local.get pairs are actually copy-shaped?
2. What `LocalGraph`-style set-influence facts are needed to compare the source local and destination local?
3. Which influenced gets would move to the source side, and which would move to the destination side?
4. Which candidates fail the type check or post-graph validation?
5. Does the pass still need DWARF invalidation after a successful rewrite?

That slice should stay honest about the existing local model:

- it should not claim generic slot coloring;
- it should not claim full `coalesce-locals` parity;
- it should not change function signatures or heap types;
- it should preserve the pass's DWARF-invalidating nature.

## Exact Starshine code and proof surfaces

| Surface | Why it matters |
| --- | --- |
| `src/passes/optimize.mbt:144-151` | `merge-locals` is still listed in `pass_registry_removed_names()`. |
| `src/passes/optimize.mbt:455-473` | removed-pass requests fail explicitly instead of silently succeeding. |
| `src/passes/registry_test.mbt:171-179` | generic removed-pass request behavior is already tested. |
| `src/passes/pass_manager.mbt:8660-8694` | the active module-pass dispatcher has no `merge-locals` case. |
| [`./local-graph-and-copy-influences.md`](./local-graph-and-copy-influences.md) | the graph/orientation proof surface is explained here because Starshine does not yet have a local graph helper. |
| `src/lib/types.mbt:230-238` | local declarations are grouped, so any future rewrite must preserve local layout. |
| `src/lib/types.mbt:416-420` | functions pair local declarations with the expression body. |
| `src/lib/types.mbt:536-538` | `LocalGet`, `LocalSet`, and `LocalTee` are the relevant instruction nodes. |
| `src/validate/typecheck.mbt:535-558` | local get/set/tee typing must stay sound after any rewrite. |
| `src/validate/validate.mbt` | module-level declaration validity matters if local identity changes. |
| `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33` | the late local-cleanup neighborhood is the right place to reason about future adjacency, even though `merge-locals` itself is not on the default path. |
| `agent-todo.md` | there is still no dedicated `merge-locals` execution slice. |

## Why this cannot be a HOT-only patch

A faithful port has to touch module-local declaration state and validator-visible typing.
That means the implementation shape is probably:

1. detect copy-shaped local traffic;
2. compare source-side and destination-side ownership with `LocalGraph`-style influences;
3. rewrite influenced gets only when the orientation is safe;
4. verify the rewrite after mutation;
5. keep DWARF invalidation explicit.

The graph helper itself is still a future addition; the current repo only proves the registry, dispatcher, validator, and local-declaration surfaces.

If Starshine starts with HOT-only rewrite logic, it will miss the local-graph proof and the post-rewrite rollback behavior.

## Validation ladder

A future port should land tests in this order:

1. analyzer-only copy-shape recognition;
2. source-side ownership positives;
3. destination-side ownership positives;
4. type-mismatch negatives;
5. post-graph rollback cases;
6. conservative `between-unreachable` regression;
7. Binaryen pass-targeted parity comparison at the repo standard scale.

Then add the neighborhood tests once the surrounding local passes exist:

- `heap2local -> merge-locals -> optimize-casts`
- `optimize-casts -> local-subtyping`
- `local-subtyping -> coalesce-locals -> local-cse`

## Open question

The only unresolved shape question here is whether Starshine should keep `merge-locals` as removed-registry-only until a real module owner lands, or first expose a boundary-only request spelling.
The current wiki keeps the honest answer as removed-registry only.

## Related pages

- [`./index.md`](./index.md) - folder overview
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream algorithm and correction history
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - owner and test surface map
- [`./local-graph-and-copy-influences.md`](./local-graph-and-copy-influences.md) - graph/orientation guide
- [`./wat-shapes.md`](./wat-shapes.md) - concrete shapes
- [`./starshine-strategy.md`](./starshine-strategy.md) - current removed-registry / no-dispatcher status
- [`../optimize-casts/index.md`](../optimize-casts/index.md) - left neighbor
- [`../local-subtyping/index.md`](../local-subtyping/index.md) - later local-cleanup neighbor
- [`../coalesce-locals/index.md`](../coalesce-locals/index.md) - later consumer
