---
kind: concept
status: supported
last_reviewed: 2026-06-25
sources:
  - ../../../raw/research/0865-2026-06-25-code-pushing-global-set-movement.md
  - ../../../raw/research/0864-2026-06-25-code-pushing-try-table-multi-catch-boundary.md
  - ../../../raw/research/0863-2026-06-25-code-pushing-try-table-catch-payload-boundaries.md
  - ../../../raw/research/0862-2026-06-25-code-pushing-try-table-catch-all-ref-boundary.md
  - ../../../raw/research/0861-2026-06-25-code-pushing-rethrow-boundary.md
  - ../../../raw/research/0860-2026-06-25-code-pushing-payload-throw-boundary.md
  - ../../../raw/research/0859-2026-06-25-code-pushing-legacy-try-lowered-movement.md
  - ../../../raw/research/0858-2026-06-25-code-pushing-try-table-boundary.md
  - ../../../raw/research/0857-2026-06-25-code-pushing-plain-throw-boundary.md
  - ../../../raw/research/0855-2026-06-25-code-pushing-throw-ref-movement.md
  - ../../../raw/research/0850-2026-06-25-code-pushing-call-barrier.md
  - ../../../raw/research/0848-2026-06-25-code-pushing-multilabel-br-table-boundary.md
  - ../../../raw/research/0829-2026-06-24-code-pushing-br-on-cast-fail-movement.md
  - ../../../raw/research/0828-2026-06-24-code-pushing-br-on-cast-movement.md
  - ../../../raw/research/0826-2026-06-24-code-pushing-br-on-null-movement.md
  - ../../../raw/research/0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md
  - ../../../raw/research/0824-2026-06-24-code-pushing-branch-value-br-if.md
  - ../../../raw/research/0823-2026-06-21-code-pushing-atomics-gc-boundary.md
  - ../../../raw/research/0821-2026-06-21-code-pushing-global-get-window-multi-set-movement.md
  - ../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md
  - ../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md
  - ../../../raw/research/0818-2026-06-20-code-pushing-loop-br-if-movement.md
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

Current Starshine is stricter than Binaryen's full `isPushable(...)` model: it moves pure nontrapping values plus guarded `global.get`, local-copy setup, and a narrow non-null `struct.get` heap-read shape only when local/effect barriers prove the delayed computation safe; [`0865`](../../../raw/research/0865-2026-06-25-code-pushing-global-set-movement.md) records that pure non-global SFA values move across an intervening `global.set` before a later `br_if`, while guarded `global.get` movement remains global-state-sensitive; as of [`0850`](../../../raw/research/0850-2026-06-25-code-pushing-call-barrier.md), single-set segment movement treats intervening calls as hard ordered barriers before a later push point, [`0855`](../../../raw/research/0855-2026-06-25-code-pushing-throw-ref-movement.md) shows a non-fallthrough `throw_ref` root is a Binaryen-positive pure-value movement case before a later `br_if`, [`0857`](../../../raw/research/0857-2026-06-25-code-pushing-plain-throw-boundary.md) keeps no-payload tag-based `throw` roots as Binaryen-stationary segment-order barriers, [`0860`](../../../raw/research/0860-2026-06-25-code-pushing-payload-throw-boundary.md) extends that stationary boundary to a payload-bearing tag-based `throw`, [`0858`](../../../raw/research/0858-2026-06-25-code-pushing-try-table-boundary.md) keeps reduced `try_table` roots as Binaryen-stationary EH barriers, [`0862`](../../../raw/research/0862-2026-06-25-code-pushing-try-table-catch-all-ref-boundary.md) extends that stationary boundary to a reference-carrying `catch_all_ref` target, [`0863`](../../../raw/research/0863-2026-06-25-code-pushing-try-table-catch-payload-boundaries.md) keeps tag-payload `catch` and payload-plus-reference `catch_ref` handlers stationary, [`0864`](../../../raw/research/0864-2026-06-25-code-pushing-try-table-multi-catch-boundary.md) keeps a reduced multi-catch `try_table` stationary, [`0859`](../../../raw/research/0859-2026-06-25-code-pushing-legacy-try-lowered-movement.md) records that local Binaryen v130 moves a pure set after no-rethrow legacy `try`/`catch` before a later `br_if` while Starshine's WAT fixture currently observes that movement through a try-lowered HOT block rather than native `HotOp::Try` coverage, and [`0861`](../../../raw/research/0861-2026-06-25-code-pushing-rethrow-boundary.md) keeps rethrow-containing HOT regions stationary before a later push point. The first segment-movement consumers keep this strict gate: single-set movement covers ordinary void `if`, dropped value-`if`, narrow no-branch-value block-/loop-target `br_if`, dropped void-label `br_on_null`, and value-block-target `br_if` with one branch payload, while ordered multi-set movement is currently limited to adjacent local-independent sets before ordinary void `if`, dropped value-`if`, narrow no-branch-value void-block-target / void-loop-target `br_if`, dropped void-label `br_on_null`, and value-block-target `br_if` push points, direct local-copy sets whose source locals are not rewritten by the crossed push point, local-independent sets separated only by `nop`, `drop(const)`, or `drop(local.get)` roots, and a bounded `drop(global.get)` separator family for ordinary void `if` / dropped value-`if` only.

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

