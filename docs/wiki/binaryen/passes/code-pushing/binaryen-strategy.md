---
kind: concept
status: working
last_reviewed: 2026-04-11
sources:
  - ../../../../0073-2026-04-02-code-pushing-binaryen-plan.md
  - ../../../raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `code-pushing` Strategy

## Upstream Source Rule

- The repo's canonical Binaryen study for this pass is still
  [`0073`](../../../../0073-2026-04-02-code-pushing-binaryen-plan.md).
- That study originally read `Binaryen version_125`, specifically:
  - `src/passes/CodePushing.cpp`
  - the default function-pipeline placement in `src/passes/pass.cpp`
  - the nested optimizing rerun helper in `src/passes/opt-utils.h`
  - the pass-specific test corpus for plain control, trap-relaxing, GC, and EH
    cases
- A direct `version_129` reread is now also filed in
  [`0076`](../../../raw/research/0076-2026-04-11-code-pushing-func-127-binaryen-noop.md).
- The important update from that reread is negative, not additive:
  Binaryen still operates as a flat block-list `local.set` mover plus one-arm
  `if` sinker. It still does not model Starshine-style explicit-exit carrier
  summaries or local-synthesis rules, which is why Binaryen leaves the current
  `parse__config__json` / printed `func $127` artifact frontier unchanged.

## Pipeline Placement

- Binaryen inserts `code-pushing` into the default function pipeline when
  `optimizeLevel >= 2 || shrinkLevel >= 2`.
- Its top-level slot is after the early `precompute` /
  `precompute-propagate` work and before `tuple-optimization`.
- Because the pass lives in Binaryen's default function-optimization helper, it
  also reappears inside optimizing nested pipelines such as:
  - `dae-optimizing`
  - `inlining-optimizing`
  - `simplify-globals-optimizing`
- The important consequence is that Binaryen does not rely on one `code-pushing`
  execution to finish every follow-on cleanup. It expects the surrounding
  optimize pipeline to revisit the function later.

## Candidate Discovery

- Binaryen does not start from full SSA.
- It uses a deliberately weaker "SFA" notion that is specific to this pass:
  - not a parameter
  - exactly one `local.set`
  - no `local.get` before that set in postorder
- It also tracks the total and "seen so far" get counts so that, when visiting a
  block in postorder, it can tell whether the local has any use left after the
  current block.
- Only roots whose destination local satisfies this shape are even considered for
  motion.

## Recognized Push Points

- Binaryen only tries to move code toward specific conditional boundaries.
- The recognized push points are:
  - `if`
  - conditional `break` / `br_if`
  - `br_on_null`
  - `br_on_non_null`
  - `br_on_cast`
  - `br_on_cast_fail`
  - a `drop` wrapped around one of those
- This is a deliberate scope choice. The pass is not a general "push through any
  pure root" framework.

## Segment Rewrite Strategy

- Binaryen's main worker is the segment-level backward scan described in `0073` as
  `optimizeSegment`.
- Inside one block list it finds the next push point, then scans roots backward
  from immediately before that push point.
- The accumulated barrier starts with the push point's effects and expands as the
  scan crosses:
  - non-pushed roots
  - earlier pushables that could not move
  - any already-determined barrier summaries
- The crucial subtlety is that Binaryen ignores control-flow-transfer effects when
  merging that barrier. The reasoning is that if control exits early, the moved
  local has already been proven dead on that path.
- Safe movable roots are removed from their old positions and reinserted
  immediately before the push point while preserving original order.

## `if`-Specific Sinking Strategy

- When the push point is an `if`, Binaryen first tries a more specific rewrite
  usually described as `optimizeIntoIf`.
- The goal is not merely to move the set past the `if`, but to place it inside
  exactly one arm.
- The sink is permitted only when:
  - one arm reads the local
  - the opposite arm does not read the local
  - there is no later read after the `if`, unless the non-target arm is
    unreachable
  - the set is not `unreachable`-typed
- On success, Binaryen prepends the set to the chosen arm and leaves a `nop` in
  the old position.
- It never duplicates the set into both arms.

## Side-Effect And Trap Policy

- Binaryen only moves sets whose value subtree has no unremovable side effects.
- Ordinary calls, writes, throws, and control transfer are not removable.
- Traps are removable only under Binaryen's trap-relaxing modes such as:
  - `--ignore-implicit-traps`
  - `-tnh`
- That is why the positive call testcase in Binaryen's own corpus uses
  `call.without.effects`, while effectful calls still block motion.

## Important Binaryen Bailouts

- No duplication across both `if` arms.
- No push of arbitrary non-`local.set` roots.
- No special exception-handling algorithm beyond what Binaryen's effect analysis
  already models.
- No immediate recursive re-run after one successful sink. The pass does its
  current scan and leaves later cleanup to later optimization cycles.
- No attempt to solve local-typing fallout inside the pass itself. The GC testcase
  is only safe because Binaryen's surrounding pass machinery can repair
  non-nullable-local typing afterwards.

## What Matters For Starshine Parity

- Matching Binaryen here is not just about "find a later `if` and move the set."
- Parity depends on simultaneously matching:
  - SFA local eligibility
  - recognized push points
  - one-arm sink conditions
  - order preservation among multiple moved roots
  - the barrier rule that ignores control transfer but still respects value,
    local, global, trap, and throw effects
- The pass is therefore closer to a small, dedicated motion algorithm than to a
  generic IR scheduler.

## What Binaryen Does Not Give Us For Free

- Binaryen's AST form does not map one-to-one onto Starshine's lifted HOT result
  carriers.
- The upstream algorithm explains which motions are semantically intended, but it
  does not by itself solve the extra lowering-validity problems Starshine hits in
  non-void carrier regions.
- That is why this folder keeps the upstream strategy separate from the HOT
  realization strategy in [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).

## Sources

- Canonical repo research doc:
  [`../../../../0073-2026-04-02-code-pushing-binaryen-plan.md`](../../../../0073-2026-04-02-code-pushing-binaryen-plan.md)
- Pipeline placement context:
  [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
