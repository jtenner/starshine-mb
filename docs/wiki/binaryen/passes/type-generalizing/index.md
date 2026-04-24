---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md
  - ../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-flow-type-floor-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../type-refining/index.md
  - ../gufa/index.md
  - ../gufa-cast-all/index.md
  - ../type-merging/index.md
supersedes:
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
---

# `type-generalizing`

## Role

- `type-generalizing` is a **local boundary-only registry alias** in Starshine.
- The reviewed upstream Binaryen `version_129` pass name is `experimental-type-generalizing`.
- Binaryen registers that upstream name as a **hidden/test pass**, not as a normal public optimizer pass.
- It is currently **unimplemented** in Starshine's active optimizer.
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- It does **not** appear in the saved generated-artifact `-O4z` skipped-slot queue.
- `agent-todo.md` currently has **no dedicated `type-generalizing` slice**.

So this folder is still a useful tracker expansion, but the 2026-04-24 source correction changes what the pass means.

## Correction note

The earlier 2026-04-21 dossier and research note described a closed-world `ContentOracle` pass over `struct.get`, `struct.set`, `call_ref`, and optional `ref.cast` tightening. A fresh official-source check did **not** support that interpretation for Binaryen `version_129`.

The corrected source-backed model is:

- one upstream hidden/test pass: `experimental-type-generalizing`
- one owner file: `src/passes/TypeGeneralizing.cpp`
- one dedicated lit file: `test/lit/passes/type-generalizing.wast`
- no `experimental-type-generalizing-with-optimizing-casts` sibling found in the reviewed release
- no `ContentOracle`, `struct.get`, `struct.set`, `call_ref`, `ref.cast`, or `ReFinalize` visitor surface in this pass

Keep this contradiction visible because the old claim is easy to propagate from the local name alone.

## Beginner summary

A beginner mental model is:

- Binaryen notices that nearby local-flow shapes only require a compatible non-concrete type,
- computes a safe local-flow type using subtype and least-upper-bound reasoning,
- retags defaultable expressions when that makes the local-flow shape simpler,
- and uses a drop-plus-zero replacement for `local.get` when a direct type mutation would be invalid.

This is **not** a whole-program GC oracle pass and **not** a generic type optimizer.

## Most important durable takeaways

- Upstream `experimental-type-generalizing` is hidden/test registered in `pass.cpp`.
- The implementation is function-local and lives in `TypeGeneralizing.cpp`.
- The pass uses local-set/local-tee evidence plus Binaryen `Type` subtype/LUB operations.
- It only rewrites defaultable expressions whose type can safely become the computed compatible type.
- Concrete typed expressions, unreachable expressions, and nondefaultable types are practical barriers.
- `local.get` is the special case: Binaryen replaces it with a sequence that drops the original get and emits a default/zero value of the chosen type.
- Starshine currently preserves only the boundary-only alias `type-generalizing`; it has no owner file, active transform, preset slot, or backlog slice.

## What this pass is not

| Misread | Corrected source-backed fact |
| --- | --- |
| Closed-world `ContentOracle` pass | Function-local type-flow cleanup over local evidence |
| `struct.get` / `struct.set` / `call_ref` / `ref.cast` visitor family | No such visitors in `TypeGeneralizing.cpp` |
| Two upstream public siblings | One hidden/test registration found: `experimental-type-generalizing` |
| Cast-insertion or cast-tightening pass | No cast visitor in the reviewed owner file |
| Starshine partial implementation | Boundary-only alias only |

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)  
  Corrected deep dive into the actual Binaryen `version_129` algorithm and source-backed invariants.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)  
  File-by-file and test-by-test map of the upstream sources that define the corrected contract.
- [`./local-flow-type-floor-and-boundaries.md`](./local-flow-type-floor-and-boundaries.md)  
  Focused guide to local-set/local-tee evidence, defaultability barriers, the `local.get` drop-plus-zero rule, and the stale `ContentOracle` contradiction.
- [`./wat-shapes.md`](./wat-shapes.md)  
  Beginner-friendly before/after shape catalog for the corrected positive, preserved, and no-op families.
- [`./starshine-strategy.md`](./starshine-strategy.md)  
  Current Starshine status and future-port map with exact repository code locations.

## Current maintenance rule

- Treat this folder as the canonical home for future `type-generalizing` research and port planning.
- Cite the 2026-04-24 raw manifest and source-correction note for pass mechanics.
- Treat `0191-2026-04-21-type-generalizing-binaryen-research.md` as historical and superseded for the algorithmic description.
- Do not reintroduce the unsupported `ContentOracle` / `call_ref` / optimizing-casts sibling story unless future primary sources actually add that surface.

## Sources

- [`../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md)
- [`../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md`](../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md)
- Historical superseded note: [`../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md`](../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/ir/hot_core.mbt`](../../../../../src/ir/hot_core.mbt)
- [`../../../../../src/ir/hot_lift.mbt`](../../../../../src/ir/hot_lift.mbt)
- [`../../../../../src/ir/hot_lower.mbt`](../../../../../src/ir/hot_lower.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
