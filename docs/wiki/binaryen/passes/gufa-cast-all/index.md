---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-gufa-cast-all-primary-sources.md
  - ../../../raw/research/0312-2026-04-24-gufa-cast-all-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cast-insertion-exactness-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../gufa/index.md
  - ../gufa-optimizing/index.md
  - ../heap2local/index.md
  - ../tracker.md
---

# `gufa-cast-all`

## Role

- `gufa-cast-all` is an upstream Binaryen whole-program optimization pass.
- It is currently **unimplemented** in Starshine and lives only as a boundary-only registry name in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` path and it does not appear in the saved generated-artifact `-O4z` skip queue.
- This folder is therefore an explicit upstream-registry dossier plus future-port map, not an implemented-pass parity claim.

## Why this pass matters

- The local registry names `gufa-cast-all` separately from `gufa` and `gufa-optimizing`, so it is a real compatibility surface.
- Binaryen publishes it as a distinct pass name and ships a dedicated `gufa-cast-all.wast` lit file.
- The sibling is easy to misread as “more aggressive GUFA,” but the source-backed contract is narrower and more precise: **plain GUFA rewrites, then fresh `ref.cast` insertion for proven narrower castable reference values**.
- Starshine can already represent and validate many cast shapes, but it does not yet have the whole-program GUFA oracle that makes inserting those casts safe.

## Beginner summary

A good beginner mental model is:

- plain `gufa` proves what values or types can actually reach a site and rewrites that site,
- `gufa-optimizing` does the same proof and then cleans up changed functions,
- `gufa-cast-all` does the same proof and then makes some narrower reference-type facts explicit with new `ref.cast` nodes.

So the pass is best read as:

- **plain GUFA plus post-refinalize cast materialization**, not a different analysis algorithm and not the cleanup-owning sibling.

## Current durable takeaways

- Binaryen `version_129` implements `gufa-cast-all` in the shared [`GUFA.cpp`](https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp) engine with `optimizing = false` and `castAll = true`.
- The whole-program proof engine is still `ContentOracle` from [`possible-contents.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h).
- After a changed function is rewritten, Binaryen refinalizes it, and the cast-all-only `addNewCasts(func)` walk can insert fresh `ref.cast` nodes.
- `addNewCasts` is GC-gated, only uses castable reference-typed sites, requires a real subtype improvement, and downgrades exact targets when custom descriptors are unavailable.
- If cast insertion changes the function, Binaryen refinalizes again before the outer EH nested-pop repair path finishes.
- `gufa-cast-all` does **not** run the nested `dce` + `vacuum` cleanup owned by [`../gufa-optimizing/index.md`](../gufa-optimizing/index.md).
- Starshine currently rejects the name: command parsing admits only active hot/module/preset pass names, and lower-level expansion rejects boundary-only names as not implemented.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` contract: shared analysis, shared rewrite engine, refinalization / EH ordering, and the exact cast-all-only insertion phase.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define `gufa-cast-all`, now anchored to the 2026-04-24 raw source capture.
- [`./cast-insertion-exactness-and-boundaries.md`](./cast-insertion-exactness-and-boundaries.md)
  Focused guide to why Binaryen inserts fresh casts here, why exactness is feature-sensitive, and why preserved no-op cases are part of the contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, preserved, and bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map with exact local code locations.

## Current maintenance rule

- Treat this folder as the canonical home for future `gufa-cast-all` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real whole-program GUFA owner and dispatch path.
- Keep the split from [`../gufa/index.md`](../gufa/index.md) and [`../gufa-optimizing/index.md`](../gufa-optimizing/index.md) explicit instead of teaching this sibling only as a footnote.

## Sources

- [`../../../raw/binaryen/2026-04-24-gufa-cast-all-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-cast-all-primary-sources.md)
- [`../../../raw/research/0312-2026-04-24-gufa-cast-all-primary-sources-and-starshine-followup.md`](../../../raw/research/0312-2026-04-24-gufa-cast-all-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md`](../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
