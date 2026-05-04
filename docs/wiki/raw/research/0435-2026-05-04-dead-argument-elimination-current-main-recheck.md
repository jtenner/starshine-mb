---
kind: research
status: supported
last_reviewed: 2026-05-04
sources:
  - ../binaryen/2026-05-04-dead-argument-elimination-current-main-recheck.md
  - ../binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-dead-argument-elimination-primary-sources.md
  - ../../binaryen/passes/dead-argument-elimination/index.md
  - ../../binaryen/passes/dead-argument-elimination/binaryen-strategy.md
  - ../../binaryen/passes/dead-argument-elimination/implementation-structure-and-tests.md
  - ../../binaryen/passes/dead-argument-elimination/wat-shapes.md
  - ../../binaryen/passes/dead-argument-elimination/starshine-strategy.md
  - ../../binaryen/passes/dead-argument-elimination/starshine-port-readiness-and-validation.md
---

# `dead-argument-elimination` current-main recheck

## Question

The plain `dead-argument-elimination` dossier already had a tagged upstream manifest, a current-main readiness check, and a full living page set.
Was the current-main story still aligned enough on 2026-05-04 to keep the dossier current without changing the teaching model?

## Answer

Yes.
The 2026-05-04 spot check found no teaching-relevant drift from the existing plain DAE contract.

The durable conclusions remain:

- plain DAE still shares `DeadArgumentElimination.cpp` with `dae-optimizing`;
- `pass.cpp` still keeps `dae`, `dae-optimizing`, and `dae2` as separate public registrations;
- `opt-utils.h` still owns only the optimizing sibling's nested cleanup replay;
- the plain-pass proof surface still centers on `dae_tnh`, `dae-gc`, `dae-gc-refine-params`, and `dae-gc-refine-return`;
- `dae2.wast` still belongs to the experimental sibling and should not be credited to plain DAE.

## Why this note exists

The old readiness bridge was already durable, but it was timestamped 2026-04-26.
This note lets the living wiki point to a fresher current-main ingest without pretending the contract changed.

## Durable filing rule

Use this note only as freshness evidence.
Keep the real explanatory pages in the living dossier under `docs/wiki/binaryen/passes/dead-argument-elimination/`.
