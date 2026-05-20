---
kind: entity
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0409-2026-04-26-type-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-05-06-type-ssa-current-main-recheck.md
  - ../../../raw/research/0503-2026-05-06-type-ssa-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md
  - ../../../raw/research/0386-2026-04-26-type-ssa-source-correction.md
  - ../../../raw/binaryen/2026-04-23-type-ssa-primary-sources.md
  - ../../../raw/research/0277-2026-04-23-type-ssa-primary-sources-and-starshine-followup.md
  - ../tracker.md
  - ../index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../type-merging/index.md
  - ../type-refining/index.md
  - ../ssa/index.md
---

# `type-ssa`

## Role

`type-ssa` is a real public upstream Binaryen pass, but it is currently **upstream-only** for Starshine:

- no `src/passes/type_ssa.mbt` owner file exists,
- the local registry does not list `type-ssa` as active, boundary-only, or removed,
- it is not in the current no-DWARF `-O` / `-Os` parity path,
- it is not in the saved generated-artifact `-O4z` skipped-slot queue,
- `agent-todo.md` has no dedicated `type-ssa` slice.

This folder is therefore a source-backed dossier and port-planning note, not a hidden local implementation.

## Important 2026-04-26 correction and 2026-05-06 freshness refresh

The older 2026-04-23 dossier misdescribed `type-ssa` as a local/global/control-flow created-type propagation pass that retagged later gets, call operands, and returns. A fresh official-source read corrected that.

The real Binaryen `version_129` and current-main contract is:

- scan selected allocation instructions,
- decide which allocations are worth splitting into their own type,
- create fresh private subtypes of the allocated struct/array heap types,
- rewrite those allocation result types to exact non-null fresh types,
- then refinalize ordinary functions and module code.

Treat the older `createdTypes` / call-operand / return-retagging story as **superseded** by [`../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md`](../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md).

## Beginner summary

A good mental model is:

> Binaryen `type-ssa` gives some allocation sites their own fresh heap type, like SSA gives some values their own register.

For example, if two `struct.new $A` instructions allocate values that later optimizations could distinguish, Binaryen may create `$A.0` and `$A.1` as private subtypes of `$A`, retag each allocation to its fresh exact type, and let later type-aware passes see those allocations as separate.

It is **not** ordinary SSA construction, and it is **not** a local-flow pass over every `local.get` / `global.get`.

## Main durable takeaways

- `type-ssa` is implemented in upstream `src/passes/TypeSSA.cpp` and registered by `pass.cpp`.
- It is GC-gated.
- The 2026-05-06 current-main recheck found no teaching-relevant drift on the reviewed surfaces.
- It analyzes module-visible exact-observation surfaces before rewriting allocation types.
- The reviewed source also scans module code, globals, and element segments; table initializers remain an open TODO surface rather than a confirmed positive scan path.
- Candidate allocation sites include:
  - `struct.new`,
  - `array.new`,
  - `array.new_data`,
  - `array.new_elem`,
  - `array.new_fixed`.
- Candidate rejection includes:
  - unreachable allocations,
  - final types,
  - open-disabled types,
  - descriptor/describee heap-type families,
  - types that were observed in exact-sensitive places.
- Positive interestingness includes:
  - default `struct.new`,
  - constants/globals feeding fields or elements,
  - operands whose type is more refined than the declared field/element type,
  - data/element-backed arrays,
  - fixed arrays when all elements are interesting.
- The rewrite creates fresh private subtypes in one rec group, preserves sharing, copies friendly names when possible, retags the selected allocation nodes, and refinalizes.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md) explains Binaryen's corrected source-backed algorithm and caveats.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) maps the owner files, registration surface, test file, helper dependencies, and superseded older interpretation.
- [`./created-exact-types-control-values-and-signature-rewrites.md`](./created-exact-types-control-values-and-signature-rewrites.md) is now the focused correction page for allocation-type splitting, exact-observation blockers, and why the old local-flow model is stale.
- [`./wat-shapes.md`](./wat-shapes.md) gives before/after module and instruction shapes for the allocation-subtype rewrite and bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md) records Starshine's current non-adoption and the real future local prerequisites.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) turns the corrected strategy into an implementation sequence: registry honesty, analyzer-only candidate/blocker discovery, fresh-subtype mutation, allocation retagging, and Binaryen-oracle validation.

## Validation guidance

For a future Starshine port, validation must compare against Binaryen's allocation-type-splitting behavior, not the older stale local-flow story. Use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) as the detailed ladder:

1. decide registry honesty first;
2. add analyzer-only tests for positive `struct.new`, `array.new`, `array.new_data`, `array.new_elem`, and all-interesting `array.new_fixed` cases;
3. add bailouts for final types, exact-observed types, descriptor/describee types, unreachable code, and uninteresting operands;
4. validate type sections, allocation result types, and refinalized parent types;
5. compare against `wasm-opt --type-ssa` on official reduced cases before fuzzing;
6. run pass-targeted parity through the local Binaryen comparison harness only after Starshine has honest registry support.

## Sources

- [`../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md)
- [`../../../raw/research/0409-2026-04-26-type-ssa-port-readiness.md`](../../../raw/research/0409-2026-04-26-type-ssa-port-readiness.md)
- [`../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md`](../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md)
- [`../../../raw/research/0386-2026-04-26-type-ssa-source-correction.md`](../../../raw/research/0386-2026-04-26-type-ssa-source-correction.md)
- Older, superseded capture kept for audit trail: [`../../../raw/binaryen/2026-04-23-type-ssa-primary-sources.md`](../../../raw/binaryen/2026-04-23-type-ssa-primary-sources.md)
- Official Binaryen sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeSSA.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-ssa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeSSA.cpp>
