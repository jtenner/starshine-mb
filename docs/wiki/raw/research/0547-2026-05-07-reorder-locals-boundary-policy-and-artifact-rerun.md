---
kind: research
status: current
last_reviewed: 2026-05-07
sources:
  - ../../binaryen/passes/reorder-locals/parity.md
  - ../../binaryen/passes/reorder-locals/multivalue-call-scope.md
  - ../../../../tests/node/dist/starshine-debug-wasi.wasm
  - ../../../../scripts/self-optimize-compare.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/reorder-locals/parity.md
  - ../../binaryen/passes/reorder-locals/multivalue-call-scope.md
  - ../../binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md
  - ./0540-2026-05-06-reorder-locals-direct-revalidation.md
---

# `reorder-locals` boundary policy and debug-artifact rerun

## Question

After the 2026-05-06 direct-pass revalidation, does current head still justify treating Binaryen's multivalue-call writeback/materialization layer as out of scope for `reorder-locals`, and can `[RL]003` leave the active backlog?

## Evidence

Command run on 2026-05-07:

- `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --binaryen-nop-until-stable 5 --reorder-locals`

The compare lane reported:

- Binaryen no-pass roundtrips: `5`
- Binaryen no-pass converged: `no`
- Canonical wasm equal: `no`
- Normalized WAT equal: `yes`
- Canonical function compare equal: `yes`
- Starshine pass runtime: `56.953 ms`
- Binaryen pass runtime: `86.020 ms`

So current head still shows the same full-artifact pattern documented in the older `0073` / `0074` research pair:

- Binaryen's raw emitted wasm does not settle on the checked-in debug artifact within the configured no-pass writeback budget.
- The representation-stable compare surfaces do settle enough to show `reorder-locals` semantic agreement on the same artifact.
- The remaining raw-output instability is therefore still evidence about Binaryen's surrounding multivalue-call writeback/materialization layer, not about the sorter itself.

## Conclusion

Keep the standing repo decision:

- treat Binaryen's multivalue-call writeback/materialization layer as **out of scope** for current `reorder-locals` parity,
- judge `reorder-locals` on representation-stable surfaces for the debug artifact,
- and leave public preset scheduling deferred under the neighboring ordered-slot tasks rather than as a standalone `reorder-locals` policy blocker.

That closes `[RL]003`. Direct explicit-pass parity remains tracked by `0540`, while future preset placement still depends on the surrounding local-pass neighborhood work.
