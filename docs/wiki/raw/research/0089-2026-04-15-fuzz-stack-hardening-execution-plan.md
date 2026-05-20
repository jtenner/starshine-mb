# 0089 - Fuzz Stack Hardening Execution Plan

> Archived on 2026-05-20. This is the completed historical ledger for the validator-fuzz hardening campaign; the living contract is [`../../validate/fuzz-hardening.md`](../../validate/fuzz-hardening.md).

## Status

Completed and superseded.

## What this ledger covered

- Truthful suite inventory and runner naming
- Shared valid-generator config and stats plumbing
- Broader valid-module topology and body generation
- AST, binary, text, and spec-seed invalid lanes
- Invalid repro persistence, shrinking, and replay
- Wrapper/docs alignment for `moon` and `bun`

## Living pages to use now

- [`../../validate/fuzz-hardening.md`](../../validate/fuzz-hardening.md)
- [`../../tooling/fuzz-runner.md`](../../tooling/fuzz-runner.md)
- [`../../validate/diagnostics-and-invalid-repro.md`](../../validate/diagnostics-and-invalid-repro.md)
- [`../../fuzzing/generator-coverage-ledger.md`](../../fuzzing/generator-coverage-ledger.md)
- [`../../wast/static-assertion-harness.md`](../../wast/static-assertion-harness.md)

## Key repository surfaces

- [`../../../../src/fuzz/main.mbt`](../../../../src/fuzz/main.mbt)
- [`../../../../src/fuzz/main_wbtest.mbt`](../../../../src/fuzz/main_wbtest.mbt)
- [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt)
- [`../../../../src/validate/invalid_fuzzer.mbt`](../../../../src/validate/invalid_fuzzer.mbt)
- [`../../../../src/fuzz/invalid_repro.mbt`](../../../../src/fuzz/invalid_repro.mbt)
- [`../../../../src/cmd/fuzz_harness.mbt`](../../../../src/cmd/fuzz_harness.mbt)
- [`../../../../scripts/lib/fuzz-task.ts`](../../../../scripts/lib/fuzz-task.ts)
- [`../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../scripts/lib/pass-fuzz-compare-task.ts)
- [`../../../../src/wast/spec_harness.mbt`](../../../../src/wast/spec_harness.mbt)
- [`../../../../src/binary/tests.mbt`](../../../../src/binary/tests.mbt)

## Historical follow-ups

- [`./0058-2026-03-23-validate-fuzz-hardening-plan.md`](./0058-2026-03-23-validate-fuzz-hardening-plan.md)
- [`./0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md`](./0090-2026-04-16-gen-valid-rume-imported-function-parity-followup.md)
- [`./0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md`](./0091-2026-04-16-gen-valid-rume-start-section-parity-followup.md)

## Note

The full slice-by-slice chronology remains in git history. Future validator-fuzz work should start from the living pages above instead of reopening this plan as the task source of truth.