A random later expression is not automatically a destination. The first Starshine segment inventory discovers selected push points: ordinary `if`, dropped `if`, locally representable conditional branch roots, and switch/`br_table` roots. Current mutating consumers accept ordinary void `if`, dropped value-`if` wrappers, a narrow no-branch-value `br_if` to a void block or loop label, a dropped `br_on_null` to a void block/loop label, a `br_on_non_null` to a one-result block label, a dropped `br_on_cast` to a one-result block label, a dropped `br_on_cast_fail` to a one-result block label, and a branch-value `br_if` to a value block label, moving the set after the push-point root when all local reads are same-region / same-loop-body suffix reads and the branch guard/payload does not read the moved local. The ordinary void-`if`, dropped value-`if`, narrow no-branch-value `br_if`, dropped void-label `br_on_null`, one-result-block `br_on_non_null`, dropped one-result-block `br_on_cast`, dropped one-result-block `br_on_cast_fail`, and adjacent local-independent value-block-target `br_if` paths also have bounded ordered multi-set subcases preserving source order. A `drop(global.get)` separator is currently admitted only for ordinary void `if` and dropped value-`if`; Binaryen v130 probes kept the same window stationary before block-/loop-target `br_if`, and Starshine now has a boundary test for that shape. Simple no-branch-value `br_table` block-exit windows, one value-carrying result-block `br_table`, and one nested-block multi-label `br_table` are now protected as Binaryen-stationary no-mutation boundaries. Pure non-global values can cross an intervening `global.set` before a later `br_if` after [`0865`](../../../raw/research/0865-2026-06-25-code-pushing-global-set-movement.md); this is a positive movement case, not a license for values that read global state to cross global mutation. Intervening calls before later push points are also protected as Binaryen-stationary ordered barriers, the reduced pure-value `throw_ref` / later-`br_if` shape moves after [`0855`](../../../raw/research/0855-2026-06-25-code-pushing-throw-ref-movement.md), tag-based `throw` before a later `br_if` remains stationary for both no-payload [`0857`](../../../raw/research/0857-2026-06-25-code-pushing-plain-throw-boundary.md) and payload-bearing [`0860`](../../../raw/research/0860-2026-06-25-code-pushing-payload-throw-boundary.md) probes, a reduced `try_table` before later `br_if` remains stationary after [`0858`](../../../raw/research/0858-2026-06-25-code-pushing-try-table-boundary.md), reference-carrying `catch_all_ref`, tag-payload `catch`, payload-plus-reference `catch_ref`, and reduced multi-catch `try_table` forms remain stationary after [`0862`](../../../raw/research/0862-2026-06-25-code-pushing-try-table-catch-all-ref-boundary.md), [`0863`](../../../raw/research/0863-2026-06-25-code-pushing-try-table-catch-payload-boundaries.md), and [`0864`](../../../raw/research/0864-2026-06-25-code-pushing-try-table-multi-catch-boundary.md), a no-rethrow legacy `try`/`catch` WAT fixture moves through Starshine's current try-lowered block path after [`0859`](../../../raw/research/0859-2026-06-25-code-pushing-legacy-try-lowered-movement.md), and a rethrow-containing HOT region remains stationary after [`0861`](../../../raw/research/0861-2026-06-25-code-pushing-rethrow-boundary.md). Other switch/`br_table` shapes, broader EH forms, broader `br_on_*` forms (`br_on_non_null`, `br_on_cast`, `br_on_cast_fail`, branch-value/reference-payload variants), broader branch-value conditional branches, arbitrary non-adjacent windows beyond `nop` / `drop(const)` / `drop(local.get)` / bounded ordinary-/dropped-`if` `drop(global.get)`, local-copy dependency chains, and broader multi-set movement outside those narrow subcases remain discovery-only or unimplemented.

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
- `code-pushing-atomics.wast` proves non-null GC `struct.get` reads can move past shared atomic loads but not shared atomic stores, both into the sole consuming `if` arm and across a segment push point for suffix use.
- Starshine now mirrors that atomics/GC family with HOT fixtures because its WAT surface does not yet parse the official shared-GC syntax; the implementation admits only non-null `struct.get` from a `local.get` source and blocks intervening memory writes.
- EH can make movement observable through exceptional paths. The first reduced EH refinements are narrow: Binaryen v130 moves a pure SFA set after a later `br_if` when the intervening root is non-fallthrough `throw_ref`; keeps the set before both no-payload and payload-bearing tag-based `throw` probes, before a `try_table` with a catch target, before reference-carrying `catch_all_ref`, tag-payload `catch`, payload-plus-reference `catch_ref`, and reduced multi-catch `try_table` forms, and before a rethrow-containing legacy try/catch; and moves the set after a no-rethrow legacy `try`/`catch` in the reduced WAT probe, which Starshine currently covers only through try-lowered block movement. Native HOT `Try`, richer `try_table` forms beyond the current catch-all/catch-all-ref probes, caught payload/reference forms, and richer legacy try surfaces remain open.

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

