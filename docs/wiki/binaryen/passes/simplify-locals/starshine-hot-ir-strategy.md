---
kind: concept
status: working
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ../../../ir2/architecture-rules.md
  - ../../../ir2/local-ssa-policy.md
---

# `simplify-locals` Starshine Strategy

## Durable Conclusions

- `simplify-locals` must stay inside the existing `HotFunc` contract; the pass should not introduce a second owned optimizer IR just to mirror Binaryen's AST walker.
- The worktree strategy is deliberately no-structure first: close the Binaryen parity gap for sink, tee, overwrite, equivalent-copy, and dead-set cleanup before landing block, `if`, or loop result rewrites.
- HOT-IR mutations should use node ids, region references, and public control-result helpers instead of Binaryen's trailing-`nop` retry pattern that exists to keep `Expression**` pointers stable.
- Any Binaryen-style mode split should stay an internal implementation detail until public extra pass ids are proven necessary by parity tooling or pipeline composition.

## Current In-Tree Shape

- The exact lifted pass in [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt) still carries the core dead-def and local-equivalence logic.
- The pass-manager raw lane in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) carries the current no-structure fallback and validator-heavy parity rewrites used on large debug-artifact functions that are still expensive or unsafe to lift exactly.
- Focused regressions live in [`../../../../../src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt) and the pass-manager test surfaces.

## Open Maintenance Rule

- Keep this page as the live explanation of how `simplify-locals` is being ported onto HOT IR.
- File future structure-lifting decisions, raw-lane retirement rules, and Binaryen parity boundaries here or in sibling simplify-locals pages instead of generic optimizer notes.

## Sources

- Archived research note: [`../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md`](../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md)
- Implementation: [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- Focused tests: [`../../../../../src/passes/simplify_locals_test.mbt`](../../../../../src/passes/simplify_locals_test.mbt)
- Raw lane: [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
