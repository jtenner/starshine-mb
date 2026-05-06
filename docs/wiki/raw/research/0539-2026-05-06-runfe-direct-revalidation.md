---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/remove-unused-non-function-elements/index.md
  - ../../binaryen/passes/remove-unused-non-function-elements/starshine-strategy.md
  - ../../binaryen/passes/remove-unused-non-function-elements/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../src/passes/remove_unused_module_elements_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/remove-unused-non-function-elements/index.md
  - ../../binaryen/passes/remove-unused-non-function-elements/starshine-strategy.md
  - ../../binaryen/passes/remove-unused-non-function-elements/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `remove-unused-nonfunction-module-elements` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `remove-unused-nonfunction-module-elements` direct module pass be removed from the AUD002 stale-evidence revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass remove-unused-nonfunction-module-elements --out-dir .tmp/pass-fuzz-remove-unused-nonfunction-module-elements`

The pass-fuzz run reported:

- compared cases: 6581 / 10000
- normalized matches: 6581
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the current known Binaryen parser/canonicalization lane for wasm-smith empty recursion groups. They were command failures, not Starshine semantic mismatches.

## Conclusion

`remove-unused-nonfunction-module-elements` is re-proven for direct pass parity under the refreshed mixed-generator harness. Keep it active as a direct module pass under the upstream-compatible spelling; no fresh post-fuzzer-change direct-pass mismatch is known for this sibling pass.
