---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-reorder-functions-current-main-recheck.md
  - ../../../raw/research/0475-2026-05-05-reorder-functions-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-04-reorder-functions-current-main-recheck.md
  - ../../../raw/research/0439-2026-05-04-reorder-functions-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-reorder-functions-primary-sources.md
  - ../../../raw/research/0297-2026-04-24-reorder-functions-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./count-surfaces-ordering-and-omissions.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ../reorder-functions-by-name/index.md
---

# Starshine `reorder-functions` port-readiness and validation

## Current status

Starshine still does **not** implement `reorder-functions`.

The current local facts are:

- `src/passes/optimize.mbt` registers `reorder-functions` and `reorder-functions-by-name` as boundary-only names.
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only names before module-pass dispatch.
- `src/passes/pass_manager.mbt` has no `reorder-functions` module-pass case.
- `agent-todo.md` has no dedicated active implementation slice.
- the nearest in-tree reference-rewrite helper cluster is still `src/passes/duplicate_function_elimination.mbt`, but that code solves duplicate-survivor remapping, not a total function permutation.

So the honest status remains: name known, request rejected, future module-pass shape not yet implemented.

## Why this is a module pass

Binaryen's contract changes module layout, not function bodies:

- function ordering changes
- `Call` / `ReturnCall` / `RefFunc` users must be remapped if indices move
- start / export / element / annotation surfaces can also point at function indices
- import-prefix versus defined-function ordering has to be decided explicitly in Starshine's lower-level model

That makes the pass a module-wide permutation + remap problem, not a HOT peephole.

## Exact local code locations

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt):137, 482, 552
  - boundary-only registry lists for `reorder-functions` and `reorder-functions-by-name`
  - `run_hot_pipeline_expand_passes(...)` rejects boundary-only names
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt):8912-8940
  - `run_hot_pipeline_apply_module_pass(...)` has cases for `reorder-locals`, `reorder-globals`, `directize`, and others, but not `reorder-functions`
- [`src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt)
  - closest local remap helper cluster for function-index-dependent surfaces
- [`src/lib/types.mbt`](../../../../../src/lib/types.mbt)
  - module layout and `FuncIdx`-carrying instruction surfaces the future permutation must repair
- [`agent-todo.md`](../../../../../agent-todo.md)
  - no dedicated `reorder-functions` slice today

## Minimum future validation ladder

1. registry keeps rejecting the pass until the real module implementation lands
2. direct-call count ordering matches Binaryen
3. start, export, and element-segment counts match Binaryen
4. descending-name tie breaking matches Binaryen
5. `ref.func` stays non-counting unless the port deliberately changes parity
6. declaration-section mentions stay non-counting unless the port deliberately changes parity
7. imported and defined function ordering is clarified and tested
8. every function-index surface is remapped after any permutation
9. function bodies remain semantically unchanged aside from required index repair
10. local validation proves the new module-pass output still round-trips and validates

## Open design question

The main unresolved local question is whether Starshine should permute imported functions inside `import_sec` or only reorder defined functions after the import prefix. Binaryen's teaching contract does not force a local answer, so this should stay explicit until the implementation decision is made.

## Bridge pages

- [`index.md`](./index.md) - entry point and maintenance notes
- [`binaryen-strategy.md`](./binaryen-strategy.md) - upstream contract
- [`implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - owner files and proof surfaces
- [`count-surfaces-ordering-and-omissions.md`](./count-surfaces-ordering-and-omissions.md) - exact counting surfaces and omissions
- [`module-shapes.md`](./module-shapes.md) - concrete before/after shape families
- [`starshine-strategy.md`](./starshine-strategy.md) - current local boundary-only status
- [`../reorder-functions-by-name/index.md`](../reorder-functions-by-name/index.md) - sibling lexical-order pass

## Current conclusion

Treat `reorder-functions` as **boundary-only with a ready-made module-pass gap**. The wiki now has the local code map needed to start a faithful port without confusing it with the sibling lexical pass or the duplicate-elimination remap helpers.
