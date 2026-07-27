---
kind: decision
status: supported
last_reviewed: 2026-07-27
sources:
  - ./index.md
related:
  - ./parity.md
  - ../../../../../scripts/lib/self-optimize-compare-task.ts
---

# `reorder-locals` Scope Around Multivalue Call Writeback

## Decision

- Non-converging Binaryen multivalue-call writeback is out of scope for current `reorder-locals` parity.
- Judge the pass at a representation-stable boundary instead of trying to match Binaryen's tuple-packaging scratch-local strategy byte for byte.

## Why

- Binaryen's IR builder reads multivalue calls as tuple-valued `Call` expressions.
- When scalar consumers need individual results, the builder introduces tuple scratch locals and `tuple.extract`.
- The stack writer then expands tuple locals back into scalar wasm locals and may allocate additional scalar scratch locals.
- Minimal triple-result call witnesses therefore grow by `+5` locals per Binaryen roundtrip.
- Block-only multivalue witnesses can stabilize after scalarization, but multivalue call witnesses can keep growing and fail convergence.
- This behavior happens before and after `ReorderLocals.cpp`; it is not evidence that Starshine's sorter is wrong.

## Binaryen v131 generated evidence

The 2026-07-27 random-all lane found one repeated non-pass-owned shape family: all `625` `remove-unused-brs-control` selections differed because Binaryen materialized type-indexed multivalue blocks into a different scratch-local/control shape before `ReorderLocals.cpp` ran. Starshine preserved the direct block representation.

This family is retained as a measured Starshine win, not dismissed as merely equivalent representation:

- Starshine canonical wasm was exactly `8` bytes smaller in all `625` random-all cases (`-5000` total).
- A separate `1000`-case replay validated both outputs with `wasm-tools` and executed every case in Node.
- Runtime evidence was `757` equal results plus `243` equal traps, with zero semantic mismatches.
- Starshine was exactly `8` canonical bytes smaller in every replay case (`-8000` total).

Reopen this decision if runtime results diverge, Starshine stops being no larger, or a future Binaryen release no longer materializes the alternate shape.

## Refreshed full-artifact evidence

- A 2026-05-07 current-head replay reran `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --binaryen-nop-until-stable 5 --reorder-locals`.
- Binaryen no-pass writeback still did not converge within 5 roundtrips, and canonical emitted wasm still compared red.
- The same replay still reached `Normalized WAT equal: yes` and `Canonical function compare equal: yes` on the debug artifact.
- That keeps the repo decision stable: the remaining full-artifact raw-output drift still belongs to Binaryen's multivalue-call writeback/materialization boundary, not to the `reorder-locals` sorter contract.

## Current Tooling

[`../../../../../scripts/lib/self-optimize-compare-task.ts`](../../../../../scripts/lib/self-optimize-compare-task.ts) supports:

- `--binaryen-nop-roundtrips <n>`
- `--binaryen-nop-until-stable <max>`
- `--require-binaryen-nop-converged`
- The related command tests live under `scripts/test/self-optimize-compare-*-command.ts`.

## Practical Rule

- Use stable-boundary compares for block-like multivalue carriers.
- Require measured canonical size and runtime evidence before retaining a different shape as a Starshine win.
- Treat non-converging multivalue-call writeback as a separate Binaryen boundary problem.
- Only port this layer if Binaryen-style raw emitted-wasm parity for multivalue call writeback becomes an explicit project goal or the retained Starshine shape loses its measured advantage.

## Sources

- Current closure note: [research note 0547](./index.md)
- Durable owner: [research note 0074](./index.md)
- Related parity page: [`./parity.md`](./parity.md)
