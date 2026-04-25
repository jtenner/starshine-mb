---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
  - ../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
supersedes:
  - ../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
---

# Binaryen `code-pushing` Strategy

## Correction summary

The current source-backed strategy is smaller than the older dossier taught.

Use [`../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md) as the current source manifest.
It corrects the 2026-04-22 interpretation that attributed these implementation pieces to Binaryen `CodePushing.cpp`:

- `BranchSeeker`
- `Pusher`
- generic target-segment sinking
- a local `benefit > cost` profitability gate
- general duplication into two reachable `if` arms

Those names and that profitability model are **not** present in the reviewed Binaryen `version_129` `src/passes/CodePushing.cpp`.
The real reviewed skeleton is:

- `visitBlock(...)`
- `optimizeIntoIf(...)`
- `canPushThrough(...)`
- `tryPush(...)`

Primary locations:

- `CodePushing.cpp` declaration and pass options: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L23-L62>
- block walk: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L66-L87>
- one-unreachable-arm `if` path: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L91-L233>
- movement-safety predicate: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L239-L315>
- generic local push: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp#L340-L395>

A 2026-04-25 current-`main` spot check found no teaching-relevant drift for those corrected points; the change here is a source-reading correction, not a new upstream algorithm.

## High-level intent

Binaryen `code-pushing` moves work later when doing so preserves behavior and makes the work closer to the point that needs it.

The beginner-safe mental model is:

- scan a block in source order,
- if a following `if` has one unreachable arm, try to sink the preceding fallthrough-preserved prefix into the reachable arm,
- otherwise, when a later expression uses an earlier expression, try to move that earlier expression directly before the use,
- only move across siblings that `canPushThrough(...)` says are safe.

It is not a general CFG code-sinking pass.
It does not search arbitrary disjoint regions.
It does not prove a global profitability model in the reviewed source.

## Phase table

| Phase | Source location | What Binaryen does | Why it matters |
| --- | --- | --- | --- |
| Pass setup | `CodePushing.cpp` `isFunctionParallel()` / `requiresExpressionRefs()` | Runs per function and depends on expression refs | The pass rewrites expression identity/order, so ports need stable expression-reference machinery |
| Block walk | `visitBlock(...)` | Walks `Block` list children by index; tries the `if` special case first; then scans earlier siblings for `tryPush(...)` | The pass is local to structured block child order, not arbitrary CFG search |
| One-arm `if` sinking | `optimizeIntoIf(...)` | If exactly one arm is unreachable, move a bounded prior region into the reachable arm when execution is preserved | This is the most distinctive upstream family and the main reason `into_if` tests exist |
| Movement check | `canPushThrough(...)` | Decides whether an expression may cross a later sibling under effect/trap/reference rules | This is the correctness engine; most surprising no-ops come from here |
| Generic local push | `tryPush(...)` | Moves an earlier root before a later expression that uses it when every intervening root is safe to cross | This is local sibling-root motion, not a broad segment duplicator |
| Type repair | `ReFinalize` calls in the changed paths | Recomputes affected expression types after mutation | Required because changing root order and `if` bodies can change surrounding expression types |

## `visitBlock(...)`: the real outer loop

The reviewed source walks each block body by index.
For each current child it:

1. tries `optimizeIntoIf(...)` when the current child is an `if`, then
2. scans earlier block roots and calls `tryPush(...)` to see whether one can move nearer this current expression.

That means the pass's normal search unit is:

- one structured `Block`,
- one later expression,
- one earlier root candidate,
- and the siblings between them.

This is why the wiki should not describe the pass as target-segment discovery through `BranchSeeker`.

## `optimizeIntoIf(...)`: one arm unreachable

The reviewed `optimizeIntoIf(...)` path is not a generic “push into both arms” rule.
It is centered on this shape:

- the current expression is an `if`,
- exactly one arm is unreachable,
- the moved expressions can be placed in the reachable arm without changing whether they execute,
- and the code between the source location and the `if` is safe to cross.

The important source idea is the `skipTo` / `limit` boundary.
The pass does not blindly move every earlier expression into the arm.
It finds the prior execution boundary and only considers the bounded block slice that can be moved while preserving whether the expressions run.

Practical consequence:

- one-unreachable-arm examples can optimize even when a naive two-live-arm duplication rule would be unsafe,
- but two-reachable-arm examples should not be documented as a guaranteed Binaryen `code-pushing` family unless a test/source location proves that exact rewrite.

## `canPushThrough(...)`: safety gate

`canPushThrough(curr, pushed)` is the main correctness gate.
It answers: can `pushed` move across `curr`?

Source-backed factors include:

- whether `curr` directly uses `pushed`,
- side effects and non-value expressions,
- traps-never-happen / ignore-implicit-traps option behavior,
- special handling for `if` conditions,
- `Call` with `call_without_effects`,
- `RefFunc` plus observed function-reference use,
- `RefAs` / `RefCast` details,
- constant-like and simple `local.get` / `struct.get` style expressions,
- recursive checks through children.

For Starshine, this is the important future-port surface: the local pass should grow by making this safety predicate more faithful before widening motion.

## `tryPush(...)`: local sibling motion

`tryPush(...)` is the generic local move:

- find a later expression that uses an earlier root,
- prove the earlier root can cross every intervening root,
- move it immediately before the later expression,
- preserve ordered root lists,
- refinalize the changed expression.

This can make local computations path- or use-local, but it is still root-order surgery inside one structured block.
It should not be explained as arbitrary CFG code sinking.

## Option-sensitive trap behavior

The dedicated lit files for `ignore-implicit-traps` and traps-never-happen remain important.
The corrected mental model is:

- a move that changes trap timing is normally blocked,
- Binaryen options can relax that barrier,
- `canPushThrough(...)` is where that relaxation is consulted.

That is why trap examples belong in the barrier page and shape catalog, even though the older profitability/segment explanation has been removed.

## Scheduler placement

`pass.cpp` still places `code-pushing` in the early function-optimization neighborhood before tuple/local cleanup in the no-DWARF path captured by the Starshine wiki.
The living no-DWARF page and tracker remain the local source for why this pass matters to Starshine's preset parity.

The nested-rerun story is still relevant as scheduler context, but the source-backed implementation of the pass itself is the smaller block-local strategy above.

## What the pass does not do

Do not teach Binaryen `version_129` `code-pushing` as:

- `BranchSeeker` / `Pusher`-owned segment sinking,
- local `benefit > cost` profitability,
- arbitrary two-live-arm `if` duplication,
- whole-CFG sinking,
- a substitute for `code-folding`, `tuple-optimization`, or `simplify-locals*`,
- Starshine's typed/dead-block flattening helper.

The last item is important: current Starshine has an extra conservative dead-block flattening family in its local `code_pushing.mbt`; that is a local helper shape, not a source-confirmed Binaryen `code-pushing` behavior.

## Sources

- [`../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md)
- [`../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md)
- Binaryen `version_129` source:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen current-main spot-check source:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodePushing.cpp>
- Binaryen `version_129` lit tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_into_if.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_ignore-implicit-traps.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing_tnh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-pushing-eh.wast>
