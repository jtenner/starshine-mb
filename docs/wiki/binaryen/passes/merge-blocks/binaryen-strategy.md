---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md
  - ../../../raw/binaryen/2026-04-22-merge-blocks-primary-sources.md
  - ../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md
related:
  - ./index.md
  - ./wat-shapes.md
  - ./implementation-structure-and-tests.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
supersedes:
  - ../../../raw/research/0111-2026-04-20-merge-blocks-binaryen-research.md
  - ../../../raw/research/0255-2026-04-22-merge-blocks-primary-sources-and-starshine-followup.md
---

# Binaryen `merge-blocks` Strategy

## Source rule and correction

Use Binaryen `version_129` as the tagged source oracle for this pass, with the 2026-04-25 current-main check as a drift guard.

Primary source manifest:

- [`../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md)

Important correction: older local pages described `merge-blocks` as a tail-child-only pass that primarily merges unnamed or same-name child blocks. Re-reading official `MergeBlocks.cpp` and `merge-blocks.wast` contradicts that simplified model.

The corrected beginner summary is:

- Binaryen removes redundant **named block layers** when all branches that mention the inner name can safely be retargeted to the surrounding block name.
- It also has dedicated `if`-arm and terminal-expression name-removal paths.
- Nameless block wrappers are **not** the main positive case; the official lit file has `no-merge-nameless` coverage.

## One-table overview

| Component | Source-owned role | Beginner meaning |
| --- | --- | --- |
| `ProblemFinder` prescan | Skip a whole function if branch retargeting could confuse same-name nested targets | Do not rewrite labels when removing a block would make old branch targets ambiguous |
| branch-user collection | Find all branches that target a block name | A named block cannot be removed until its branch users are understood |
| `canChangeTo(block, parent)` | Prove a child block name can be changed to the parent block name | Retargeting is allowed only when every branch user remains semantically safe |
| `visitBlock(...)` | Splice accepted child block contents into the parent block list and rewrite name uses | Delete one redundant named block layer |
| `visitIf(...)` | Remove named block wrappers from `if` arms when the same proof succeeds | Deblock `then` / `else` shapes without pretending they are ordinary tail children |
| terminal visitors | Remove child block names around `throw`, `rethrow`, and `return` families | If the terminal exits anyway, a wrapper label can be unnecessary |
| `ReFinalize` | Recompute expression types after structural edits | Type repair is part of the pass contract |

## Phase 1: function-wide ambiguity prescan

Before the normal postwalk, Binaryen runs `ProblemFinder` over the function.

The important fact is the bailout strength:

- if the bad family is found anywhere, Binaryen skips block merging for the whole function;
- it does not merely skip the nearest candidate.

The bad family is about branch-target ambiguity after removing a named block layer. If a rewrite first deletes an inner name and only later updates name uses, old branch targets can become indistinguishable from a surrounding same-name target. Binaryen chooses safety by avoiding the whole function in that case.

This part of the older dossier was directionally right, but it was overused to justify a tail-child-only model. `ProblemFinder` is a guard inside a broader named-block rewrite pass.

## Phase 2: collect branch users by target name

The real legality proof starts from branch users, not from a syntactic “last child” test.

Binaryen needs to know:

- which branches target the child block name;
- which containing block each branch exits;
- whether those containing exits can themselves be changed to the candidate parent;
- whether retargeting would skip invalidating effects.

This is why helper surfaces such as `branch-utils.h` and `effects.h` matter for a faithful reading. The pass is small because it delegates branch-scope and side-effect questions to shared Binaryen utilities.

## Phase 3: `canChangeTo(...)` is the core safety proof

`canChangeTo(block, parent)` is the key function to read.

Its durable contract is:

1. Nameless blocks do not pass this proof.
2. If the child and parent already have the same name, the direct rename proof is trivial.
3. Otherwise, Binaryen inspects every branch user of the child name.
4. Each branch user's exiting block must be changeable to the parent too.
5. The path between relevant positions must not contain effects that would be invalidated by retargeting the branch.

That recursive shape is the central correction to the old docs.

Older wording said “different-name child does not merge.” The source is more subtle: different names can be legal when their branch users can be recursively retargeted to the parent safely.

## Phase 4: `visitBlock(...)` splices accepted named child blocks

The normal block visitor:

1. scans child expressions in a parent block list;
2. looks for named block children;
3. requires `canChangeTo(child, parent)`;
4. checks immediate named grandchildren so removing the middle layer does not strand an unsafe name relation;
5. splices the child block's list into the parent list;
6. rewrites scope-name uses from the child name to the parent name;
7. runs `ReFinalize` on the rewritten block.

The most important correction is what this is **not**:

- not tail-child-only;
- not unnamed-child flattening;
- not same-name-only;
- not a generic flatten-all-blocks pass.

It is a named-block deblocking pass whose proof is branch-user and effect driven.

## Phase 5: `visitIf(...)` owns a separate shape family

Binaryen also has an `if` visitor that applies the same named-wrapper idea to `if` arms.

The teaching point is simple:

- an `if` arm can contain a named block wrapper;
- if the name can be safely changed to the containing block's name, Binaryen can remove that label layer;
- this is not literally the same shape as “a block's final child is another block.”

This matters for shape catalogs and future ports because a local implementation that only scans block-list tail children would miss an official upstream surface.

## Phase 6: terminal visitors remove redundant names

`MergeBlocks.cpp` also has visitors for terminal families such as `throw`, `rethrow`, and `return`.

The high-level role is to remove a block name around a terminal expression when the label is only structural noise. These visitors make the pass more than a block-list splice pass.

Beginner rule:

- if the inner expression exits anyway, the surrounding block label may not need to remain as an observable branch target.

Advanced caution:

- treat this as a source-backed pass surface, not as permission to erase arbitrary names around arbitrary control instructions. The same branch-user and scope-name safety rules still frame the file.

## Phase 7: refinalization is mandatory

After successful structural rewrites, Binaryen refinalizes the affected expression.

That is a correctness signal:

- block removal can change the expression tree that type finalization sees;
- branch name retargeting can alter payload expectations;
- the pass treats type repair as part of the transformation, not as optional cleanup.

## What Binaryen does not do

`merge-blocks` still has a narrow scope even after the correction.

It does **not**:

- flatten nameless wrappers as a general rule;
- replace `flatten`;
- replace `remove-unused-brs`;
- solve arbitrary CFG restructuring;
- ignore branch users;
- ignore skipped effects;
- skip refinalization after edits.

The corrected mental model is “named-block deblocking with branch-retargeting proof,” not “general block flattening.”

## Relationship to current Starshine

Current Starshine is in the same cleanup family but uses a different HOT-IR proof:

- Starshine flattens branch-free HOT region-root blocks, including unlabeled local wrappers.
- Starshine refuses any block whose label is referenced anywhere in the function.
- Therefore Starshine has no local equivalent of Binaryen's recursive name-retargeting proof, `ProblemFinder`, or named-child effect barrier.
- Starshine adds local typed-carrier guards and dead-`unreachable` suffix repair because HOT lowering/writeback has different obligations from Binaryen's AST refinalizer.

Read [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) for the local code map.

## Sources

- [`../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md`](../../../raw/binaryen/2026-04-25-merge-blocks-current-main-source-correction.md)
- [`../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md`](../../../raw/research/0357-2026-04-25-merge-blocks-source-correction-and-code-map.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeBlocks.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-blocks.wast>
- Binaryen current-main pass source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeBlocks.cpp>
