---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md
  - ../../../raw/research/0427-2026-04-27-type-un-finalizing-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md
  - ../../../raw/research/0314-2026-04-24-type-un-finalizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
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
  - ./private-boundaries-sibling-split-and-no-leaf-rule.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../type-finalizing/index.md
  - ../remove-unused-types/index.md
  - ../type-merging/index.md
  - ../unsubtyping/index.md
---

# Starshine `type-un-finalizing` strategy

## Current status

Starshine does **not** implement `type-un-finalizing` today.

The current local truth is:

- `src/passes/optimize.mbt` lists `type-un-finalizing` in `pass_registry_boundary_only_names()`.
- The registry category is therefore `BoundaryOnly`, not `HotPass` and not `ModulePass`.
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only requests with the standard “boundary-only and is not implemented in the hot pipeline” error.
- `optimize_preset_passes(...)` and `shrink_preset_passes(...)` do not include `type-un-finalizing`.
- There is no `src/passes/type_un_finalizing.mbt`, `src/passes/type_unfinalizing.mbt`, or shared `src/passes/type_finality.mbt` owner file.
- `agent-todo.md` has no dedicated `type-un-finalizing` backlog slice.

So this page is a **status and future-port map**, not an implementation guide for code that already exists.

## Exact local code locations

| Local surface | Code location | Why it matters |
| --- | --- | --- |
| Boundary-only registry name | `src/passes/optimize.mbt`, `pass_registry_boundary_only_names()` around lines 127-139 | Preserves the local extra-hyphen spelling `type-un-finalizing` while preventing accidental execution |
| Boundary-only entry construction | `src/passes/optimize.mbt`, `pass_registry_entries()` around lines 156-270 | Converts every boundary-only name into a registry entry with `BoundaryOnly` category and no descriptor |
| Boundary-only request rejection | `src/passes/optimize.mbt`, `run_hot_pipeline_expand_passes(...)` around lines 456-462 | Stops direct `--pass type-un-finalizing` requests before hot/module dispatch |
| Active preset omission | `src/passes/optimize.mbt`, `optimize_preset_passes(...)` around lines 379-391 and `shrink_preset_passes(...)` around lines 394-405 | Confirms no hidden default-pipeline role |
| Local type model | `src/lib/types.mbt` | Defines the type-section, recursive type, reference type, function type, global, local, and instruction structures a future module pass would rewrite |
| WAT parser/lowering | `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/module_wast_tests.mbt` | Existing surfaces for `sub`, `final`, recursive types, globals, locals, function heap types, and text-fixture coverage |
| Validator | `src/validate/env.mbt`, `src/validate/typecheck.mbt` | Owns heap-type environments and post-rewrite type checking |
| Binary roundtrip | `src/binary/encode.mbt`, `src/binary/decode.mbt` | Any future open/final bit rewrite must remain encodable and decodable |
| Port-batch classification | `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md` | Records `type-un-finalizing` among boundary-only type/global/signature shaping names |
| Backlog status | `agent-todo.md` | No active dedicated slice currently exists |

## Mapping Binaryen strategy to a future Starshine port

Binaryen's `type-unfinalizing` strategy is module/type-section work:

- check that GC is enabled,
- collect private heap types,
- skip the finalizing sibling's immediate-subtype / leaf-only proof,
- reopen every private candidate with `setOpen(true)`,
- and rely on a coherent global type rewrite so all uses still point at valid heap types.

A faithful Starshine port should therefore be a module pass that rewrites type declarations and dependent references coherently. It should **not** be planned as a local HOT peephole.

## Required future implementation shape

A future implementation needs at least these pieces:

