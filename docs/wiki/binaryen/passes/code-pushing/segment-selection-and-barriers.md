---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `code-pushing` Segment Selection And Barriers

## Corrected framing

The current source-backed Binaryen frame is:

- `LocalAnalyzer` finds single-first-assignment locals;
- `Pusher` scans block-root segments;
- `isPushable(...)` decides whether a `local.set` root can move;
- `isPushPoint(...)` decides where a segment can push toward;
- `optimizeSegment(...)` performs ordered movement;
- `optimizeIntoIf(...)` handles arm-specific sinking.

This page therefore restores segment-selection terminology, but keeps it precise: it is about block-local windows of SFA `local.set` roots, not arbitrary CFG sinking or two-arm expression cloning.

## Barrier 1: the local must be SFA-like

Binaryen is local-write centered. A candidate usually fails before effect analysis if the local is not a safe temporary.

Bailouts include:

- the local is a parameter;
- more than one set/tee-like write exists;
- a get appears before the set;
- the candidate root is not a suitable `local.set`;
- not all gets can be accounted for by the destination region.

Starshine currently approximates a tiny part of this with whole-root get/write counters for the local next to an `if`.

## Barrier 2: the value must be movable

`isPushable(...)` checks the set's value effects. Values with unremovable side effects do not move. Values with removable side effects may move only when the segment proof keeps behavior valid.

Current Starshine is stricter: it only moves `Const`, `RefNull`, and `RefFunc` values for the arm-sinking family.

## Barrier 3: intervening effects must not invalidate the value

`optimizeSegment(...)` accumulates effects between source and destination and refuses movement when those effects invalidate the candidate value's effects.

Beginner rule: even if the value looks simple, it cannot cross a sibling that can make computing it later observe a different world.

Advanced rule: future Starshine parity needs a local effect-invalidation predicate before it can safely widen beyond const-like values.

## Barrier 4: push points are specific

Binaryen's push points include:

- `if`,
- `switch`,
- conditional branch forms,
- and dropped wrappers around push points.

A random later expression is not automatically a destination. This is why the first future Starshine segment slice should discover push points without rewriting.

## Barrier 5: `if` arm sinking needs one consuming arm

For `if` sinking, the moved set goes into the arm that reads the local. The other arm must not need the local. Reads after the `if` are only safe when control-flow facts, such as an unreachable non-consuming arm, preserve availability.

This is the important distinction from stale two-live-arm duplication examples:

- one consuming arm: source-backed family;
- two reachable consuming arms: not the default proof;
- post-if read with fallthrough from the non-consuming arm: bailout unless another proof exists.

## Trap, GC, and EH boundaries

Trap timing and exceptional control are correctness boundaries.

- Default trap policy is stricter than ignore-implicit-traps / TNH modes.
- GC/reference expressions are allowed only when the same effect and use proof succeeds.
- EH can make movement observable through exceptional paths.

Use the official `code-pushing_ignore-implicit-traps.wast`, `code-pushing_tnh.wast`, `code-pushing-gc.wast`, and `code-pushing-eh.wast` files as the proof surface for these families.

## Starshine-local extra boundary

Current Starshine also has a typed/dead-block flattening helper in `src/passes/code_pushing.mbt`.
That local family is guarded by:

- neighboring `unreachable` or leading-unreachable context;
- a single body `unreachable` at the beginning or end;
- no nested branch-bearing roots in moved body entries;
- no multivalue non-unreachable moved roots.

Do not confuse that with upstream Binaryen's `CodePushing.cpp` strategy. It is a local repair/cleanup family currently bundled under the active pass.

## Porting checklist

A future broader Starshine port should preserve these rules before widening motion:

1. implement or test an SFA-local classifier;
2. discover block-local candidate segments and push points;
3. keep one-arm `if` sinking separate from generic segment movement;
4. preserve order among multiple moved sets;
5. implement effect-invalidation before moving non-const-like values;
6. keep trap options explicit;
7. test GC and EH as first-class boundaries;
8. document Starshine-local helper families separately from upstream Binaryen behavior.

## Sources

- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- Binaryen current-main `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
- Current Starshine owner: [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
