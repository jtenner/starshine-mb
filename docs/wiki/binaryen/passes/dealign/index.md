---
kind: entity
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../alignment-lowering/index.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./align-one-rewrite-surface-and-alignment-lowering-split.md
  - ./wat-shapes.md
  - ../alignment-lowering/index.md
  - ../tracker.md
---

# `dealign`

## Role

- `dealign` is a real public Binaryen pass.
- It is currently **upstream-only** in this repo's living pass map: it is **not** in Starshine's local optimizer registry in `src/passes/optimize.mbt`.
- It is **not** part of the repo's canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `dealign` slice**.

## Why this dossier exists

The tracker currently has no obvious remaining pass entries with wiki status `none`.
That means a new dossier needs explicit justification.

`dealign` is justified because the refreshed `alignment-lowering` dossier already depended on teaching its opposite-direction sibling precisely, but the wiki had no canonical home explaining what `dealign` actually does.

Without this folder, it was too easy to blur together:

- `alignment-lowering`, which legalizes weakly aligned scalar loads and stores by splitting them into smaller aligned scalar accesses, and
- `dealign`, which simply weakens selected alignment immediates to `1`.

## Beginner summary

A good beginner mental model is:

- walk over a module's defined functions
- find visited loads and stores that currently claim stronger alignment than `1`
- rewrite only the alignment metadata to `1`
- leave everything else alone

So this pass is best taught as:

- **alignment-metadata pessimization / normalization to `align=1`**
- not a legality pass
- not a chunk-splitting pass
- not a generic memory optimizer

## Most important durable takeaways

- The entire reviewed `version_129` contract is concentrated in `DeAlign.cpp`, `pass.cpp`, and one dedicated lit file.
- The pass is a tiny module pass with an early `module->memory.exists()` bailout.
- It visits only `Load`, `Store`, `SIMDLoad`, and `SIMDStore`.
- The core rewrite rule is literally: if `align > 1`, set `align = 1`.
- It preserves offset, width, signedness, opcode family, pointer/value children, and trapping semantics.
- It is the conceptual opposite-direction sibling of `alignment-lowering`, but not the same kind of pass.
- The dedicated lit file proves the scalar rewrite surface directly; SIMD support is source-confirmed from `DeAlign.cpp` more than from a visibly dedicated lit case.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: the tiny module-pass structure, exact visitor surface, scope boundaries, and why this is an alignment-metadata pass rather than a legality pass.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact owner-file and proof-surface map for `DeAlign.cpp`, `pass.cpp`, and `dealign.wast`.
- [`./align-one-rewrite-surface-and-alignment-lowering-split.md`](./align-one-rewrite-surface-and-alignment-lowering-split.md)
  Focused guide to the exact rewrite surface, the scalar-vs-SIMD split, and the important contrast with `alignment-lowering`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the direct `align -> 1` rewrites, no-op families, preserved fields, and main non-goals.

## Current maintenance rule

- Treat this folder as the canonical home for future `dealign` research.
- Keep it explicitly marked as an **upstream-only** dossier unless Starshine later grows a local registry entry.
- Keep the split from `alignment-lowering` explicit: `dealign` weakens alignment metadata, while `alignment-lowering` rewrites weakly aligned scalar accesses into smaller aligned ones.
- Keep the smallness of the contract explicit too: this is one of those passes where the real source-backed behavior is much narrower than the public name may suggest.

## Sources

- [`../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md`](../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../alignment-lowering/index.md`](../alignment-lowering/index.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
- Current-`main` spot-check sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeAlign.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dealign.wast>
