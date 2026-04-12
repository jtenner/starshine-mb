---
kind: entity
status: working
last_reviewed: 2026-04-12
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../raw/research/0079-2026-04-12-code-pushing-one-off-alias-tail-prefix.md
  - ../../../../../agent-todo.md
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/ir/hot_lower_live_repro_test.mbt
related:
  - ./wat-shapes.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ./artifact-frontiers.md
  - ./validation-and-fuzzing.md
  - ./performance-and-runtime.md
  - ../../no-dwarf-default-optimize-path.md
---

# `code-pushing`

## Role

- `code-pushing` is an active hot pass in Starshine's Binaryen namespace.
- It is a local-motion pass, not a generic simplifier. Its job is to move certain
  eligible `local.set` roots closer to the conditional structure that justifies
  them.
- The pass runs on one lifted [`HotFunc`](../../../../../src/ir/README.md) at a
  time, but parity is still constrained by whether the rewritten HOT shape lowers
  back to valid Wasm with the same result and branch structure Binaryen keeps.

## Current Summary

- Recognize Binaryen-style pushable locals using a pass-local SFA analysis rather
  than the stronger SSA overlay.
- Reorder eligible `local.set` roots inside one region so they sit immediately
  before a recognized push point such as `if`, `br_if`, or `br_on_*`.
- Sink a `local.set` into exactly one `if` arm when only one arm needs that
  value and the opposite arm does not create a later-use hazard.
- Extract some `local.set` roots from dropped result carriers so the lifted HOT
  form can still reach the same post-`if` placement Binaryen achieves on its AST.
- Stay conservative around non-void carriers and parent-escape payload rewrites.
  Result-producing one-arm `if` sinks, same-region reorders past result-
  producing `if` pushpoints, plain one-off alias tails without an earlier
  explicit-exit carrier, and crossed-gap carrier aliases where the kept
  condition-set does not alias that same carried local are now part of the
  admitted Binaryen-matched surface again, but the broader owner-sensitive
  non-void families are still where the hard lowering risk lives.

## Source Scope

- This folder is grounded in the repo's canonical `0073` research doc plus the
  later in-tree implementation, tests, backlog notes, and changelog checkpoints.
- The upstream algorithm notes here are therefore anchored to the repo's direct
  `Binaryen version_125` study, not to a fresh `version_129` reread.
- The Starshine-side status and frontier notes are newer than the original
  research doc because they include all landed parity slices through
  `2026-04-11`.

## Page Map

- [`./wat-shapes.md`](./wat-shapes.md) - Exact WAT families that do and do not
  transform today, including the dropped-carrier extraction shapes that matter on
  the debug artifact.
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - The upstream
  `code-pushing` algorithm as studied in `0073`: candidate discovery, push-point
  recognition, segment motion, one-arm `if` sinking, and deliberate bailouts.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) - The
  current in-tree HOT implementation strategy, including the actual helper groups,
  mutation phases, and the extra lowering-validity fences that Binaryen does not
  need in the same form.
- [`./parity.md`](./parity.md) - The current Binaryen parity state for explicit
  `code-pushing`, including landed slices and the still-open direct-artifact gap.
- [`./artifact-frontiers.md`](./artifact-frontiers.md) - Detailed record of the
  current and former debug-artifact mismatch families, what each reducer proved,
  and which family is the real blocker now.
- [`./validation-and-fuzzing.md`](./validation-and-fuzzing.md) - The exact test,
  compare-pass, HOT-lowering, and artifact-replay workflow used to advance this
  pass safely.
- [`./performance-and-runtime.md`](./performance-and-runtime.md) - Runtime
  expectations, historical timing checkpoints, current hot spots, and the
  secondary performance work that remains after correctness.

## Current Maintenance Rule

- Treat this folder as the canonical home for future `code-pushing` work.
- Keep three layers separate:
  - exact transformed WAT shapes
  - the Binaryen strategy being mimicked
  - the Starshine HOT strategy actually used to realize those shapes
- Put future artifact family notes, compare evidence, and performance findings in
  the dedicated subpages here rather than back into one large numbered doc.
