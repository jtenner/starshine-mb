---
kind: research
status: supported
last_reviewed: 2026-05-04
sources:
  - ../binaryen/2026-05-04-reorder-types-current-main-recheck.md
  - ../binaryen/2026-04-24-reorder-types-primary-sources.md
  - ../../binaryen/passes/reorder-types/index.md
  - ../../binaryen/passes/reorder-types/binaryen-strategy.md
  - ../../binaryen/passes/reorder-types/implementation-structure-and-tests.md
  - ../../binaryen/passes/reorder-types/ordering-cost-model-and-boundaries.md
  - ../../binaryen/passes/reorder-types/wat-shapes.md
  - ../../binaryen/passes/reorder-types/starshine-strategy.md
---

# `reorder-types` current-main recheck

## Question

The living `reorder-types` dossier already had a source-confirmed contract, an exact cost-model page, and a Starshine status page.
Was the current-main story still aligned enough on 2026-05-04 to keep the dossier fresh without changing the teaching model?

## Answer

Yes.
The 2026-05-04 spot check found no teaching-relevant drift from the existing `reorder-types` contract.

The durable conclusions remain:

- `reorder-types` still reorders only private heap types;
- the pass still requires GC and `--closed-world`;
- the legality graph still comes from private supertypes plus private described types;
- the sort still samples 21 successor-weight factors;
- the final rewrite still goes through `GlobalTypeRewriter` and remaps the whole module.

## Why this note exists

The old source-confirmed dossier was already durable, but it was timestamped 2026-04-24.
This note lets the living wiki point to a fresher current-main ingest without pretending the contract changed.

## Durable filing rule

Use this note only as freshness evidence.
Keep the real explanatory pages in the living dossier under `docs/wiki/binaryen/passes/reorder-types/`.
