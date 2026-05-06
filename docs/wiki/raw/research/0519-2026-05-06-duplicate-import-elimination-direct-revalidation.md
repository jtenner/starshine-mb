---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/duplicate-import-elimination/index.md
  - ../../binaryen/passes/duplicate-import-elimination/starshine-strategy.md
  - ../../../../src/passes/duplicate_import_elimination.mbt
  - ../../../../src/passes/duplicate_import_elimination_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/duplicate-import-elimination/index.md
  - ../../binaryen/passes/duplicate-import-elimination/starshine-strategy.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `duplicate-import-elimination` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `duplicate-import-elimination` direct module pass be removed from the AUD002 stale-evidence revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass duplicate-import-elimination --out-dir .tmp/pass-fuzz-duplicate-import-elimination`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the current known Binaryen parser/canonicalization lane for wasm-smith empty recursion groups. For example, `.tmp/pass-fuzz-duplicate-import-elimination/failures/case-000573-wasm-smith/failure-metadata.json` records `Recursion groups of size zero not supported` from Binaryen while preserving Starshine raw output. These were command failures, not Starshine semantic mismatches.

## Conclusion

`duplicate-import-elimination` is re-proven for direct module-pass parity under the refreshed mixed-generator harness. Keep the direct pass active with the source-confirmed function-import-only Binaryen contract. Public preset widening remains deferred to the broader late-tail neighborhood proof rather than this direct-pass revalidation lane.
