---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./content-oracle-variants-and-boundaries.md
  - ./wat-shapes.md
  - ../type-refining/index.md
  - ../tracker.md
---

# `gufa`

## Role

- `gufa` is an upstream Binaryen whole-program optimization pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` path and it does not appear in the saved generated-artifact `-O4z` skip queue.
- This folder is therefore an explicit tracker expansion for a source-backed upstream-only registry pass.

## Why this pass matters

- The pass already exists as a named local registry surface, so it is a real future port candidate.
- Upstream exposes a public pass family here: `gufa`, `gufa-optimizing`, and `gufa-cast-all`.
- The existing `type-refining` dossier already depends on understanding GUFA as a distinct whole-program inference engine.
- `agent-todo.md` currently has **no dedicated `gufa` slice**.
- Without a dedicated page, beginners can easily blur GUFA into ordinary constant propagation or into the separate `type-refining-gufa` companion.

## Beginner summary

A good beginner mental model is:

- build a whole-program oracle for what values can actually reach each location,
- use that oracle to replace impossible code with `unreachable`,
- replace some locations with known literal / global / `ref.func` values,
- simplify `ref.eq`, `ref.test`, and `ref.cast` using the same oracle,
- optionally add new casts everywhere or run cleanup passes afterward, depending on the chosen variant.

So the pass is best read as:

- **whole-program contents analysis plus a narrow rewrite surface**, not generic constant propagation.

## Current durable takeaways

- `gufa` is a **whole-program**, oracle-driven pass, not a local peephole pass.
- The core helper is `ContentOracle` in `src/ir/possible-contents.h`.
- The plain pass rewrite surface is intentionally narrow: constants, `global.get` / `ref.func`, `unreachable`, `ref.eq`, `ref.test`, and `ref.cast` refinement.
- `gufa-optimizing` is the same analysis plus nested `dce` and `vacuum` reruns on changed functions.
- `gufa-cast-all` is the same analysis plus explicit cast insertion where the oracle knows a narrower type.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` contract: what the pass analyzes, how it rewrites code, why the default scheduler does not run it, and what the public variants really mean.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define `gufa`, `gufa-optimizing`, and `gufa-cast-all`.
- [`./content-oracle-variants-and-boundaries.md`](./content-oracle-variants-and-boundaries.md)
  Focused guide to the most easy-to-misread part of the pass family: `ContentOracle`, closed-world assumptions, plain-vs-optimizing-vs-cast-all behavior, and the main bailout boundaries.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, preserved, and easy-to-misread GUFA families.

## Current maintenance rule

- Treat this folder as the canonical home for future `gufa` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the relationship to [`../type-refining/index.md`](../type-refining/index.md) explicit instead of teaching GUFA only as a side note inside the `type-refining` folder.

## Sources

- [`../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md`](../../../raw/research/0163-2026-04-21-gufa-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
