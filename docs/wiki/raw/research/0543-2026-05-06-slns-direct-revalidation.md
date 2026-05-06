---
kind: research
status: current
last_reviewed: 2026-05-06
sources:
  - ../../binaryen/passes/simplify-locals-nostructure/index.md
  - ../../binaryen/passes/simplify-locals-nostructure/starshine-strategy.md
  - ../../binaryen/passes/simplify-locals-nostructure/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../agent-todo.md
related:
  - ../../binaryen/passes/simplify-locals-nostructure/index.md
  - ../../binaryen/passes/simplify-locals-nostructure/starshine-strategy.md
  - ../../binaryen/passes/simplify-locals-nostructure/starshine-port-readiness-and-validation.md
  - ./0513-2026-05-06-starshine-pass-audit.md
---

# `simplify-locals-nostructure` direct revalidation

## Question

After the 2026-05-06 pass-audit harness refresh, can the active `simplify-locals-nostructure` direct pass and its local `simplify-locals-no-structure` alias leave the AUD002 stale-evidence backlog?

## Evidence

Commands run on 2026-05-06:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-nostructure --out-dir .tmp/pass-fuzz-simplify-locals-nostructure`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-locals-no-structure --out-dir .tmp/pass-fuzz-simplify-locals-no-structure`

The canonical spelling run reported:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

The alias run reported the same result:

- compared cases: 6759 / 10000
- normalized matches: 6759
- mismatches: 0
- validation failures: 0
- generator failures: 0
- command failures: 20

During the alias revalidation attempt, the local Moon registry index had to be refreshed with `moon update` after `moon info` briefly failed to resolve `moonbitlang/x`. The rerun succeeded after the registry refresh. No repository files changed from `moon update`.

The command failures match the already-seen Binaryen parser/canonicalization failure class on wasm-smith inputs using empty recursion groups. They are command failures, not semantic mismatches in the compared Starshine/Binaryen outputs.

## Conclusion

`simplify-locals-nostructure` is re-proven for direct explicit-pass parity under the refreshed harness. The compatibility alias `simplify-locals-no-structure` is also re-proven through the same dispatcher/Binaryen canonical mapping. This closes the AUD002 stale-evidence lane for both spellings.

This does **not** close `[SLNS]003` or make the pass preset-ready. Public `optimize` / `shrink` scheduling remains deferred until the ordered `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals` neighborhood is oracle-proven.
