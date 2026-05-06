---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/vacuum/index.md
  - ../../binaryen/passes/vacuum/starshine-hot-ir-strategy.md
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/vacuum/index.md
  - ../../binaryen/passes/vacuum/starshine-hot-ir-strategy.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `vacuum` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `vacuum` direct hot pass be removed from the AUD002 stale-evidence revalidation backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `moon test src/passes`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass vacuum --out-dir .tmp/pass-fuzz-vacuum`

The first post-audit mixed-generator replay found five wasm-smith mismatches where Starshine emitted an empty function body and Binaryen's `vacuum` canonicalized the same empty body to a single `nop`. The durable reduced regression is now `vacuum matches Binaryen empty function nop canonicalization` in `src/passes/optimize_test.mbt`.

After the fix, the pass-fuzz run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The command failures match the current known Binaryen parser/canonicalization lane for wasm-smith empty recursion groups. For example, `.tmp/pass-fuzz-vacuum/failures/case-000573-wasm-smith/failure-metadata.json` records `Recursion groups of size zero not supported` from Binaryen while preserving Starshine raw output. These were command failures, not Starshine semantic mismatches.

## Conclusion

`vacuum` is re-proven for direct hot-pass parity under the refreshed mixed-generator harness. The completed fix is narrow: preserve the existing `vacuum` rewrite scope, but when the pass is forced through lower/writeback for an empty body, canonicalize that empty function body to Binaryen's single-`nop` form. Broader Binaryen `vacuum` semantics remain future parity work, but the refreshed AUD002 direct revalidation item is closed.
