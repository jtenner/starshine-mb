---
kind: decision
status: supported
last_reviewed: 2026-05-07
sources:
  - ../../../raw/research/0547-2026-05-07-reorder-locals-boundary-policy-and-artifact-rerun.md
  - ../../../raw/research/0074-2026-04-02-binaryen-multivalue-call-local-disparity.md
  - ../../../raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md
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
- Treat non-converging multivalue-call writeback as a separate Binaryen boundary problem.
- Only port this layer if Binaryen-style raw emitted-wasm parity for multivalue call writeback becomes an explicit project goal.

## Sources

- Current closure note: [`../../../raw/research/0547-2026-05-07-reorder-locals-boundary-policy-and-artifact-rerun.md`](../../../raw/research/0547-2026-05-07-reorder-locals-boundary-policy-and-artifact-rerun.md)
- Archived research doc: [`../../../raw/research/0074-2026-04-02-binaryen-multivalue-call-local-disparity.md`](../../../raw/research/0074-2026-04-02-binaryen-multivalue-call-local-disparity.md)
- Related parity page: [`./parity.md`](./parity.md)
