---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/coalesce_locals.mbt
  - ../../../../src/passes/coalesce_locals_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/coalesce-locals/index.md
  - ../../binaryen/passes/coalesce-locals/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `coalesce-locals` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `coalesce-locals` direct module pass be removed from the AUD002 stale-evidence revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass coalesce-locals --out-dir .tmp/pass-fuzz-coalesce-locals`

The pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the current known Binaryen parser/canonicalization lane for wasm-smith empty recursion groups. They were command failures, not Starshine semantic mismatches.

## Conclusion

`coalesce-locals` is re-proven for direct pass parity under the refreshed mixed-generator harness. Keep the active direct module pass in its existing explicit surface, and keep public preset placement deferred to the ordered-neighborhood proof tracked by `[CL]003`.
