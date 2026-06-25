---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ./1132-2026-06-25-heap-store-optimization-post-1131-validation.md
  - ./1120-2026-06-25-heap-store-optimization-post-1119-validation.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# HSO speed parity target refresh

## Question

What is the active HSO-I performance target after the user requested Binaryen speed parity rather than the earlier relaxed `<=2x` pass-local threshold?

## Answer

The active target is now at least `0.95x` Binaryen speed for the allocation-heavy HSO fixture. Interpreted as pass-local runtime, Starshine should be no slower than `1 / 0.95 ~= 1.0526x` Binaryen time.

Using the refreshed `1120` Binaryen 2000-function median of `1.28922ms`, the current fixture target is therefore approximately `<=1.357ms` Starshine median.

This supersedes the older `<=2x` disposition threshold from `1116` for future HSO-I and HSO-J decisions unless the user explicitly clarifies otherwise. The best committed Starshine median remains `1131`'s `6.972ms`, about `5.41x` the `1120` Binaryen median and far above the new target.

## Interpretation

HSO-I remains open. HSO-J final closeout must not be declared complete merely by satisfying the old `<=2.57844ms` target; it now requires meeting the stricter speed-parity target, superseding the fixture with stronger artifact/neighborhood evidence plus reopening criteria and explicit user approval, or getting explicit user approval to carry the measured speed gap.

## Validation

Docs/status-only update. No executable validation was required.
