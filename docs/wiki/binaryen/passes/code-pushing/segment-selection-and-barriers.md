---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `code-pushing` Movement Boundaries

## Corrected framing

This page used to teach `code-pushing` as a target-segment pass with `BranchSeeker`, `Pusher`, two-live-arm `if` duplication, and profitability scoring.
The 2026-04-25 source correction removes that framing.

The real reviewed Binaryen `version_129` surface is easier to follow:

- `visitBlock(...)` scans one block's children.
- `optimizeIntoIf(...)` handles the one-unreachable-arm `if` case.
- `tryPush(...)` moves one earlier root near a later use.
- `canPushThrough(...)` decides whether intervening expressions are safe to cross.

## The two movement families

### Family A: one-unreachable-arm `if` sinking

When an `if` has one unreachable arm, Binaryen may move a bounded prefix of preceding block roots into the reachable arm.

Why this is legal only sometimes:

- moving the prefix must not change whether it executes,
- the prefix must come after the previous fallthrough boundary,
- the moved roots must be safe to cross intervening expressions,
- and refinalization must repair the changed `if` body.

This is not the same as duplicating pure work into two live arms.
It is closer to postponing work into the only path that can continue.

### Family B: local sibling-root pushing

For an ordinary later expression, Binaryen can move an earlier block root to immediately before that later expression when:

- the later expression uses the earlier root,
- every intervening root passes `canPushThrough(...)`,
- moving the earlier root does not break root ordering or expression validity,
- and the changed region can be refinalized.

This family is still local to one block root list.
It is not arbitrary CFG sinking.

## `canPushThrough(...)` is the barrier checklist

When a candidate fails to move, assume `canPushThrough(...)` is the first place to inspect.

The predicate accounts for:

- direct uses of the moved expression,
- expressions without values,
- side effects,
- implicit-trap policy,
- traps-never-happen policy,
- `if` condition special cases,
- `call_without_effects`,
- function-reference use,
- `ref.func`,
- `ref.as_non_null`,
- cast exactness,
- nested child checks.

That makes the pass conservative in exactly the places beginners expect “pure code” to be enough.
Purity alone is not the full proof.

## Trap and option boundaries

Trap timing is a correctness boundary.

Under normal settings, a move that can change when a trap occurs is blocked.
The dedicated `ignore-implicit-traps` and traps-never-happen tests exist because Binaryen has options that intentionally relax parts of that rule.

For Starshine, this means future port work must decide whether to model the option-sensitive behavior or keep a stricter subset and document the mismatch.

## Calls and external effects

The stale page claimed calls categorically block the strict two-arm family.
The corrected source-backed statement is narrower:

- visible effects generally block motion,
- but `canPushThrough(...)` has specific handling for `call_without_effects`,
- and the exact legality is decided by the pass-local predicate, not by a blanket “all calls stop all motion” rule.

So examples should distinguish ordinary calls from explicitly effect-free calls.

## GC and reference boundaries

GC/reference operations participate when the same movement proof succeeds.
The source has explicit cases for reference-oriented operations, including `ref.func`, `ref.as_non_null`, casts, and nested children.

The safe teaching rule is:

- GC is not excluded,
- but GC does not bypass trap/effect/reference-use rules.

## EH boundary

The EH tests remain important because exceptional control can make movement observable.
The corrected page should not claim a separate EH segment planner.
Instead, teach EH as a region where `canPushThrough(...)`, expression refs, and refinalization must all keep control/value availability valid.

## Starshine-local extra boundary

Current Starshine also has a typed/dead-block flattening helper in `src/passes/code_pushing.mbt`.
That local family is guarded by:

- neighboring `unreachable` or leading-unreachable context,
- a single body `unreachable` at the beginning or end,
- no nested branch-bearing roots in moved body entries,
- no multivalue non-unreachable moved roots.

Do not confuse that with upstream Binaryen's `CodePushing.cpp` strategy.
It is a Starshine-local conservative repair/cleanup family currently bundled under the active pass.

## Porting checklist

A future broader Starshine port should preserve these rules before widening motion:

1. scan structured block root lists, not arbitrary CFG regions;
2. keep one-unreachable-arm `if` sinking separate from ordinary sibling-root pushing;
3. implement a faithful movement predicate before adding more positive shapes;
4. keep trap and option behavior explicit;
5. refinalize or locally retype after every structural mutation;
6. test GC and EH as first-class boundaries;
7. document Starshine-local helper families separately from upstream Binaryen behavior.

## Sources

- [`../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md)
- [`../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md)
- Binaryen `version_129` `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
- Current Starshine owner: [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
