---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md
  - ../../../raw/research/0426-2026-04-27-type-finalizing-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md
  - ../../../raw/research/0310-2026-04-24-type-finalizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./leaf-types-public-boundaries-and-sibling-split.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../type-un-finalizing/index.md
  - ../remove-unused-types/index.md
  - ../type-merging/index.md
  - ../unsubtyping/index.md
---

# Starshine `type-finalizing` strategy

## Current status

Starshine does **not** implement `type-finalizing` today.

The current local truth is:

- `src/passes/optimize.mbt` lists `type-finalizing` in `pass_registry_boundary_only_names()`.
- The registry category is therefore `BoundaryOnly`, not `HotPass` and not `ModulePass`.
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only requests with the standard “boundary-only and is not implemented in the hot pipeline” error.
- `optimize_preset_passes(...)` and `shrink_preset_passes(...)` do not include `type-finalizing`.
- `src/passes/registry_test.mbt` locks the active preset list to implemented pass names, but it does not prove a hidden implementation of this pass.
- There is no `src/passes/type_finalizing.mbt` owner file.
- `agent-todo.md` has no dedicated `type-finalizing` backlog slice.

So the correct Starshine strategy page is a **status and future-port map**, not an implementation guide for code that already exists.

## Exact local code locations

| Local surface | Code location | Why it matters |
| --- | --- | --- |
| Boundary-only registry name | `src/passes/optimize.mbt`, `pass_registry_boundary_only_names()` | Preserves the local `type-finalizing` spelling while preventing accidental execution |
| Boundary-only request rejection | `src/passes/optimize.mbt`, `run_hot_pipeline_expand_passes(...)` | Stops direct `--pass type-finalizing` requests before hot/module dispatch |
| Active preset omission | `src/passes/optimize.mbt`, `optimize_preset_passes(...)` and `shrink_preset_passes(...)` | Confirms no hidden default-pipeline role |
| Registry/preset tests | `src/passes/registry_test.mbt` | Tests active category and preset honesty, but does not implement this pass |
| Local type model | `src/lib/types.mbt` | Defines the type-section, recursive type, reference type, and instruction structures a future module pass would rewrite |
| WAT parser/lowering | `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/module_wast_tests.mbt` | Existing surfaces for `sub`, `final`, recursive types, globals, locals, and function heap-type fixtures |
| Validator | `src/validate/env.mbt`, `src/validate/typecheck.mbt` | Owns heap-type environments and post-rewrite type checking |
| Binary roundtrip | `src/binary/encode.mbt`, `src/binary/decode.mbt` | Any future final/open bit rewrite must remain encodable and decodable |
| Port-batch classification | `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md` | Records `type-finalizing` among boundary-only type/global/signature shaping names |
| Backlog status | `agent-todo.md` | No active dedicated slice currently exists |

## Mapping Binaryen strategy to a future Starshine port

Binaryen's pass is module/type-section work:

- it checks for GC,
- collects private heap types,
- filters to private leaves only in finalizing mode,
- and toggles `open` to `false` through a coherent global type rewrite.

A faithful Starshine port should therefore be a module pass that rewrites type declarations and all dependent references coherently. It should **not** be planned as a local HOT peephole.

## Required future implementation shape

For a step-by-step validation ladder, read [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). A future implementation needs at least these pieces:

1. an owner file such as `src/passes/type_finalizing.mbt` or a shared `type_finality.mbt` sibling engine;
2. a module-pass registry entry in `src/passes/optimize.mbt` instead of a boundary-only entry;
3. a module dispatcher hook if the current pass runner still separates module and hot passes;
4. private-heap-type discovery that matches Binaryen's observability boundary;
5. an immediate-subtype index for the finalizing-only leaf proof;
6. a coherent type remapper that updates globals, locals, function signatures, type references, exports, and any binary/text metadata that names heap types;
7. tests for public type preservation, private leaf finalization, private non-leaf preservation, function heap-type participation, and local/global use repair;
8. validation after rewriting;
9. a sibling policy for local `type-un-finalizing`, because upstream implements both names with one shared engine.

## What not to build for this pass

Do **not** implement `type-finalizing` as any of these:

- dead-type removal,
- type merging,
- subtype-edge pruning,
- field-type inference,
- local expression retagging,
- a HOT-only expression visitor,
- a closed-world-only whole-program analysis.

Those are neighboring pass families such as `remove-unused-types`, `type-merging`, `unsubtyping`, `type-refining`, or `type-generalizing`, not this pass.

## Current validation guidance

Because Starshine has no implementation, the current validation is status validation:

- `type-finalizing` must remain rejected as boundary-only when requested directly.
- It must not appear in the `optimize` or `shrink` preset expansion.
- Wiki pages must cite the 2026-04-24 raw manifest and this status page instead of only the older 0192 research note.

If a future port lands, use the repo's standard signoff:

- quick: `moon info`, `moon fmt`, `moon test`
- pass parity: `moon build --target native --release src/cmd` followed by `bun fuzz compare-pass --pass type-finalizing ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` or the nearest harness spelling accepted by the local Binaryen toolchain

## Relationship to neighboring Starshine code

- `src/passes/remove_unused_module_elements.mbt` and `src/passes/duplicate_function_elimination.mbt` are useful examples of whole-module pass organization, but they do not implement type finality semantics.
- `src/passes/reorder_locals.mbt` is useful as a module-pass testing/dispatch neighbor, but it rewrites locals, not heap-type finality.
- `src/lib/types.mbt` and the WAT/binary/validator surfaces are the real future dependency cluster because this pass needs a correct type-graph rewrite.
- `../type-un-finalizing/index.md` should be kept in sync on naming and shared-engine claims, because Binaryen implements both pass names in `TypeFinalizing.cpp`.

## Uncertainties and caveats

- The local representation of private/public heap-type visibility may not exactly mirror Binaryen's `ModuleUtils::getPrivateHeapTypes(...)`; a future port must define and test the Starshine equivalent before flipping the registry category.
- The best local type-remap helper does not exist yet as a named `GlobalTypeRewriter` equivalent. A faithful port may first need shared type-section rewrite infrastructure used by other boundary-only GC/type passes.
- The sibling `type-un-finalizing` now has its own 2026-04-24 raw-manifest refresh and Starshine status page. It shares the upstream owner file, but this page remains scoped to the finalizing direction.

## Source chain

For the full source-backed chain, read in this order:

1. [`../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-finalizing-primary-sources.md)
2. [`../../../raw/research/0310-2026-04-24-type-finalizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0310-2026-04-24-type-finalizing-primary-sources-and-starshine-followup.md)
3. [`../../../raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-type-finalizing-port-readiness-primary-sources.md)
4. [`./binaryen-strategy.md`](./binaryen-strategy.md)
5. [`./leaf-types-public-boundaries-and-sibling-split.md`](./leaf-types-public-boundaries-and-sibling-split.md)
6. [`./wat-shapes.md`](./wat-shapes.md)
7. [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
