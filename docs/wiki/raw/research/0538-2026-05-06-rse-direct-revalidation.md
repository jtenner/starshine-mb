---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/rse/index.md
  - ../../binaryen/passes/rse/starshine-strategy.md
  - ../../binaryen/passes/rse/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/rse.mbt
  - ../../../../src/passes/rse_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/rse/index.md
  - ../../binaryen/passes/rse/starshine-strategy.md
  - ../../binaryen/passes/rse/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `redundant-set-elimination` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `redundant-set-elimination` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass redundant-set-elimination --out-dir .tmp/pass-fuzz-redundant-set-elimination`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`redundant-set-elimination` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass.

This does **not** close the broader RSE backlog. The current Starshine pass remains direct-only; full Binaryen-style fixed-point CFG merge values, strict-subtype equivalent-local `local.get` retargeting, the late `rse -> vacuum` cleanup lane, and public preset scheduling remain future work.
