---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md
  - ../../../raw/research/0492-2026-05-05-reorder-types-port-readiness-and-validation.md
  - ../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md
  - ../../../raw/research/0438-2026-05-04-reorder-types-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md
  - ../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
  - ./ordering-cost-model-and-boundaries.md
  - ./wat-shapes.md
  - ../remove-unused-types/index.md
  - ../minimize-rec-groups/index.md
  - ../reorder-globals/index.md
---

# `reorder-types`: Starshine strategy and status

## Current Starshine status

Starshine does **not** implement `reorder-types` today.
The 2026-05-04 current-main recheck did not change that local status, and the 2026-05-05 freshness refresh only added a port-readiness bridge.

The exact local status is:

- `src/passes/optimize.mbt:127-139` includes `reorder-types` in `pass_registry_boundary_only_names()`.
- `src/passes/optimize.mbt:448-466` rejects boundary-only names before execution with the standard message that the pass is not implemented in the hot pipeline.
- `src/passes/pass_manager.mbt:8641-8647` dispatches the currently implemented module passes and has no `reorder-types` case.
- `src/passes/registry_test.mbt:1-90` covers category/preset expectations for the active registry, but does not hide a partial `reorder-types` transform.
- `src/passes/` currently contains `reorder_locals.mbt` and `reorder_locals_test.mbt`, but no `reorder_types.mbt` owner file.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:58-61` lists `reorder-types` in the older boundary cleanup / ordering bucket.
- `agent-todo.md` has no dedicated active `reorder-types` implementation slice.

So the current strategy is honest non-implementation:

1. preserve the public pass spelling,
2. reject explicit requests instead of silently no-oping,
3. keep the Binaryen contract documented for a future module pass,
4. do not include the pass in active `optimize` / `shrink` presets.

## Why a HOT pass would be wrong

Binaryen `reorder-types` is a whole-module type-layout pass, not an expression-local peephole.
A faithful Starshine port must be module-scoped because it must update all type-index-bearing surfaces together:

- type-section order and rec-group structure,
- function signatures,
- locals and expression result types,
- struct / descriptor instruction immediates,
- tables, elements, globals, tags, imports, and exports,
- binary type-index encodings and any preserved type-name / index metadata.

That makes it closer to the future local infrastructure needed for [`remove-unused-types`](../remove-unused-types/index.md), [`minimize-rec-groups`](../minimize-rec-groups/index.md), and [`type-merging`](../type-merging/index.md) than to implemented HOT cleanup passes.

## Local surfaces a future port would reuse

### Registry and request plumbing

- `src/passes/optimize.mbt:127-139` is the current boundary-only registry entry.
- `src/passes/optimize.mbt:448-466` is the request-rejection path that should be replaced only after a real module dispatcher case exists.
- `src/passes/pass_manager.mbt:8641-8647` is the module-pass dispatcher location where a future `reorder-types` case would land.
- `src/cli/cli.mbt:1072-1077` parses `--closed-world`.
- `src/cmd/cmd.mbt:1667-1705` carries `closed_world` into `HotPipelineOptions`.

### Type-section model

- `src/lib/types.mbt:98-155` defines `TypeIdx`, `RecType`, `SubType`, and `TypeMetadata`.
- `TypeMetadata` already has `describes` and `descriptor` fields, which are the local analogs of Binaryen's described-type / descriptor dependency edge surface.
- `SubType` already stores the declared supertype list used by Binaryen's predecessor-edge rule.

### Text-format and fixture lowering

- `src/wast/lower_to_lib.mbt:385-428` lowers WAT subtypes and rec groups into library `SubType` / `RecType` values.
- `src/wast/lower_to_lib.mbt:2413-2478` lowers type-indexed struct allocation, struct field, descriptor, and cast/test descriptor instructions.

Those are the main beginner-friendly fixture surfaces for proving a future type-remap pass.

### Validation and roundtrip support

- `src/validate/env.mbt:129-285` resolves global and recursive type indices, function types, tag types, local/global/table types, and rec-stack entries.
- `src/validate/typecheck.mbt` is the broader instruction/module typechecking surface that would catch incomplete remaps.
- `src/binary/encode.mbt:607-610` encodes concrete `TypeIdx` values.
- `src/binary/decode.mbt:186-191` decodes concrete heap-type indices.

A future implementation should add tests that fail when any of those surfaces are left stale after a reorder.

## Required future algorithm shape

A faithful port should preserve the Binaryen strategy documented in [`./binaryen-strategy.md`](./binaryen-strategy.md):

1. require GC support,
2. require closed-world mode,
3. collect used IR heap-type traffic and visibility,
4. freeze public heap types,
5. build predecessor edges from private supertypes and private described types,
6. sample the same 21 successor-weight factors,
7. score by encoded type-index byte cost,
8. rebuild reordered private types into one fresh private rec group,
9. remap every type-bearing module surface in one atomic rewrite,
10. validate and binary-roundtrip the result.

## Local caveats and uncertainties

- Starshine has pieces of the type-section model, but no shared `GlobalTypeRewriter`-equivalent helper today.
- The current docs do not identify a local public/private heap-type visibility oracle equivalent to Binaryen's `collectHeapTypeInfo(..., FindVisibility)`.
- `--closed-world` option plumbing exists locally, but only implemented passes such as `global-struct-inference` currently consume it in the module-pass path.
- There is no active backlog slice, so the exact local landing plan is still open.

## Cross-links for readers

- Start with [`./index.md`](./index.md) for the pass overview.
- Use [`./wat-shapes.md`](./wat-shapes.md) for concrete before/after module shapes.
- Use [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream algorithm.
- Use [`./ordering-cost-model-and-boundaries.md`](./ordering-cost-model-and-boundaries.md) for the hard public/private, predecessor-edge, and cost-model rules.
- Use [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the upstream file/test map.
- Use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the first-slice order and validation ladder.

## Sources

- [`../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md)
- [`../../../raw/research/0492-2026-05-05-reorder-types-port-readiness-and-validation.md`](../../../raw/research/0492-2026-05-05-reorder-types-port-readiness-and-validation.md)
- [`../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md)
- [`../../../raw/research/0438-2026-05-04-reorder-types-current-main-recheck.md`](../../../raw/research/0438-2026-05-04-reorder-types-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md)
- [`../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md`](../../../raw/research/0309-2026-04-24-reorder-types-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- [`../../../../../src/validate/env.mbt`](../../../../../src/validate/env.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
- [`../../../../../src/cli/cli.mbt`](../../../../../src/cli/cli.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
