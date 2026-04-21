---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cast-insertion-exactness-and-boundaries.md
  - ./wat-shapes.md
  - ../gufa/index.md
  - ../gufa-optimizing/index.md
  - ../tracker.md
---

# `gufa-cast-all`

## Role

- `gufa-cast-all` is an upstream Binaryen whole-program optimization pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` path and it does not appear in the saved generated-artifact `-O4z` skip queue.
- This folder is therefore an explicit tracker expansion for a source-backed upstream-only registry pass.

## Why this pass matters

- The local registry already names `gufa-cast-all` separately, so it is a real future port surface.
- Upstream Binaryen registers it as a distinct public pass name in `pass.cpp`.
- Upstream ships a dedicated `gufa-cast-all.wast` lit file for it.
- `agent-todo.md` currently has **no dedicated `gufa-cast-all` slice**.
- The existing `gufa` dossier explains the family, but beginners still need a dedicated page for the cast-owning sibling's exact contract.

## Beginner summary

A good beginner mental model is:

- plain `gufa` proves what values or type cones can reach a site,
- `gufa-optimizing` does the same proof and then cleans up changed functions,
- `gufa-cast-all` does the same proof and then makes some of that sharper reference knowledge explicit by inserting new `ref.cast` nodes.

So the pass is best read as:

- **plain GUFA plus a post-refinalize cast-insertion walk**, not a different inference engine and not the cleanup-owning sibling.

## Current durable takeaways

- `gufa-cast-all` is the same shared `GUFA.cpp` engine as plain `gufa`, with `optimizing = false` and `castAll = true`.
- The whole-program analysis is still `ContentOracle` in `src/ir/possible-contents.h`.
- The first-phase rewrite surface is still plain GUFA: exact-value replacement, `unreachable`, `ref.eq`, `ref.test`, and existing `ref.cast` refinement.
- The sibling's distinctive phase is `addNewCasts(func)`, which runs **after refinalization** when Binaryen knows a narrower castable reference type than the current IR type.
- The dedicated `gufa-cast-all.wast` file exists specifically to prove that new-cast insertion, exactness limits, and preserved no-op cases are part of the real public contract.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` contract: shared analysis, shared first-phase rewrites, and the exact cast-all-only post-pass.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define `gufa-cast-all`.
- [`./cast-insertion-exactness-and-boundaries.md`](./cast-insertion-exactness-and-boundaries.md)
  Focused guide to the easiest part of the sibling to misread: why Binaryen adds fresh casts here, why exactness is feature-sensitive, and why many seemingly-obvious casts are still not inserted.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, preserved, and bailout families.

## Current maintenance rule

- Treat this folder as the canonical home for future `gufa-cast-all` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the split from both [`../gufa/index.md`](../gufa/index.md) and [`../gufa-optimizing/index.md`](../gufa-optimizing/index.md) explicit instead of teaching this sibling only as a footnote.

## Sources

- [`../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md`](../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
