---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0217-2026-04-21-type-ssa-binaryen-research.md
  - ../tracker.md
  - ../index.md
  - ../../../../../agent-todo.md
  - ../type-merging/binaryen-strategy.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./wat-shapes.md
  - ../type-merging/index.md
  - ../type-refining/index.md
  - ../ssa/index.md
  - ../type-generalizing/index.md
---

# `type-ssa`

## Role

- `type-ssa` is a real public upstream Binaryen pass in `version_129`.
- It is currently **upstream-only** for this repo.
- It is **not** in the local Starshine pass registry.
- It is **not** part of the current canonical no-DWARF `-O` / `-Os` path.
- It does **not** appear in the saved generated-artifact `-O4z` skipped-slot queue.
- `agent-todo.md` currently has **no dedicated `type-ssa` slice**.

So this folder is an explicit tracker expansion, not a hidden implementation backlog.

## Why this pass matters

`type-ssa` deserved its own dossier for one concrete reason:

- the existing [`../type-merging/index.md`](../type-merging/index.md) dossier already depends on contrasting against it,
- but the tracker and pass map did not yet give it a canonical page of its own.

That made it easy to keep saying “`type-ssa` creates distinctions” without teaching what the pass actually does.

## Beginner summary

A good beginner mental model is:

- when Binaryen sees a value that was **just created** as an exact struct/array/reference type,
- it remembers that precision,
- threads it through simple SSA-like local/global and control-value flows,
- then retags later `local.get`, `global.get`, call arguments, and returns when the narrower type is still subtype-safe.

So `type-ssa` is **not** ordinary SSA conversion and **not** whole-program type inference.
It is a small GC type-precision pass built around **created exact types**.

## Main durable takeaways

- The pass is a **function pass** with a tiny implementation surface.
- Its main state is a `createdTypes` map from expressions to more precise reference types.
- It seeds that map from:
  - `struct.new`
  - `array.new`
  - `array.new_fixed`
  - `ref.as_non_null`
  - `ref.cast`
- It can propagate those facts through:
  - `block` values
  - `if` values when both arms agree
  - some `try` result shapes when the values agree
  - `local.set` / `local.get`
  - `global.set` / `global.get`
- It can then sharpen:
  - direct call operands
  - return values
- It intentionally does **not** treat `loop` as a value-propagation source here.
- If anything changed and GC is enabled, it runs `ReFinalize`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Source-backed explanation of the real `version_129` algorithm, helper surface, pass boundaries, and nearby-pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map for the upstream implementation and public proof surface.
- [`./created-exact-types-control-values-and-signature-rewrites.md`](./created-exact-types-control-values-and-signature-rewrites.md)
  Focused guide to the hardest part to misread: what counts as a created exact type, how `block` / `if` / `try` values propagate it, and where the pass pushes that precision into call and return signatures.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, preserved, and bailout families.

## Current maintenance rule

- Treat this folder as the canonical home for future `type-ssa` research.
- Keep it explicitly marked as **upstream-only** unless Starshine ever adopts it.
- Keep the split from nearby passes explicit:
  - unlike [`../ssa/index.md`](../ssa/index.md), this is not general SSA conversion,
  - unlike [`../type-refining/index.md`](../type-refining/index.md), this is not a closed-world field-analysis pass,
  - unlike [`../type-generalizing/index.md`](../type-generalizing/index.md), this does not consume a content oracle,
  - unlike [`../type-merging/index.md`](../type-merging/index.md), this increases use-site precision instead of merging declarations.

## Sources

- [`../../../raw/research/0217-2026-04-21-type-ssa-binaryen-research.md`](../../../raw/research/0217-2026-04-21-type-ssa-binaryen-research.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../type-merging/binaryen-strategy.md`](../type-merging/binaryen-strategy.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeSSA.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-ssa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>
  - current-main spot checks:
    - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeSSA.cpp>
    - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-ssa.wast>
