# SGO full parity backlog reactivation

Date: 2026-05-25

## Question

The recurring SGO slice cron found an in-progress `agent-todo.md` edit that moved `simplify-globals-optimizing` from the evidence-gated follow-up area back into the active v0.1.0 slice list. Should that be treated as active work or discarded?

## Decision

Treat the edit as the active recovery state for the cron and keep it as a planning/backlog change. This does **not** invalidate the accepted v0.1.0 supported-surface signoff in [`0573`](./0573-2026-05-19-sgo-v010-signoff.md), and it does **not** claim that Starshine already has full Binaryen `SimplifyGlobals.cpp` parity.

The practical interpretation is:

- current supported SGO behavior remains signed off and non-blocking for the prior v0.1.0 supported surface;
- full Binaryen `SimplifyGlobals.cpp` breadth is now an active product-goal backlog again;
- the first active implementation-enabling child is `[SGO]003A`, the Binaryen source audit and fact-table parity slice;
- behavior changes still need a focused Binaryen-positive source/probe shape, tests first, direct SGO fuzz, and docs/wiki updates.

## Active task selected for the next implementation run

`[SGO]003A - Binaryen Source Audit And Fact-Table Parity`.

The task is intentionally too large to finish in this recovery run. `agent-todo.md` now enumerates the required child slices, guardrails, validation commands, and exit criteria so the next cron run can start at `[SGO]003A` without ambiguity.

## Source basis

- [`agent-todo.md`](../../../../agent-todo.md) now carries the active v0.1.0 SGO full-parity backlog and child slices.
- [`parity-matrix.md`](../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md) still separates supported-surface signoff from incomplete full Binaryen breadth.
- [`0573`](./0573-2026-05-19-sgo-v010-signoff.md) remains the accepted supported-surface signoff.
- [`0673`](./0673-2026-05-25-sgo003-call-breadth-closeout.md) remains valid for the previously enumerated call-breadth queue: future call breadth still needs a fresh explicit child slice.

## Validation

No optimizer behavior, tests, registry entries, or public APIs changed in this recovery run. Moon and fuzz validation were not required for this docs/backlog-only reactivation.
