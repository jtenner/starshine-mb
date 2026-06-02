---
kind: concept
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0409-2026-04-26-type-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-05-06-type-ssa-current-main-recheck.md
  - ../../../raw/research/0503-2026-05-06-type-ssa-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-01-type-ssa-current-main-recheck.md
  - ../../../raw/research/0688-2026-06-01-type-ssa-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md
  - ../../../raw/research/0386-2026-04-26-type-ssa-source-correction.md
  - ../../../raw/binaryen/2026-04-23-type-ssa-primary-sources.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../type-merging/index.md
  - ../ssa/index.md
---

# Binaryen `type-ssa` strategy

## Upstream source rule

Use the 2026-06-01 freshness capture as the current source oracle: [`../../../raw/binaryen/2026-06-01-type-ssa-current-main-recheck.md`](../../../raw/binaryen/2026-06-01-type-ssa-current-main-recheck.md).

The key official sources are:

- `src/passes/TypeSSA.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `test/lit/passes/type-ssa.wast`
- `src/ir/ReFinalize.cpp`
- `src/wasm-type-shape.*`

Primary URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeSSA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-ssa.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeSSA.cpp>

## The pass in one sentence

Binaryen `type-ssa` is a GC pass that creates fresh private heap subtypes for selected allocation instructions and rewrites those allocations to exact non-null fresh types so later type-aware optimizations can distinguish allocation sites.

## The corrected naming fact

The name is still intentionally SSA-flavored, but the analogy is narrower than the old dossier claimed.

- Ordinary SSA: each value can get a distinct register.
- `type-ssa`: selected allocation values can get distinct fresh heap types.

So `type-ssa` is not general [`../ssa/index.md`](../ssa/index.md), not local-flow retagging, and not whole-program type inference.

## Public-pass fact

`pass.cpp` registers `type-ssa` as a public pass name. That makes it worth tracking as its own upstream dossier even though Starshine does not currently name the pass in the local registry.

## High-level algorithm

### 1. Gate on GC

The pass requires GC support. Without GC heap types, fresh allocation subtypes have no useful target representation.

### 2. Scan allocation candidates

The analyzer records allocation sites in a `news` list. The important candidate families are:

- `struct.new`,
- `array.new`,
- `array.new_data`,
- `array.new_elem`,
- `array.new_fixed`.

It skips imported functions for function-body analysis but also scans module code, globals, and element segments so allocation sites outside ordinary defined function bodies are not missed; table initializers remain a documented TODO surface in the reviewed source, so they are not part of the currently source-backed positive scan surface.

### 3. Record exact-observation blockers

The pass also records `disallowedTypes`: types that cannot safely be split because exact type identity might already be observable or constrained.

Important blocker families include:

- exact `ref.cast` / `ref.test` targets,
- exact function results,
- exact global types,
- exact element-segment types,
- exact child constraints found through the `ChildTyper` helper.

This is the core correctness guard. A fresh subtype is only safe when later code cannot observe that the allocation no longer has exactly the original heap type.

### 4. Filter for interesting allocations

Not every safe allocation is worth splitting. `isInteresting(...)` rejects allocations that do not expose useful type distinctions.

Important positive families include:

- default `struct.new`,
- fields or elements initialized from constants,
- fields or elements initialized from globals,
- operands whose types are more refined than the declared field or element type,
- data/element-backed arrays,
- `array.new_fixed` when every element is interesting.

Important negative families include:

- unreachable allocations,
- final types,
- types whose `open` bit is disabled,
- descriptor/describee types,
- boring operands that do not carry useful refinement.

### 5. Create a fresh rec group

For selected candidates, Binaryen constructs one new rec group containing fresh private subtypes of the original allocated heap types.

The rewrite preserves sharing through an old-to-new type map and calls the type-shape machinery so the new group is unique rather than colliding with existing shapes.

### 6. Rewrite allocation result types

Each selected allocation is retagged from the old allocation type to an exact non-null reference to its fresh subtype.

This is the visible transformation: the allocation node, not a later `local.get` or call operand, gets the fresh type.

### 7. Preserve useful names

When the old type has a name, Binaryen copies a friendly derived name to the new fresh subtype with a numeric suffix. This is a readability/debugging detail, not the semantic core.

### 8. Refinalize

After rewriting, Binaryen runs `ReFinalize` over ordinary functions and module code so parent expression types agree with the new child allocation types.

## Closed-world caveat

The pass comments describe the optimization as likely most useful in closed-world scenarios because fresh rec-group collisions outside the module can make some distinctions less profitable or harder to preserve. The source-backed gate, however, is GC support plus the pass's own exact-observation/disallowed-type analysis, not a simple hard `--closed-world` option check like some neighboring GC/type passes.

## Current-main drift check

The 2026-04-26 source correction and the 2026-06-01 freshness recheck both rechecked current `main`. No teaching-relevant drift was found from the corrected `version_129` allocation-subtype contract, including the still-open table-initializer TODO boundary. The latest bridge keeps the same port-facing reading: candidate discovery is still allocation-site based, exact-observation blockers still gate fresh subtype creation, and refinalization remains part of the post-rewrite contract.

## What the older dossier got wrong

The older 2026-04-23 pages should not be used for the algorithm. They claimed the pass had:

- a `createdTypes` expression map,
- a `getTargetType(...)` helper that filtered abstract refs,
- control-value forwarding through `block` / `if` / `try`,
- local/global get retagging,
- direct-call operand and return retagging.

Those claims are superseded by the owner file's allocation-subtype implementation.

## Important pass interactions

- Compared with [`../ssa/index.md`](../ssa/index.md), this pass creates fresh **types**, not general SSA locals.
- Compared with [`../type-refining/index.md`](../type-refining/index.md), this pass does not aggregate field writes; it specializes allocation result types.
- Compared with [`../type-merging/index.md`](../type-merging/index.md), this pass may create more type distinctions, while type merging later removes indistinguishable private declarations.
- Compared with [`../abstract-type-refining/index.md`](../abstract-type-refining/index.md), this pass creates new private subtypes rather than only refining uses of existing abstract types.

## Validation expectations

A faithful implementation must prove:

- allocation candidate discovery across functions and module code,
- exact-observation blockers,
- interestingness filtering,
- correct subtype/rec-group creation,
- exact non-null allocation retagging,
- name copying only as a non-semantic detail,
- refinalization after rewrites,
- no accidental local-flow retagging model imported from the superseded dossier.

For Starshine-specific sequencing, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
