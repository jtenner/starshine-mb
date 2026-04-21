---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cleanup-rerun-contract.md
  - ./wat-shapes.md
  - ../gufa/index.md
  - ../tracker.md
---

# `gufa-optimizing`

## Role

- `gufa-optimizing` is an upstream Binaryen whole-program optimization pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` path and it does not appear in the saved generated-artifact `-O4z` skip queue.
- This folder is therefore an explicit tracker expansion for a source-backed upstream-only registry pass.

## Why this pass matters

- The local registry already names `gufa-optimizing` separately, so it is a real future port surface rather than a theoretical upstream curiosity.
- Upstream Binaryen registers it as a distinct public pass name in `pass.cpp`.
- The broader `gufa` dossier already explains the shared `ContentOracle` engine, but that folder does **not** replace a dedicated page for the optimizing sibling's real public contract.
- `agent-todo.md` currently has **no dedicated `gufa-optimizing` slice**.
- Beginners can easily misread this sibling as “just more aggressive GUFA,” when its real purpose is **post-rewrite cleanup of changed functions via nested `dce` + `vacuum`**.

## Beginner summary

A good beginner mental model is:

- plain `gufa` proves what values or types can actually reach a location and rewrites the site,
- `gufa-optimizing` does the same proof and the same rewrites,
- but then it immediately cleans up the extra `drop`, `block`, dead-result, and `unreachable` scaffolding those proofs can leave behind.

So the pass is best read as:

- **plain GUFA plus nested cleanup on modified functions**, not a different analysis algorithm.

## Current durable takeaways

- `gufa-optimizing` is the same shared `GUFA.cpp` engine as plain `gufa`, with `optimizing = true` and `castAll = false`.
- The whole-program analysis is still `ContentOracle` in `src/ir/possible-contents.h`.
- The optimizing sibling does **not** widen the core GUFA rewrite surface.
- Its main public difference is in `visitFunction`: after refinalization and EH nested-pop repair, Binaryen runs a nested `PassRunner` containing **`dce` then `vacuum`** on changed functions.
- The dedicated `gufa-optimizing.wast` file exists specifically to prove that cleanup contract.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` contract: shared analysis, shared rewrite engine, and the exact optimizing-only nested cleanup phase.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define `gufa-optimizing`.
- [`./cleanup-rerun-contract.md`](./cleanup-rerun-contract.md)
  Focused guide to the easiest part of the sibling to misread: why GUFA creates cleanup debt, why the optimizing sibling runs `dce` then `vacuum`, and what that means for future ports.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, preserved, and bailout families.

## Current maintenance rule

- Treat this folder as the canonical home for future `gufa-optimizing` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the split from both [`../gufa/index.md`](../gufa/index.md) and the separate `gufa-cast-all` variant explicit instead of teaching the sibling only as a footnote.

## Sources

- [`../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md`](../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
  - <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
