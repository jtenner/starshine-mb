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
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../agent-todo.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./count-surfaces-ordering-and-omissions.md
  - ./module-shapes.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./count-surfaces-ordering-and-omissions.md
  - ./module-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../reorder-functions-by-name/index.md
  - ../reorder-globals/index.md
  - ../reorder-locals/index.md
  - ../reorder-types/index.md
  - ../tracker.md
---

# Starshine `reorder-functions` strategy and current status

## Current status

Starshine does **not** implement `reorder-functions` today.

The exact local status is:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt):137 registers `reorder-functions` as a **boundary-only** pass name.
- The same boundary-only list also registers the sibling `reorder-functions-by-name`.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt):482, 552 rejects boundary-only names in `run_hot_pipeline_expand_passes(...)` instead of running a transformation.
- The active `optimize` and `shrink` preset arrays in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) do not include `reorder-functions`.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt):8912-8940 has no `run_hot_pipeline_apply_module_pass(...)` case for `reorder-functions`.
- [`agent-todo.md`](../../../../../agent-todo.md) has no dedicated active implementation slice for `reorder-functions`.

So the current local strategy is honest non-implementation: keep the name recognizable, reject active requests clearly, and document the future module-pass shape before adding code.

## Why a Starshine port would be a module/boundary pass, not a hot pass

Binaryen teaches this pass as a declaration-order pass: it sorts the function list by a small static-use count and does not optimize function bodies.

In Starshine, that still belongs outside HOT IR because the mutation is module-global:

- function indices are part of module-level section layout,
- imports and defined functions share the function-index namespace,
- `func_sec` and `code_sec` have paired defined-function ordering,
- exports, start, element expressions, table/global initializers, and body instructions can all mention `FuncIdx`,
- name and annotation metadata can also be tied to function indices.

The current module shape in [`src/lib/types.mbt`](../../../../../src/lib/types.mbt) makes that visible: `Module` owns `import_sec`, `func_sec`, `export_sec`, `start_sec`, `elem_sec`, `code_sec`, `name_sec`, and `func_annotation_sec`, while instructions such as `Call`, `ReturnCall`, and `RefFunc` carry numeric `FuncIdx` operands. The shared imported-prefix function-index contract is now summarized in [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md).

That is different from Binaryen's source-level teaching point. Binaryen can reorder its function list while expressions still name the same logical functions. Starshine's lowered representation would need an explicit permutation and reference-remap step so the same logical targets survive changed numeric indices.

## Starshine-specific porting shape

A faithful future port should be small, but it is not just `sort(func_sec)`.

### 1. Build the function-index domain

The port must model the current function-index namespace:

- imported functions from `import_sec`, in their current import order,
- defined functions from paired `func_sec` / `code_sec`, after the imported-function prefix.

This is where Starshine differs from Binaryen's `module->functions` abstraction. The local pass must preserve wasm's import-before-defined indexing rule while still deciding whether the local behavior can and should reorder imported functions inside `import_sec` or only reorder defined functions. That policy decision is still open and should be source-compared before implementation.

### 2. Count exactly Binaryen's reviewed surfaces

For `version_129` parity, the count model should match [`./count-surfaces-ordering-and-omissions.md`](./count-surfaces-ordering-and-omissions.md):

- count direct `Call` targets,
- add one bump for `start_sec`,
- add one bump for each function export,
- add one bump for each function name/index in element segments,
- do **not** add `ref.func` or declaration-section counts unless the port intentionally targets newer or deliberately different behavior.

Because Starshine's IR is index-based, the direct-call scan would inspect `@lib.Call(func_idx)` in function bodies. The upstream TODO boundary around `ref.func` means a parity-oriented port should count `Call` but not `RefFunc`, even though `RefFunc` still must be remapped later if function indices change.

### 3. Sort by Binaryen's comparator

The Binaryen comparator is:

1. descending count,
2. descending function name on ties.

The name tie-breaker is easy to miss and must be specified before coding. A Starshine port must decide which local name source is authoritative for the tie break:

- the symbolic function names available before lowering from WAT,
- the function name subsection in `name_sec`,
- generated/internal fallback names for unnamed functions,
- or another canonical name source.

That is a real open porting question because the current lowered module model can contain numeric functions without stable source names.

### 4. Apply a permutation and remap all function references

If any function index changes, Starshine must rewrite all surfaces that store `FuncIdx`.

The closest existing helper cluster is in [`src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt). In particular, the DFE code already has reusable patterns for:

- rewriting `Call`, `ReturnCall`, and `RefFunc` instructions,
- rewriting function exports,
- rewriting start-section function indices,
- rewriting element segment function lists and element expressions,
- rewriting function indices inside table/global/data initializer expressions,
- rewriting function annotation metadata.

A future `reorder-functions` owner should not copy DFE blindly. DFE maps duplicate functions to canonical survivors and may drop or compact entries. `reorder-functions` needs a total permutation that preserves every function but changes order. Still, DFE is the current best in-tree code map for the reference-rewrite surface a port must audit.

### 5. Preserve declaration-only semantics

Even though Starshine must rewrite numeric operands as a representation repair, the semantic pass should remain declaration-order-only:

- do not fold expressions,
- do not drop functions,
- do not change function bodies except for required `FuncIdx` remapping,
- do not change types except as necessary to keep `func_sec` paired with reordered defined bodies,
- validate after the module pass using the existing module-pass verification path in `pass_manager.mbt`.

## What not to borrow from neighboring passes

- From [`../reorder-locals/index.md`](../reorder-locals/index.md): the access-count idea is related, but locals are per-function and require local-index rewriting. `reorder-functions` is whole-module and must reason about imports, exports, start, elements, names, and code-section pairing.
- From [`../reorder-globals/index.md`](../reorder-globals/index.md): the declaration-layout idea is related, but globals have dependency and initializer-order constraints that `reorder-functions` does not have in the reviewed Binaryen source.
- From [`../reorder-types/index.md`](../reorder-types/index.md): the index-size motivation is related, but types require graph legality and rec-group ordering. `reorder-functions` has no equivalent type-graph legality phase.
- From DFE: function-index remapping helpers are relevant, but duplicate removal and canonical survivor selection are not.

## Current validation story

Because the pass is not implemented, there are no pass-local Starshine behavior tests yet.

The current validation surfaces are indirect:

- registry presence in `src/passes/optimize.mbt`,
- boundary-only request rejection through the shared `run_hot_pipeline_expand_passes(...)` path,
- absence from active presets,
- absence from module-pass dispatch in `src/passes/pass_manager.mbt`,
- this wiki page and the raw primary-source manifest documenting the intended future shape.

For the porting ladder, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

When implemented, the minimum local tests should cover:

1. direct-call count ordering,
2. start/export/element count bumps,
3. descending-name tie breaks,
4. `ref.func` non-counting paired with required remapping if indices change,
5. imports plus defined functions in the same module,
6. `func_sec` / `code_sec` pairing after reorder,
7. export/start/element/body/name/annotation remapping,
8. active request acceptance only after a real module-pass owner and dispatcher case exist.

## Current conclusion

The correct Starshine status is **boundary-only with a clear future module-pass map**.

Do not describe this as implemented, removed, or merely unknown. The repository knows the pass name, rejects it honestly, and now has a complete source-backed plan for what a faithful future implementation must preserve.
