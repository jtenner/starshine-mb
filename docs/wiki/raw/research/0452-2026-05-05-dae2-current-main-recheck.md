---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-05-05-dae2-current-main-recheck.md
  - ../binaryen/2026-04-26-dae2-port-readiness-primary-sources.md
  - ../binaryen/2026-04-25-dae2-primary-sources.md
  - ../../binaryen/passes/dae2/index.md
  - ../../binaryen/passes/dae2/binaryen-strategy.md
  - ../../binaryen/passes/dae2/implementation-structure-and-tests.md
  - ../../binaryen/passes/dae2/wat-shapes.md
  - ../../binaryen/passes/dae2/starshine-strategy.md
  - ../../binaryen/passes/dae2/starshine-port-readiness-and-validation.md
---

# `dae2` current-main recheck

## Question

The `dae2` dossier already had immutable primary-source coverage and a port-readiness bridge.
Was the current-main source story still aligned enough on 2026-05-05 to keep the teaching model stable?

## Answer

Yes.
The 2026-05-05 spot check found no teaching-relevant drift from the existing experimental DAE contract.

The durable conclusions remain:

- `dae2` is still a separate public Binaryen pass, not a mode bit on plain `dae`;
- backward used/forwarded-parameter fixed-point analysis is still the core model;
- the closed-world + GC referenced-function rewrite gate still exists as a separate mode;
- the official `dae2.wast` file still exercises the same direct, indirect, reference, and bailout families.

## Why this note exists

The older port-readiness bridge was already durable, but it was timestamped 2026-04-26.
This note lets the living wiki point to a fresher current-main ingest without changing the explanation pages.

## Durable filing rule

Use this note only as freshness evidence.
Keep the real explanatory pages in the living dossier under `docs/wiki/binaryen/passes/dae2/`.
