---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/simplify-locals-notee-nostructure/index.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/starshine-strategy.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/simplify-locals-notee-nostructure/index.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/starshine-strategy.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `simplify-locals-notee-nostructure` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `simplify-locals-notee-nostructure` direct pass leave the AUD002 stale-evidence backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-notee-nostructure --out-dir .tmp/pass-fuzz-simplify-locals-notee-nostructure`

The direct-pass run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures were Binaryen/tool command failures, not Starshine/Binaryen semantic mismatches in compared outputs:

- `binaryen-rec-group-zero`: 17
- `binaryen-bad-section-size`: 1
- `binaryen-table-index-out-of-range`: 1
- `binaryen-invalid-tag-index`: 1

## Conclusion

`simplify-locals-notee-nostructure` is re-proven for direct explicit-pass parity under the refreshed harness and can be pruned from the AUD002 stale-evidence lane.

This does **not** close `[SLNNS]003` or make the pass preset-ready. Public `optimize` / `shrink` scheduling remains deferred until the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood is representable and oracle-proven.
