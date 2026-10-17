---
kind: concept
status: supported
last_reviewed: 2026-10-16
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp
  - https://webassembly.github.io/spec/js-api/#exported-functions
  - ./index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../agent-todo.md
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

## October 16 bounded packing experiment

[The fixed-fixture experiment](../../../../../src/passes/index_packing_experiments_wbtest.mbt)
swaps defined functions 1 and 128 behind a fixed function-import prefix. It
uses the existing DFE reference rewriter and explicitly pairs code with its
signature. Direct checks cover calls, body and initializer `ref.func`, elements,
start, exports, and a decoded function name. Both modules validate; complete
encoding saves eight bytes. The input bytes remain unchanged.

This fixture has no local or label names, annotations, compiler facts, raw name
payload, or offset metadata. It therefore does not prove a general remap or
metadata contract. The public pass remains boundary-only. A production owner
must prove all excluded surfaces, count references across the whole module,
check complete encoded cost, and supply a dedicated generator profile before
the registry can become active. No compile-time, runtime, or memory gain is
established by this experiment.

## Current status

Starshine does **not** implement `reorder-functions` today.

The exact local status is:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt):137 registers `reorder-functions` as a **boundary-only** pass name.
- The same boundary-only list also registers the sibling `reorder-functions-by-name`.
- It does **not** register the separate open Binaryen proposal `reorder-functions-by-similarity`; current upstream does not register that proposal either.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt):482, 552 rejects boundary-only names in `run_hot_pipeline_expand_passes(...)` instead of running a transformation.
- The active `optimize` and `shrink` preset arrays in [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) do not include `reorder-functions`.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt):8912-8940 has no `run_hot_pipeline_apply_module_pass(...)` case for `reorder-functions`.
- [`agent-todo.md`](../../../../../agent-todo.md) has no dedicated active implementation slice for `reorder-functions`.

So the current local strategy is honest non-implementation: keep the name recognizable, reject active requests clearly, and document the future module-pass shape before adding code.

## Measured private-call experiment

A 2026-10-13 prototype against baseline `a61c3e418` was withdrawn. It kept
imports and addressable functions fixed, assigned short private direct-call
indices by frequency, retained original order within each encoded-width group,
and required a strict exact encoded-size decrease. It did not reorder types.

Seven alternating control/candidate samples after one warmup pair measured
the following changes after the existing size preset:

| Module | Raw bytes saved | gzip level 9 bytes saved | Paired median wall increase | Median peak RSS increase |
|---|---:|---:|---:|---:|
| Release WasmGC compiler | 32,345 | 595 | 355 ms | 11,020 KiB |
| Held-out WASI compiler | 28,563 | 1,244 | 342 ms | 31,660 KiB |

Both are compiler artifacts from the same project. Small C workloads had no
index-width opportunity. gzip used explicit level 9 and `mtime=0`. Linux
`wait4` measured native-child peak RSS, not aggregate concurrent memory.
Unrelated Moon tests ran during measurements; exact cost percentages remain
uncertain. A separate trace measured 206 ms in the GC ordering pass. Thus the
results support repeatable byte savings, but do not meet the requirement for
no meaningful compile-time regression. No runtime speed gain was established.

Independent `wasm-tools` validation and Node execution checks passed. A bounded
100-case GenValid probe had no validation or observed runtime failures. Its
output differences were not complete parity signoff; the required 10,000-case
lane was not run because the candidate failed the cost gate. No implementation,
generator profile, pass flag, or preset change was retained. Experimental native
build SHA256: `440bd45a1068cf7e7ebe54b9b28c8541fe1f4de5b0c40e9cfc6ddad3e4e83c83`.

A future port must preserve import lookup order. Binaryen 133
(`version_133-60-g93d6e9de7`) changed import-getter order in a reduced execution
case. It must also preserve exported and addressable function indices: the
[WebAssembly JavaScript API](https://webassembly.github.io/spec/js-api/#exported-functions)
sets an exported function's `name` from its index. Unknown raw name subsections
cannot be discarded, and a bijective metadata remap must preserve annotation
associations and duplicates. Reopen only with cheaper exact-cost and remap work
plus repeated runtime measurements; the older port map below is subject to
these constraints.

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
- this wiki page, retained source research, and direct tagged URLs documenting the intended future shape.

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

Do not describe this as implemented, removed, or merely unknown. The repository knows the two shipped Binaryen pass names, rejects them honestly, and has a complete source-backed plan for what a faithful future implementation must preserve. Keep the open compression-oriented proposal distinct until it lands; see [`compression-oriented-similarity-proposal.md`](compression-oriented-similarity-proposal.md).
