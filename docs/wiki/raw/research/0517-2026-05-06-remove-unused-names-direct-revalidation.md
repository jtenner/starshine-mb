---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/remove-unused-names/index.md
  - ../../binaryen/passes/remove-unused-names/starshine-hot-ir-strategy.md
  - ../../../../src/passes/remove_unused_names.mbt
  - ../../../../src/passes/remove_unused_names_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/remove-unused-names/index.md
  - ../../binaryen/passes/remove-unused-names/starshine-hot-ir-strategy.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `remove-unused-names` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `remove-unused-names` direct pass be removed from the AUD002 stale-evidence revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass remove-unused-names --out-dir .tmp/pass-fuzz-remove-unused-names`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the current known Binaryen parser/canonicalization lane for wasm-smith empty recursion groups. They were command failures, not Starshine semantic mismatches.

## Conclusion

`remove-unused-names` is re-proven for direct pass parity under the refreshed mixed-generator harness. Keep it active in its existing direct/preset slots; no fresh post-fuzzer-change direct-pass mismatch is known for this pass.