1. build on the initial SFA and segment-window diagnostic inventory in [`0808`](../../../raw/research/0808-2026-06-20-code-pushing-segment-inventory.md), the first ordinary-void-`if` movement slice in [`0809`](../../../raw/research/0809-2026-06-20-code-pushing-if-segment-movement.md), the first dropped-`if` movement slice in [`0811`](../../../raw/research/0811-2026-06-20-code-pushing-dropped-if-segment-movement.md), the first narrow `br_if` movement slice in [`0812`](../../../raw/research/0812-2026-06-20-code-pushing-br-if-segment-movement.md), the first ordinary-`if` ordered multi-set slice in [`0813`](../../../raw/research/0813-2026-06-20-code-pushing-ordered-multi-set-movement.md), the dropped-`if` ordered multi-set slice in [`0814`](../../../raw/research/0814-2026-06-20-code-pushing-dropped-if-multi-set-movement.md), the `br_if` ordered multi-set slice in [`0815`](../../../raw/research/0815-2026-06-20-code-pushing-br-if-multi-set-movement.md), the direct local-copy multi-set slice in [`0816`](../../../raw/research/0816-2026-06-20-code-pushing-local-copy-multi-set-movement.md), the `nop`-separated multi-set slice in [`0817`](../../../raw/research/0817-2026-06-20-code-pushing-nop-window-multi-set-movement.md), the loop-target `br_if` slice in [`0818`](../../../raw/research/0818-2026-06-20-code-pushing-loop-br-if-movement.md), the `drop(const)` separator slice in [`0819`](../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md), and the `drop(local.get)` separator slice in [`0820`](../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md);
2. keep one-arm `if` sinking separate from generic segment movement;
3. preserve order among multiple moved sets; the first Starshine slices cover adjacent local-independent sets before ordinary void `if`, dropped value-`if`, narrow void-block-target `br_if`, and dropped void-label `br_on_null`, one-result-block `br_on_non_null`, and dropped one-result-block `br_on_cast`, and dropped one-result-block `br_on_cast_fail` push points, plus direct local-copy, `nop`-separated, `drop(const)`-separated, `drop(local.get)`-separated, and bounded ordinary-/dropped-`if` `drop(global.get)`-separated subcases with explicit boundaries;
4. extend effect-ordering / effect-invalidation before moving broader value families;
5. keep trap options explicit;
6. test GC, atomics, and EH as first-class boundaries;
7. document Starshine-local helper families separately from upstream Binaryen behavior.

## Sources

- [`../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md`](../../../raw/binaryen/2026-06-20-code-pushing-version-130-source-lit-refresh.md)
- [`../../../raw/research/0829-2026-06-24-code-pushing-br-on-cast-fail-movement.md`](../../../raw/research/0829-2026-06-24-code-pushing-br-on-cast-fail-movement.md)
- [`../../../raw/research/0828-2026-06-24-code-pushing-br-on-cast-movement.md`](../../../raw/research/0828-2026-06-24-code-pushing-br-on-cast-movement.md)
- [`../../../raw/research/0826-2026-06-24-code-pushing-br-on-null-movement.md`](../../../raw/research/0826-2026-06-24-code-pushing-br-on-null-movement.md)
- [`../../../raw/research/0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md`](../../../raw/research/0825-2026-06-24-code-pushing-branch-value-multiset-br-if.md)
- [`../../../raw/research/0824-2026-06-24-code-pushing-branch-value-br-if.md`](../../../raw/research/0824-2026-06-24-code-pushing-branch-value-br-if.md)
- [`../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md`](../../../raw/research/0820-2026-06-21-code-pushing-local-get-window-multi-set-movement.md)
- [`../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md`](../../../raw/research/0819-2026-06-21-code-pushing-drop-window-multi-set-movement.md)
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
