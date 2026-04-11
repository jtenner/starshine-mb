---
kind: concept
status: supported
last_reviewed: 2026-04-11
sources:
  - ../../0065-2026-03-24-ir2-execution-plan.md
related:
  - ./test-matrix.md
  - ../../../scripts/test/ir2-handoff-docs.ts
  - ../../../src/passes/optimize.mbt
---

# IR2 Execution Plan

## Durable Conclusions

- `HotFunc` is the only owned optimizer body representation.
- CFG, dominance, post-dominance, loop info, use-def, liveness, effects, and local SSA exist as revision-keyed overlays instead of replacing `HotFunc`.
- The public hot pipeline is:
  `lift -> verify -> run passes -> verify -> lower -> validate`
- The registry surface is intentionally narrow while the rebuilt IR2 leg stays conservative.

## Current Active Surface

- Module passes:
  `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, `reorder-locals`, `duplicate-function-elimination`, `remove-unused-module-elements`
- Hot passes:
  `ssa-nomerge`, `dead-code-elimination`, `remove-unused-names`, `remove-unused-brs`, `vacuum`, `optimize-instructions`, `heap-store-optimization`, `heap2local`, `pick-load-signs`, `precompute`, `simplify-locals`, `tuple-optimization`
- Presets:
  `optimize`, `shrink`
- `optimize` and `shrink` currently expand to the implemented mixed batch-1 sequence, including all currently modeled `remove-unused-names` slots, all `remove-unused-brs` replays, both `precompute` slots, and the mid-function `heap2local` slot.
- `reorder-locals` is active as an explicit module pass, but it still stays out of both presets until its neighboring local-pass slots can be modeled honestly.

## Next Slice Order

1. Batch 2 control and cleanup passes:
   `flatten`, `merge-blocks`, `re-reloop`, `redundant-set-elimination`, `optimize-casts`
2. Batch 3 dataflow-sensitive passes:
   `local-subtyping`, `loop-invariant-code-motion`
3. `tuple-optimization` is already an explicit hot pass and is no longer in the pending batch path; it remains out of public presets until local-cleanup slot parity is finalized.

## Practical Rule

- If a future pass needs a new IR rule or overlay contract, land the docs and contract first, then the pass slice.
- Keep one atomic slice per dependency step instead of mixing architecture changes, pass ports, and cleanup in one change.
- Extend the shared helper and golden layer in [`./test-matrix.md`](./test-matrix.md) instead of inventing ad hoc IR2 harnesses.
- Keep public docs and help text conservative: describe only the passes and registry entries that are real today.

## Sources

- Numbered handoff doc: [`../../0065-2026-03-24-ir2-execution-plan.md`](../../0065-2026-03-24-ir2-execution-plan.md)
- Handoff coverage: [`../../../scripts/test/ir2-handoff-docs.ts`](../../../scripts/test/ir2-handoff-docs.ts)
