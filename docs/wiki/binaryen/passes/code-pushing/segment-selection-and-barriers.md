---
kind: concept
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md
  - ../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md
  - ../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md
  - ../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md
  - ../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md
  - ../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md
  - ../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md
  - ../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md
  - ../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md
  - ../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md
  - ../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md
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

The current source-backed Binaryen frame after the 2026-06-20 `version_130` refresh is:

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

Current Starshine is stricter than Binaryen's full `isPushable(...)` model: it moves pure nontrapping values plus guarded `global.get` and local-copy setup shapes only when local/effect barriers prove the delayed computation safe. The first segment-movement consumers keep this strict gate: single-set movement covers ordinary void `if`, dropped value-`if`, and narrow `br_if`, while ordered multi-set movement is currently limited to adjacent local-independent sets before ordinary void `if`, dropped value-`if`, and narrow void-block-target `br_if` push points, direct local-copy sets whose source locals are not rewritten by the crossed push point, and local-independent sets separated only by `nop` roots.

## Barrier 3: intervening effects must not invalidate or order before the value

`optimizeSegment(...)` accumulates effects between source and destination and refuses movement when the candidate value's effects are ordered before the cumulative intervening effects. This is the current `version_130` source wording; older notes that describe only invalidation are now incomplete.

Beginner rule: even if the value looks simple, it cannot cross a sibling that can make computing it later observe a different world or violate ordered-before constraints.

Advanced rule: future Starshine widening should keep extending the local effect-ordering / effect-invalidation predicate before admitting broader value families.

## Barrier 4: push points are specific

Binaryen's push points include:

- `if`,
- `switch`,
- conditional branch forms,
- and dropped wrappers around push points.

A random later expression is not automatically a destination. The first Starshine segment inventory discovers selected push points: ordinary `if`, dropped `if`, locally representable conditional branch roots, and switch/`br_table` roots. Current mutating consumers accept ordinary void `if`, dropped value-`if` wrappers, and a narrow no-branch-value `br_if` to a void block label, moving the set after the push-point root when all local reads are same-region suffix reads. The ordinary void-`if`, dropped value-`if`, and narrow `br_if` paths also have bounded ordered multi-set subcases for adjacent local-independent SFA sets, direct local-copy SFA sets, and local-independent SFA sets separated only by `nop` roots, preserving source order. Switch/`br_table`, `br_on_*`, loop-target branches, branch-value conditional branches, arbitrary non-adjacent windows beyond `nop`, local-copy dependency chains, and broader multi-set movement outside those narrow subcases remain discovery-only or unimplemented.

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
- `code-pushing-atomics.wast` proves GC reads can move past shared atomic loads but not shared atomic stores.
- EH can make movement observable through exceptional paths.

Use the official `version_130` `code-pushing_ignore-implicit-traps.wast`, `code-pushing_tnh.wast`, `code-pushing-gc.wast`, `code-pushing-atomics.wast`, `code-pushing-eh.wast`, and `code-pushing-eh-legacy.wast` files as the proof surface for these families.

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

1. build on the initial SFA and segment-window diagnostic inventory in [`0808`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md), the first ordinary-void-`if` movement slice in [`0809`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md), the first dropped-`if` movement slice in [`0811`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md), the first narrow `br_if` movement slice in [`0812`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md), the first ordinary-`if` ordered multi-set slice in [`0813`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md), the dropped-`if` ordered multi-set slice in [`0814`](../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md), the `br_if` ordered multi-set slice in [`0815`](../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md), the direct local-copy multi-set slice in [`0816`](../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md), and the `nop`-separated multi-set slice in [`0817`](../../../raw/research/0817-2026-06-20-code-pushing-nop-window-multi-set-movement.md);
2. keep one-arm `if` sinking separate from generic segment movement;
3. preserve order among multiple moved sets; the first Starshine slices cover adjacent local-independent sets before ordinary void `if`, dropped value-`if`, and narrow void-block-target `br_if` push points, plus direct local-copy and `nop`-separated subcases with explicit boundaries;
4. extend effect-ordering / effect-invalidation before moving broader value families;
5. keep trap options explicit;
6. test GC and EH as first-class boundaries;
7. document Starshine-local helper families separately from upstream Binaryen behavior.

## Sources

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md`](../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md)
- [`../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md`](../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md)
- [`../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md`](../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md)
- [`../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md)
- [`../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md)
- [`../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md)
- [`../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md)
- [`../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md)
- [`../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/research/0807-2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md`](../../../raw/research/0454-2026-05-05-code-pushing-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md)
- [`../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md`](../../../raw/research/0413-2026-04-26-code-pushing-current-main-port-readiness.md)
- Binaryen `version_130` `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/CodePushing.cpp>
- Binaryen current-main `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
- Current Starshine owner: [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
