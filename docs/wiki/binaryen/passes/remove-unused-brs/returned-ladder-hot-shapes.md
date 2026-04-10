---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md
related:
  - ./parity.md
  - ../../../../../src/passes/remove_unused_brs_test.mbt
---

# `remove-unused-brs` Returned-Ladder HOT Shapes

## Durable Conclusions

- Printed WAT is not enough to reason about the remaining returned-ladder `remove-unused-brs` cases.
- After lift, the important families arrive as explicit `Return` and holder-block structures, not as bare typed `if` arms.

A representative lifted shape is:

- `Block(result) -> Return -> If`
- returned arms wrapped in zero-result holder blocks
- nested returned value blocks that contain another typed `If`
- additional zero-result holder blocks around both arms

## Why It Matters

- The current pass is strongest at direct region tails, payload-context rewrites, and block-local branch exits.
- The remaining returned-ladder oracle families do not enter HOT in that direct shape.
- That explains why broader "all return-context tails" probes overfired, regressed performance, or broke existing returned-scalar tests.

## Practical Rule

- Treat these families as lifted-shape work, not just normalized-WAT work.
- The next narrow matcher should target explicit `Return -> If -> holder-block` structure instead of guessing from printed text.
- Preserve the existing returned-scalar regressions that prove some typed returned ladders must survive until later `select` or return stripping.

## Sources

- Archived research doc: [`../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md`](../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md)
- Related pass page: [`./parity.md`](./parity.md)
- Focused tests: [`../../../../../src/passes/remove_unused_brs_test.mbt`](../../../../../src/passes/remove_unused_brs_test.mbt)
