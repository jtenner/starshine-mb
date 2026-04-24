---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md
  - ../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
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
  - ../reorder-functions/starshine-strategy.md
  - ../reorder-locals/starshine-hot-ir-strategy.md
  - ../remove-unused-module-elements/starshine-hot-ir-strategy.md
---

# Starshine strategy for `reorder-functions-by-name`

## Current local status

Starshine does **not** implement `reorder-functions-by-name` today.

The exact local state is:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lists `reorder-functions-by-name` in `pass_registry_boundary_only_names()`.
- `HotPassRegistryCache::new()` only includes hot passes and presets in `help_entries`, so boundary-only names are tracked but not advertised as active optimizer help entries.
- `run_hot_pipeline_expand_passes(...)` rejects an explicit request with the standard boundary-only-not-implemented error.
- `optimize_preset_passes(...)` and `shrink_preset_passes(...)` do not include the pass.
- `agent-todo.md` has no active `reorder-functions-by-name` slice.

So the safe user-facing statement is:

- Starshine recognizes the name as a future/boundary pass, but no module transform runs for it.

## Why this is a module pass, not a HOT pass

Binaryen's pass sorts the module-level function declaration list. That is outside Starshine's current HOT function-body pass model.

A future port would need to mutate whole-module section order and rewrite all numeric function-index users. It should therefore be designed as a module pass, closer to [`../remove-unused-module-elements/starshine-hot-ir-strategy.md`](../remove-unused-module-elements/starshine-hot-ir-strategy.md) and [`../reorder-functions/starshine-strategy.md`](../reorder-functions/starshine-strategy.md) than to a HOT peephole.

## Starshine surfaces a future port must update

### Function declaration and body order

[`src/lib/types.mbt`](../../../../../src/lib/types.mbt) models the relevant module surfaces separately:

- `func_sec : FuncSec?`
- `code_sec : CodeSec?`
- `import_sec : ImportSec?`
- `export_sec : ExportSec?`
- `start_sec : StartSec?`
- `elem_sec : ElemSec?`
- `name_sec : NameSec?`
- `func_annotation_sec : FuncAnnotationSec?`

`FuncSec` stores defined-function type indices and `CodeSec` stores defined-function bodies. A by-name reorder must keep those two defined-function arrays in lockstep while preserving the imported-function prefix.

### Numeric function references

The lowered Starshine module uses numeric `FuncIdx` references. A faithful reorder must remap every function-index-bearing surface, including:

- direct `call`,
- `return_call`,
- `ref.func`,
- element segment function lists,
- element segment expression initializers that contain `ref.func`,
- function exports,
- `start_sec`,
- name-section function/local/label maps,
- and function annotations.

This is the main difference between Binaryen's tiny source file and a safe local port: Starshine must make the index permutation explicit in its own module representation.

### Existing remap examples

[`src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt) is the closest in-tree model to read before implementing this pass.

Useful existing patterns include:

- `rume_rewrite_func_idx(...)` for numeric function-index remapping,
- instruction rewriting for `call`, `return_call`, and `ref.func`,
- element-kind rewriting for function lists and expression initializers,
- export and start-section rewriting,
- name-section rewriting for function, local, and label names,
- and `rume_rewrite_func_annotation_sec(...)` for annotation remapping.

A future `reorder-functions-by-name` port should probably build a pure permutation/remap table and reuse or factor similar helpers rather than inventing a second ad hoc function-index rewrite surface.

### Encoding and WAT lowering boundaries

[`src/binary/encode.mbt`](../../../../../src/binary/encode.mbt) writes the module sections in the order provided by the `Module` value. It does not perform a last-minute function declaration reorder.

[`src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt) resolves textual function names to numeric `FuncIdx` values for exports, start sections, element segments, calls, and `ref.func`. After lowering, a module-level reorder must update those indices explicitly.

## Minimal faithful implementation plan

A future Starshine port should preserve the small upstream contract and avoid turning this into a count-based layout optimizer.

A clean implementation shape would be:

1. Count imported functions; never sort imports.
2. Collect defined-function names from the name section or the canonical internal-name surface chosen by the implementation.
3. Build a stable old-defined-index to new-defined-index permutation by ascending Binaryen-compatible internal name.
4. Reorder `FuncSec` entries and `CodeSec` bodies together.
5. Build a full absolute `FuncIdx` remap that leaves imported function indices unchanged and remaps defined indices after the import prefix.
6. Rewrite all function-index-bearing bodies and module sections through that remap.
7. Rewrite function names, local names, label names, and function annotations through the same remap.
8. Validate the final module.

## Correctness constraints

A faithful local port must keep these constraints explicit:

- Do not merge this pass with [`../reorder-functions/index.md`](../reorder-functions/index.md). The sibling uses static-reference counts; this pass uses names only.
- Do not inspect call counts, exports, start sections, element segments, `ref.func`, or body complexity to choose the order.
- Do not rewrite function bodies except for numeric index repair caused by the declaration permutation.
- Do not reorder imported functions. The wasm function index space has imports first, followed by defined functions.
- Keep function type entries and function bodies in the same defined-function order.
- Keep name and annotation metadata coherent with the new function indices.

## Validation checklist

When this pass is eventually implemented, validate with at least these families:

- `$c`, `$b`, `$a` defined-function order becomes `$a`, `$b`, `$c`.
- Already sorted `$a`, `$b`, `$c` is a no-op.
- Imported functions remain before defined functions.
- Direct calls still target the same semantic function after reordering.
- `ref.func`, element segments, exports, and `start_sec` still target the same semantic function.
- Function names, local names, label names, and function annotations move with the function they describe.
- The sibling [`../reorder-functions/index.md`](../reorder-functions/index.md) still remains a separate pass with a different ordering policy.

## Current non-goals

This page does not claim Starshine has:

- a module dispatcher case for `reorder-functions-by-name`,
- an owner file for the pass,
- a backlog slice,
- preset scheduling,
- Binaryen parity evidence,
- or a completed function-index permutation API.

Those are future implementation tasks.

## Sources

- [`../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-functions-by-name-primary-sources.md)
- [`../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md`](../../../raw/research/0325-2026-04-24-reorder-functions-by-name-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
