---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0447-2026-05-05-local-subtyping-current-main-recheck.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lubs-and-dominance.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
---

# Starshine strategy for `local-subtyping`

Use this page together with the corrected Binaryen source manifest in [`../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md), the older source-correction manifest in [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md), and the upstream implementation/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

The 2026-05-05 recheck did not change the local status; it only refreshes provenance.

## Honest current status

`local-subtyping` is still **unimplemented** in Starshine.

There is no `src/passes/local_subtyping.mbt` owner file and no active dispatcher case. The current local strategy is:

- track the upstream pass spelling;
- keep the `LS` backlog slice visible;
- preserve honest preset placement until this and its neighboring local passes land;
- point a future port at the exact Starshine type, local, validator, and scheduler surfaces it would need.

## Exact local code map today

- `src/passes/optimize.mbt:144-151`
  - `pass_registry_removed_names()` includes `"local-subtyping"`.
- `src/passes/optimize.mbt:272-278`
  - removed names are registered as removed entries, so active requests are known but unsupported.
- `src/passes/pass_manager.mbt:8688-8704`
  - active hot-pass dispatch lists implemented HOT passes and has no `local-subtyping` case.
- `src/passes/optimize_test.mbt:390-395`
  - test locks that `optimize` and `shrink` do not schedule `reorder-locals` before neighboring local passes land.
- `agent-todo.md:372-383`
  - `LS` backlog slice: local type narrowing core plus ordering/artifact proof.
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33`
  - canonical local-cleanup neighborhood: `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`.

## Exact prerequisite implementation surfaces

A future port is not just a HOT peephole. It must update function-local declarations and expression typing.

Current reusable local surfaces include:

- `src/lib/types.mbt:55-65`
  - `RefType` and `ValType` model reference and value types.
- `src/lib/types.mbt:230-238`
  - `LocalRun` / `Locals` store grouped body-local declarations.
- `src/lib/types.mbt:416-420`
  - `Func` pairs `Locals` with the expression body.
- `src/lib/types.mbt:536-538`
  - `LocalGet`, `LocalSet`, and `LocalTee` instruction constructors.
- `src/validate/typecheck.mbt:535-558`
  - local get/set/tee validation reads from the local declaration type.
- `src/ir/hot_core.mbt:150-178`
  - HOT local metadata separates params and locals; if the implementation becomes HOT-aware, this split must stay aligned with the module-level `Locals` table.

## What Starshine currently does for this pass name

### 1. The name is tracked, not forgotten

The upstream spelling remains in the removed-name registry. That keeps docs, help/error behavior, backlog, and tracker entries connected instead of letting the pass disappear from planning.

### 2. Active execution is intentionally absent

Because no implementation exists, the pass manager cannot dispatch `local-subtyping`. That is correct. A fake declaration-only pass would be worse than no pass because Binaryen's real contract also includes get/tee repair, non-null dominance, and repeated refinement.

### 3. Preset placement remains conservative

`local-subtyping` sits in a cluster that Starshine cannot honestly schedule yet:

- `optimize-casts` is still removed;
- `local-subtyping` is still removed;
- `coalesce-locals` is still removed;
- `local-cse` is still removed;
- `reorder-locals` is implemented but intentionally excluded from `optimize` / `shrink` until the surrounding local passes make the slot story honest.

## The right future Starshine implementation shape

A faithful port should be a function-wide local declaration/type repair pass, not a pure expression peephole.

Minimum source-faithful shape:

1. scan reference-typed locals and collect set/tee plus get sites;
2. compute set-fed LUB candidates for body locals;
3. preserve parameter declarations;
4. prove non-nullability with structured dominance over gets;
5. rewrite body-local declaration runs;
6. retag safe `local.get` and all affected `local.tee` expression types;
7. refinalize or otherwise repair expression types and repeat until stable;
8. preserve non-reference, tuple-like, and nondefaultable unsafe cases.

The likely local landing zone is module- or function-boundary-aware because declaration runs live outside a single interior HOT region. HOT metadata may still be useful, but a final implementation must write back the module's `Locals` and keep validator behavior aligned.

## Neighbor dependency map

- [`../optimize-casts/index.md`](../optimize-casts/index.md)
  - left neighbor; can expose cleaner reference assignment types.
- [`../coalesce-locals/index.md`](../coalesce-locals/index.md)
  - right neighbor; benefits from exact local types after subtyping.
- [`../local-cse/index.md`](../local-cse/index.md)
  - later consumer of cleaner local traffic.
- [`../reorder-locals/index.md`](../reorder-locals/index.md)
  - implemented comparison point for module-owned local declaration/index rewrite and preset-honesty constraints.

## Validation plan for the eventual port

A future implementation should validate in this order:

1. reduced pass tests for:
   - body-local reference narrowing;
   - common-parent LUBs;
   - `local.tee` retagging;
   - non-null dominance positives and failures;
   - repeated refinement;
   - param preservation;
   - non-reference and tuple/nondefaultable preservation.
2. validator-backed tests showing `local.get`, `local.set`, and `local.tee` expression typing remains sound after declaration rewrites.
3. scheduler interaction tests for:
   - `optimize-casts -> local-subtyping`;
   - `local-subtyping -> coalesce-locals`;
   - `coalesce-locals -> local-cse`.
4. artifact/oracle comparison for the `LS` backlog slice and the canonical no-DWARF debug-artifact path.

## Bottom line

Current Starshine `local-subtyping` strategy is tracked absence plus a precise port map:

- no transform yet;
- upstream spelling retained in the removed registry;
- no dispatcher case;
- backlog slice `LS` visible;
- exact type/local/validator/HOT prerequisites identified;
- source correction recorded so a future implementation does not copy either stale overread: neither generic `LocalUpdater` local inference nor set-only no-get/no-refinalize simplification.
