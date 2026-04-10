---
kind: comparison
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md
related:
  - ./returned-ladder-hot-shapes.md
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_test.mbt
---

# `remove-unused-brs` Binaryen Parity

## Durable Conclusions

- Binaryen's `RemoveUnusedBrs` is phased, not a bag of independent peepholes.

The oracle shape is:

- a repeated postwalk fixpoint for flowing unconditional branches and returns
- loop cleanup plus block sinking and branch threading
- a final optimizer block that performs `restructureIf`, `selectify`, `tablify`, adjacent branch cleanup, and local-set arm rewrites

- MoonBit already covers trailing redundant branch or return stripping, one-armed `if` to `br_if`, many tail branch-exit rewrites, return-context stripping, value-`if` to `select`, local-set arm rewrites, and several targeted perf bailouts.

## Current In-Tree Status

- The implementation lives in [`../../../../../src/passes/remove_unused_brs.mbt`](../../../../../src/passes/remove_unused_brs.mbt).
- The focused correctness suite lives in [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt).
- The raw or hot skip and perf guard coverage lives in [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt).
- Preset replay coverage for all RUB slots lives in [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt).
- CLI and debug-artifact coverage lives in [`../../../../../src/cmd/cmd_test.mbt`](../../../../../src/cmd/cmd_test.mbt).

## Active Gap

- The remaining parity families are not just tail-branch-removal gaps.
- The real missing area is Binaryen's later final-shape cleanup, especially the `restructureIf` family that only becomes cheap after earlier simplification.
- Earlier MoonBit attempts tried to find those shapes by scanning more nested regions during the main walk, which hit real oracle cases but reopened the performance cliff.

## Practical Rule

- Keep extending `remove-unused-brs` in Binaryen-like phase order.
- Do not widen nested-region probing just to hit one remaining oracle family.
- Prefer structurally narrow late-phase matchers over broad "all return-context" or "all nested tail" discovery.

## Sources

- Archived research doc: [`../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md`](../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md)
- HOT shape note: [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md)
- Implementation: [`../../../../../src/passes/remove_unused_brs.mbt`](../../../../../src/passes/remove_unused_brs.mbt)
- Focused tests: [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt)
