---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-reorder-functions-by-name-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md
  - ../../../raw/research/0481-2026-05-05-reorder-functions-by-name-current-main-recheck.md
  - ../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./lexical-order-proof-and-boundaries.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ../reorder-functions/index.md
  - ../reorder-globals/index.md
  - ../reorder-locals/index.md
  - ../reorder-types/index.md
---

# Starshine `reorder-functions-by-name` port-readiness and validation

## Current status

Starshine does **not** implement `reorder-functions-by-name` today.

The local facts are:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt):137-138 lists `reorder-functions-by-name` in the boundary-only registry
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only names instead of running a transform
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) has no `reorder-functions-by-name` module-pass case
- [`agent-todo.md`](../../../../../agent-todo.md) has no dedicated active slice
- there is no owner file yet

So this pass remains a tracked boundary-only name, not a hot pass and not a module pass.

## Why this is a module pass

Binaryen's pass only sorts the function declaration list by internal name.
Starshine's lowered module must also:

- preserve the import prefix
- reorder defined functions with paired `func_sec` / `code_sec`
- remap every `FuncIdx`-bearing surface if numeric indices change
- keep metadata and writer output coherent after the permutation

That makes the implementation a module-level permutation plus remap, not a body peephole.

## Exact local code locations

- `src/passes/optimize.mbt:137-138` - boundary-only registry entry
- `src/passes/pass_manager.mbt` - no module-pass dispatch case yet
- `src/lib/types.mbt` - module sections and numeric `FuncIdx` surfaces
- `src/passes/remove_unused_module_elements.mbt` - closest in-tree function-index remap helper cluster
- `src/binary/encode.mbt` - module writer follows the existing section order
- `src/wast/lower_to_lib.mbt` - textual names are lowered to numeric `FuncIdx` values
- `agent-todo.md` - no active implementation slice

## Minimal future validation ladder

1. keep rejecting the name until the real implementation lands
2. sort declared functions by ascending internal name
3. keep imports in their chosen position and test that decision explicitly
4. keep `func_sec` and `code_sec` paired
5. remap every `FuncIdx` surface after any permutation
6. preserve function bodies except for numeric repair
7. validate and round-trip the output
8. compare focused fixtures against Binaryen's `--reorder-functions-by-name`

## Open design question

Should Starshine reorder only defined functions after the import prefix, or also touch imports? Binaryen's source only sorts `module->functions`, so the local answer should stay explicit until implementation.

## Bridge pages

- [`./index.md`](./index.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./lexical-order-proof-and-boundaries.md`](./lexical-order-proof-and-boundaries.md)
- [`./module-shapes.md`](./module-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../reorder-functions/index.md`](../reorder-functions/index.md)

## Current conclusion

Treat `reorder-functions-by-name` as boundary-only today, with a clear module-pass gap and a clear remap surface for a future port.
