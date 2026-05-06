---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/global-struct-inference/index.md
  - ../../binaryen/passes/global-struct-inference/starshine-strategy.md
  - ../../binaryen/passes/global-struct-inference/parity.md
  - ../../../../src/passes/global_struct_inference.mbt
  - ../../../../src/passes/global_struct_inference_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/global-struct-inference/index.md
  - ../../binaryen/passes/global-struct-inference/starshine-strategy.md
  - ../../binaryen/passes/global-struct-inference/parity.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `global-struct-inference` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `global-struct-inference` direct pass stay out of the AUD002 revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass global-struct-inference --out-dir .tmp/pass-fuzz-global-struct-inference`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`global-struct-inference` is re-proven for direct explicit-pass parity under the refreshed harness. This closes the AUD002 stale-evidence lane for the pass, but it does not change the documented local-vs-upstream capability gaps: Starshine still implements a narrow closed-world direct-global subset rather than the full Binaryen origin-analysis contract.
