---
kind: workflow
status: supported
last_reviewed: 2026-07-19
sources:
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
related:
  - ./index.md
  - ./starshine-strategy.md
  - ../inlining/fuzzing.md
---

# `inline-main` fuzzing

## Admission

`inline-main` is an active module pass and admitted compare-pass name.

Generic random corpora are usually no-ops because meaningful transformation requires all of:

- a defined function named exactly `main`;
- a defined function named exactly `__original_main`;
- exactly one direct matching `call` or `return_call` inside `main`.

Therefore generic normalized matches prove protocol compatibility only.

## Required focused matrix

A meaningful fixture or generated profile must include:

- ordinary direct `call`;
- direct `return_call`;
- matching tail call nested inside `try_table`;
- nested placement in block/if/loop structures;
- `__original_main` containing nested direct/indirect/ref tail calls;
- scalar and multivalue results;
- nullable/nonnullable copied locals;
- missing/imported endpoints;
- zero and multiple matching calls;
- unrelated direct calls that remain unchanged;
- helper retention after success.

The current focused suite covers the chooser, ordinary/tail/EH-tail rewrite, no-op, and retention families through the shared `120/120` inlining tests.

## Generated-lane acceptance

Before a generated lane can count as closeout evidence, its manifest must record:

- exact function-name creation;
- selected call form and nesting shape;
- whether the pass changed `main`;
- whether `__original_main` remained declared;
- validation of both Starshine and Binaryen outputs.

Until then, direct focused tests plus the shared plain/optimizing `10000/10000` official-v131 closeouts are the durable evidence.
