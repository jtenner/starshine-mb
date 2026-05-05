---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
supersedes:
  - ../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md
---

# Binaryen `code-pushing` Strategy

## Current correction

The 2026-04-25 `code-pushing` correction went too far. It correctly warned against teaching arbitrary two-live-arm duplication, but it incorrectly said the reviewed upstream file did not use `Pusher`, segment selection, or local profitability-style movement.

The 2026-04-26 primary-source recheck found that official Binaryen `version_129` and current-main `src/passes/CodePushing.cpp` are in fact organized around:

- `LocalAnalyzer`,
- `Pusher`,
- `isPushable(...)`,
- `isPushPoint(...)`,
- `optimizeSegment(...)`,
- `optimizeIntoIf(...)`,
- cached `EffectAnalyzer` / `Properties` reasoning,
- and `doWalkFunction(...)` running the analysis plus the walker.

Use [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md) as the current source manifest. The older 2026-04-26 file stays as historical provenance for local-status notes, and the 2026-05-05 recheck kept the reviewed owner and scheduler surfaces unchanged on the teaching-relevant lines.

Primary sources:

- Binaryen current-main `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
- Binaryen `version_129` `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>

## High-level intent

Binaryen `code-pushing` moves single-assignment local writes later in structured code so the write executes closer to, or only on, the path that consumes it.

Beginner mental model:

1. identify locals with one assignment and no read before that assignment;
2. find block segments where eligible `local.set` roots can move forward;
3. stop at a push point such as an `if`, `switch`, or conditional branch;
4. move only values whose effects can be safely delayed across intervening effects;
5. for `if`, sink each moved set into the one arm that reads the local when the other arm does not need it.

Advanced mental model: the pass is a structured-block, SFA-local, effect-checked code-sinking pass. It is not whole-CFG sinking and it is not generic expression duplication into all arms.

## Phase table

| Phase | Upstream owner | What Binaryen does | Why it matters |
| --- | --- | --- | --- |
| Local analysis | `LocalAnalyzer` | Counts local gets/sets and marks single-first-assignment locals | Only SFA `local.set` roots become push candidates |
| Block candidate scan | `Pusher::visitBlock` | Walks a block root list and finds a segment from first pushable root to a later push point | The rewrite is segment-local, not arbitrary CFG motion |
| Candidate test | `isPushable(...)` | Requires an SFA local, all local gets seen, and a value without unremovable side effects | A pure-looking expression is not enough; the local-use proof matters |
| Push point test | `isPushPoint(...)` | Treats `if`, `switch`, conditional `br`, and dropped forms as places worth pushing toward | Explains why control-flow roots dominate the examples |
| Segment movement | `optimizeSegment(...)` | Moves eligible `local.set` roots forward when cumulative effects do not invalidate the value effects | This is the real segment-selection / movement-safety engine |
| Arm sinking | `optimizeIntoIf(...)` | Inserts a moved set into the one arm that reads the local when the other arm is safe | This is the distinctive `if` family and includes unreachable-arm post-use allowances |
| Type/effect repair | changed-path finalization and later optimizer cycles | Keeps expression types/effects coherent and leaves deeper opportunities to later cycles | Ports need validation and repeated-pass tests, not one-shot local rewrites only |

## `LocalAnalyzer`: why the pass is local-set centered

The pass is not looking for any expression that might be profitable to duplicate. It looks for `local.set` roots whose local behaves like a single-first-assignment temporary.

A local remains interesting when:

- it has exactly one write;
- it is not a parameter;
- no `local.get` appears before that write in the traversal used by the analysis;
- and the write is represented as a `local.set` candidate root.

This analysis is why examples should be written with explicit temporary locals. Direct arithmetic moved across arbitrary siblings is not the basic public contract.

## `Pusher`: segment selection and movement

`Pusher` walks blocks and tracks a candidate segment. Once it reaches a push point, `optimizeSegment(...)` tries to move eligible candidate sets forward.

Important constraints:

- movement preserves the relative order of pushed sets;
- candidate values cannot have unremovable side effects;
- cumulative effects between source and destination must not invalidate the candidate value's effects;
- deeper recursive opportunities are intentionally left for later optimizer cycles.

This restores the segment-selection language that the 2026-04-25 correction wrongly removed, but with a narrower source-backed meaning: a block-local segment of `local.set` roots, not arbitrary target-region cloning.

## `optimizeIntoIf(...)`: one-arm consumption, not generic duplication

The `if` case is still easy to over-teach. Binaryen does not need to duplicate a temporary into both live arms to be useful.

The source-backed positive family is:

- a moved local is read in exactly one arm;
- the other arm does not read the local;
- any reads after the `if` are safe, commonly because the non-consuming arm is unreachable;
- the moved `local.set` is inserted into the consuming arm.

So the corrected rule is: `code-pushing` can sink into an `if` arm, including unreachable-arm scenarios, but this should not be generalized into “duplicate pure work into both reachable arms.”

## Effects, traps, GC, and EH

The official lit suite shows why movement is not just syntactic:

- `code-pushing_ignore-implicit-traps.wast` and `code-pushing_tnh.wast` cover trap-policy differences.
- `code-pushing-gc.wast` proves reference/GC-shaped expressions are part of the proof surface.
- `code-pushing-eh.wast` keeps exceptional control in scope.

The core rule is effect invalidation: a candidate can move only when intervening effects do not make the delayed value computation observably different under the active options.

## Starshine implication

Starshine's current direct pass is a small, safe subset: const-like `local.set` sinking into one consuming `if` arm plus a local dead-block flattening helper. A faithful widening should first port the SFA-local analyzer and effect-checked segment model before adding broader `if`, branch, GC, or EH cases. See [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Sources

- [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- Binaryen current-main `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
- Binaryen `version_129` `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
