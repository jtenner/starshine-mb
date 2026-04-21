---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./call-ref-casts-and-boundaries.md
  - ./wat-shapes.md
  - ../type-refining/index.md
  - ../gufa/index.md
  - ../gufa-cast-all/index.md
  - ../type-merging/index.md
---

# `type-generalizing`

## Role

- `type-generalizing` is a **local boundary-only registry alias** in Starshine.
- The upstream Binaryen public names are:
  - `experimental-type-generalizing`
  - `experimental-type-generalizing-with-optimizing-casts`
- It is currently **unimplemented** in Starshine's active optimizer.
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- It does **not** appear in the saved generated-artifact `-O4z` skipped-slot queue.
- `agent-todo.md` currently has **no dedicated `type-generalizing` slice**.

So this folder is an explicit tracker expansion for a real upstream-only registry pass family.

## Why this pass matters

- The local registry still names `type-generalizing`, so it is a real future port surface.
- The pass sits directly beside already-documented GC/type neighbors like `type-refining`, `signature-*`, `abstract-type-refining`, `type-merging`, and `unsubtyping`.
- The local name is easy to misread. Upstream is more honest: this is still an **experimental** pass family, and the family actually has **two** public names.
- The implementation is much narrower than the name suggests, which makes it a good teaching target.

## Beginner summary

A good beginner mental model is:

- Binaryen asks a whole-program possible-contents oracle what values can really flow into a few GC-sensitive sites,
- uses that information to make some expression or field types more precise,
- and then refinalizes if anything changed.

In `version_129`, the real supported rewrite surface is only:

- `struct.get`
- `struct.set`
- `call_ref`
- optionally `ref.cast` in the optimizing-casts sibling

So this is **not** a generic “improve all types everywhere” pass.

## Most important durable takeaways

- The family requires **closed-world** reasoning.
- Upstream wires it as a **function-parallel** pass backed by one module-wide `ContentOracle`.
- The plain sibling narrows types on `struct.get`, `struct.set`, and `call_ref`.
- The second sibling adds **cast-target tightening** for `ref.cast`.
- `call_ref` only rewrites when the possible target set collapses to **one signature**.
- Impossible `call_ref` targets are rewritten to **`unreachable`**.
- Binaryen refinalizes afterwards when GC is enabled and anything changed.

## The sibling split in one table

| Local teaching name | Upstream public name | Extra behavior |
| --- | --- | --- |
| plain `type-generalizing` | `experimental-type-generalizing` | narrows `struct.get`, `struct.set`, and `call_ref` types |
| cast-optimizing sibling | `experimental-type-generalizing-with-optimizing-casts` | same plus `ref.cast` target tightening |

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` contract, helper dependencies, and algorithmic phases.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the family.
- [`./call-ref-casts-and-boundaries.md`](./call-ref-casts-and-boundaries.md)
  Focused guide to the easiest part to misread: the one-signature `call_ref` rule, the impossible-target `unreachable` rewrite, and the cast-optimizing sibling split.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, preserved, and bailout families.

## Current maintenance rule

- Treat this folder as the canonical home for future `type-generalizing` research and port planning.
- Keep the local-vs-upstream naming split explicit: Starshine tracks `type-generalizing`, while Binaryen currently publishes an experimental two-pass family.
- Keep the split from `type-refining` and `gufa-cast-all` explicit too. This pass consumes oracle facts on a tiny rewrite surface; it is not a broad type-shaping pass and it does not insert arbitrary new casts.

## Sources

- [`../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md`](../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeGeneralizing.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing-with-optimizing-casts.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-contents.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>
