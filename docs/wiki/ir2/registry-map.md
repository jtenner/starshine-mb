---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../0063-2026-03-24-pass-port-batches-and-registry-map.md
related:
  - ./execution-plan.md
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/optimize_test.mbt
  - ../../../src/passes/registry_test.mbt
---

# IR2 Registry Map

## Durable Conclusions

- The exact live optimizer surface comes from the current registry and preset code, not from historical flag lists alone.
- The registry keeps five explicit categories:
  - active hot passes
  - active module passes
  - active presets
  - boundary-only names
  - removed names
- Boundary-only and removed names stay known for diagnostics and planning, but they are not silent no-ops.

## Current Live Surface

- Active hot passes currently include:
  `ssa-nomerge`, `dead-code-elimination`, `remove-unused-names`, `remove-unused-brs`, `vacuum`, `optimize-instructions`, `heap-store-optimization`, `heap2local`, `pick-load-signs`, `precompute`, and `simplify-locals`.
- Active module passes currently include:
  `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, `reorder-locals`, `duplicate-function-elimination`, and `remove-unused-module-elements`.
- Active presets are still `optimize` and `shrink`.
- `optimize` and `shrink` currently expand to the same implemented pass list.
- `reorder-locals` is active as an explicit module pass but still stays out of both presets until its neighboring local-pass slots can be modeled honestly.

## Current Caveat

- The March batch-map doc was a useful handoff snapshot, but parts of it are now stale relative to current code.
- In particular, `precompute` and `heap2local` have since moved from planned or removed status into the active hot registry and preset expansions.
- Use this page plus the current registry tests for exact answers about what flags and presets are live today.

## Current In-Tree Status

- The registry truth lives in [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt).
- Category and preset coverage live in [`../../../src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt) and [`../../../src/passes/optimize_test.mbt`](../../../src/passes/optimize_test.mbt).
- [`./execution-plan.md`](./execution-plan.md) remains the handoff page for slice order and pipeline orientation, but it is not the exact per-flag registry inventory.

## Practical Rule

- When the question is "can I run this pass or preset now," trust the live registry and its tests.
- Keep legacy names explicit for diagnostics.
- Do not silently accept missing hot ports as no-ops.

## Sources

- Numbered research doc: [`../../0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../0063-2026-03-24-pass-port-batches-and-registry-map.md)
- Live registry: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Registry coverage: [`../../../src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt)