1. an owner file such as `src/passes/type_finality.mbt`, shared with `type-finalizing`, or a dedicated sibling file if the pass runner keeps them separate;
2. a module-pass registry entry in `src/passes/optimize.mbt` instead of a boundary-only entry;
3. a module dispatcher hook if the current pass runner still separates module and hot passes;
4. a GC-feature gate matching the upstream no-GC no-op rule;
5. private-heap-type discovery that matches Binaryen's observability boundary;
6. no leaf-only proof in the unfinalizing mode;
7. a coherent type remapper that updates globals, locals, function signatures, type references, exports, and any binary/text metadata that names heap types;
8. tests for public type preservation, private leaf reopening, private non-leaf reopening, function heap-type participation, and local/global use repair;
9. validation after rewriting;
10. a sibling policy for `type-finalizing`, because upstream implements both pass names with one shared engine.

## What not to build for this pass

Do **not** implement `type-un-finalizing` as any of these:

- type deletion,
- type merging,
- subtype-edge pruning,
- field-type inference,
- local expression retagging,
- a HOT-only expression visitor,
- a broad “open every type” rewrite that changes public heap types,
- or a finalizing mirror that still requires the leaf-only proof.

Those are neighboring pass families such as `remove-unused-types`, `type-merging`, `unsubtyping`, `type-refining`, or `type-generalizing`, not this pass.

## Current validation guidance

Because Starshine has no implementation, current validation is status validation:

- `type-un-finalizing` must remain rejected as boundary-only when requested directly.
- It must not appear in the `optimize` or `shrink` preset expansion.
- Wiki pages should cite the 2026-04-24 raw manifest, the 2026-04-27 port-readiness manifest, this status page, and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) instead of only the older 0193 research note.

For a future implementation's first-slice ordering, shape-to-validation checklist, and Binaryen oracle lanes, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

If a future port lands, use the repo's standard signoff:

- quick: `moon info`, `moon fmt`, `moon test`
- pass parity: `moon build --target native --release src/cmd` followed by `bun fuzz compare-pass --pass type-unfinalizing ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` or `--pass type-un-finalizing ...`, depending on which spelling the local harness accepts and how it maps to upstream Binaryen

## Relationship to neighboring Starshine code

- `../type-finalizing/index.md` is the closest sibling and should stay in sync with this page.
- `src/passes/remove_unused_module_elements.mbt` and `src/passes/duplicate_function_elimination.mbt` are useful examples of whole-module pass organization, but they do not implement type finality semantics.
- `src/lib/types.mbt` plus the WAT/binary/validator surfaces are the real future dependency cluster because this pass needs a correct type-graph rewrite.
- `../remove-unused-types/index.md`, `../type-merging/index.md`, and `../unsubtyping/index.md` are neighboring type-graph transforms that future docs should contrast instead of conflating.

## Uncertainties and caveats

- The local representation of private/public heap-type visibility may not exactly mirror Binaryen's `ModuleUtils::getPrivateHeapTypes(...)`; a future port must define and test the Starshine equivalent before flipping the registry category.
- The best local type-remap helper does not exist yet as a named `GlobalTypeRewriter` equivalent. A faithful port may first need shared type-section rewrite infrastructure used by other boundary-only GC/type passes.
- The current-main source check was narrow: it compared the owner file and dedicated lit file for teaching-relevant drift, not every helper transitively used by Binaryen's type updater.

## Source chain

For the full source-backed chain, read in this order:

1. [`../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md)
2. [`../../../raw/research/0427-2026-04-27-type-un-finalizing-port-readiness.md`](../../../raw/research/0427-2026-04-27-type-un-finalizing-port-readiness.md)
3. [`../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md)
4. [`../../../raw/research/0314-2026-04-24-type-un-finalizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0314-2026-04-24-type-un-finalizing-primary-sources-and-starshine-followup.md)
5. [`./binaryen-strategy.md`](./binaryen-strategy.md)
6. [`./private-boundaries-sibling-split-and-no-leaf-rule.md`](./private-boundaries-sibling-split-and-no-leaf-rule.md)
7. [`./wat-shapes.md`](./wat-shapes.md)
8. [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
