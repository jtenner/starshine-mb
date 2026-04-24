---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md
  - ../../../raw/research/0311-2026-04-24-gufa-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cleanup-rerun-contract.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../gufa/index.md
  - ../gufa-cast-all/index.md
  - ../dead-code-elimination/index.md
  - ../vacuum/index.md
  - ../tracker.md
---

# `gufa-optimizing`

## Role

- `gufa-optimizing` is an upstream Binaryen whole-program optimization pass.
- It is currently **unimplemented** in Starshine and lives only as a boundary-only registry name in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` path and it does not appear in the saved generated-artifact `-O4z` skip queue.
- This folder is therefore an explicit upstream-registry dossier plus future-port map, not an implemented-pass parity claim.

## Why this pass matters

- The local registry names `gufa-optimizing` separately from `gufa` and `gufa-cast-all`, so it is a real compatibility surface.
- Binaryen publishes it as a distinct pass name and ships a dedicated `gufa-optimizing.wast` lit file.
- The sibling is easy to misread as “stronger GUFA,” but the source-backed contract is narrower and more precise: **plain GUFA rewrites, then `dce` and `vacuum` on changed functions**.
- The existing Starshine cleanup passes are useful future building blocks, but without a whole-program GUFA oracle they do not implement this pass.

## Beginner summary

A good beginner mental model is:

- plain `gufa` proves what values or types can actually reach a site and rewrites that site,
- `gufa-optimizing` does the same proof and the same rewrites,
- then it immediately cleans up the `drop`, `block`, dead-tail, and `unreachable` residue in functions the GUFA rewrite changed.

So the pass is best read as:

- **plain GUFA plus changed-function cleanup**, not a different analysis algorithm and not the cast-insertion sibling.

## Current durable takeaways

- Binaryen `version_129` implements `gufa-optimizing` in the shared [`GUFA.cpp`](https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp) engine with `optimizing = true` and `castAll = false`.
- The whole-program proof engine is still `ContentOracle` from [`possible-contents.h`](https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h).
- After a changed function is rewritten, Binaryen refinalizes it, repairs EH nested pops, and then runs nested `dce` followed by `vacuum` on that function.
- `gufa-optimizing` does **not** insert the fresh casts owned by [`../gufa-cast-all/index.md`](../gufa-cast-all/index.md).
- Starshine currently rejects the name: command parsing admits only active hot/module/preset pass names, and lower-level expansion rejects boundary-only names as not implemented.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` contract: shared analysis, shared rewrite engine, refinalization / EH ordering, and the exact optimizing-only nested cleanup phase.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define `gufa-optimizing`, now anchored to the 2026-04-24 raw source capture.
- [`./cleanup-rerun-contract.md`](./cleanup-rerun-contract.md)
  Focused guide to why GUFA creates cleanup debt and why this sibling runs `dce` then `vacuum`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, preserved, and bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map with exact local code locations.

## Current maintenance rule

- Treat this folder as the canonical home for future `gufa-optimizing` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real whole-program GUFA owner and dispatch path.
- Keep the split from [`../gufa/index.md`](../gufa/index.md) and [`../gufa-cast-all/index.md`](../gufa-cast-all/index.md) explicit instead of teaching this sibling only as a footnote.

## Sources

- [`../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md)
- [`../../../raw/research/0311-2026-04-24-gufa-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0311-2026-04-24-gufa-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md`](../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
