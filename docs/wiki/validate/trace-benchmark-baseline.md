---
kind: comparison
status: supported
last_reviewed: 2026-05-13
sources:
  - ../raw/research/0010-2026-03-18-validate-trace-baseline.md
related:
  - ../tooling/validation-gates.md
  - ./ref-func-declarations.md
  - ../../../src/validate_trace/main.mbt
  - ../../../scripts/lib/validate-task.ts
  - ../../../scripts/test/task-family-commands.ts
  - ../../../src/validate/validate.mbt
---

# Validation Trace Benchmark Baseline

## Durable Conclusions

- The benchmark entrypoint is `bun validate trace-benchmark ...`, with `wasm-gc` as the default target; the shared command contract is summarized in [`../tooling/validation-gates.md`](../tooling/validation-gates.md).
- The committed baseline is the emitted `phase_totals`, `helper_totals`, and `hotspots`, not the raw machine wall time.
- The current corpus set is `deep-control`, `wide-locals`, `large-codesec`, and `ref-func-heavy`.
- Each corpus is intended to light up a different validator cost center.

## Current Baseline Signals

- `deep-control`: dominated by code-section and body validation work, plus a visible `datacnt_requirement` check on one very deep function.
- `wide-locals`: low wall time but explicit local-width pressure, with `384` locals and `768` top-level instructions in the hotspot function.
- `large-codesec`: many tiny bodies stress section traversal more than per-body validation cost.
- `ref-func-heavy`: table-section work dominates, with smaller supporting costs in code and data processing; interpret any future `ref_func_declarations` movement through the declaration-source model in [`./ref-func-declarations.md`](./ref-func-declarations.md).

## Practical Rule

- Treat shifts in `phase_totals`, `helper_totals`, or hotspot shape as more trustworthy than shifts in `elapsed_ms`.
- Add new benchmark corpora through [`../../../src/validate_trace/main.mbt`](../../../src/validate_trace/main.mbt) with stable names and one clear stress target each.
- When comparing runs, call out which phase moved and which corpus exposed it, not just the top-line runtime.

## Sources

- Archived benchmark snapshot: [`../raw/research/0010-2026-03-18-validate-trace-baseline.md`](../raw/research/0010-2026-03-18-validate-trace-baseline.md)
- Shared validation-gate map: [`../tooling/validation-gates.md`](../tooling/validation-gates.md)
- Benchmark entrypoint: [`../../../scripts/lib/validate-task.ts`](../../../scripts/lib/validate-task.ts)
