---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md
related:
  - ./index.md
  - ./typed-control-voidification-and-eh.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `dead-code-elimination` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass.

Primary files:

- `src/passes/DeadCodeElimination.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`

Most important helper dependencies:

- `src/ir/effects.h`
- `src/ir/type-updating.h`
- `src/ir/eh-utils.h`
- `src/ir/properties.h`
- `src/ir/flatten.h`

The shipped dedicated test surface is part of the contract too:

- `test/lit/passes/dce_all-features.wast`
- `test/lit/passes/dce_vacuum_remove-unused-names.wast`
- `test/lit/passes/dce-eh.wast`
- `test/lit/passes/dce-eh-legacy.wast`
- `test/lit/passes/dce-stack-switching.wast`

## High-level intent

Binaryen uses `dead-code-elimination` for two tightly related jobs:

1. remove code that is provably unreachable after non-fallthrough points
2. remove or simplify expressions whose **result** is dead while preserving side effects and valid structure

That second point is the one people miss.
DCE is not just about dead tails.
It is also about dead typed wrappers and dead dropped values.

## Where the pass runs

`pass.cpp` registers:

- `dce`
  - description: `removes unreachable code`

In the default no-DWARF function pipeline, Binaryen inserts `dce` once, immediately after `ssa-nomerge`:

- `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> optimize-instructions -> ...`

That placement is meaningful.
The pass is expected to expose further cleanup for the next passes rather than finishing the whole early cleanup story by itself.

The saved generated-artifact `-O4z` audit observed the analogous top-level slot at `12`, while the saved full debug log shows `18` total `dce` executions because nested reruns also include the pass.

## The biggest beginner correction

Despite the name and short description, Binaryen DCE is **not** a generic whole-function dataflow deadness engine.

The strongest evidence is its actual structure:

- no full local-liveness framework here
- no store/load deadness analysis
- no whole-module reachability reasoning
- heavy emphasis on `EffectAnalyzer`, structure kind checks, and block-target awareness

So a safer summary is:

- **effect-aware unused-result simplification plus unreachable-suffix cleanup**

## Phase 1: helper walkers classify blocks before simplification

The file begins with two small walkers.

### `BranchSeeker`

This walker answers whether a nested branch targets a particular block.
That matters because a branch-targeted block cannot be treated like a plain sequence wrapper.

### `UnneededBlockSeeker`

This helper uses `BranchSeeker` to find blocks that really are unneeded.
That gives DCE a way to simplify blocks aggressively **only** when their label is not part of the live control-flow contract.

This is one of the most important safety gates in the whole pass.

## Phase 2: `canRemove(...)` asks an effect question, not a syntax question

`canRemove(...)` wraps `EffectAnalyzer`.
The crucial rule is:

- if an expression is removable when unused, DCE may erase it
- otherwise, DCE must preserve its side effects somehow

That is why these two shapes behave differently:

```wat
(drop (i32.add (i32.const 1) (i32.const 2)))
```

can disappear entirely, while:

```wat
(drop (call $impure))
```

cannot.

The pass does not care whether the node *looks* small.
It cares whether dropping the result also drops observable behavior.

## Phase 3: `optimizeExpression(...)` is child-first and kills unreachable suffixes early

This helper recursively optimizes children before the parent.
Then it scans the children in order.
When it finds a child that cannot fall through, it clears the remaining siblings because they are now dead.

That gives DCE an immediate local rule for shapes like:

- `return ... ; dead`
- `throw ... ; dead`
- `delegate ... ; dead`
- child subexpressions that become `unreachable`

The important beginner lesson is:

- DCE does not wait for a later global sweep to notice these tails
- it removes them while recursively simplifying the tree

## Phase 4: impossible dead-result expressions can collapse to simpler forms

After child optimization, `optimizeExpression(...)` also handles some dead-result “this cannot actually produce a useful value anymore” families.

The exact source branches are subtle, but the durable story is straightforward:

- if a dead-result expression can be replaced by its remaining side effects plus a simpler surviving branch or default arm, DCE does that
- if a child rewrite proves a parent can only lead to `unreachable`, DCE can turn the parent into side effects plus `unreachable`

This is still effect-preserving cleanup.
It is not speculative control-flow rewriting for its own sake.

## Phase 5: `visitDrop(...)` is where the real dead-result story lives

`visitDrop(...)` is the heart of the pass.

Its real job is:

- decide what to do when a value is computed only to be dropped

That splits into several cases.

### Case A: the child is fully removable

Then DCE removes the whole `drop`.

### Case B: the child still has side effects, but its result is dead

Then DCE tries to simplify the child to just the still-needed contents.
This preserves effect order while deleting dead pure pieces.

### Case C: the child is a control-flow structure with a dead result

This is the hard case.
Binaryen often cannot simply delete the structure.
Instead it:

- keeps the control shell
- changes its type from “produces a value” to “void”
- and lets later repair helpers fix up the resulting type/EH/block details

This is the biggest reason DCE is more than a plain dead-tail pass.

## Phase 6: `visitBlock(...)` simplifies blocks conservatively

`visitBlock(...)` uses the helper walkers to ask whether a block is genuinely unneeded.
The practical rule is:

- if the label is live, keep the block
- if the block is only sequencing effects before a dead final value, simplify to those contents
- if internal nonfinal roots still matter, keep them in order
- if only the final value is pointless, do not pretend the rest of the block was pointless too

So DCE can reduce blocks a lot, but only after proving they are not still part of the control-flow contract.

## Phase 7: function-end repair is mandatory, not optional polish

After the structural rewrites, `visitFunction(...)` still runs a real repair tail:

- `TypeUpdater::handleNonDefaultableLocals(...)`
- `EHUtils::handleBlockNestedPops(...)`
- `Flatten::flatten(...)`
- `ReFinalize()`

That means the pass contract is really:

- simplify first,
- then repair types / EH / block shape,
- then refinalize.

If a future port only copies the deletion logic and forgets the repair tail, it will be semantically incomplete.

## The helper stack matters

## `EffectAnalyzer`

This is the main semantic oracle.
It is why DCE can safely distinguish:

- dead pure values to erase
- effectful values whose side effects must survive
- non-fallthrough children that make later siblings unreachable

## `Properties::isControlFlowStructure(...)`

This helper draws the line between:

- expressions that can simplify directly to contents
- and typed control structures that must be voidified instead

## `TypeUpdater::handleNonDefaultableLocals(...)`

When result traffic disappears, some locals may no longer be justified at their old precise/nondefaultable type.
Binaryen repairs that explicitly.

## `EHUtils::handleBlockNestedPops(...)`

Exception handling is not an afterthought here.
DCE's structural rewrites can expose nested-pop problems, and Binaryen fixes them directly before finishing the pass.

## `Flatten::flatten(...)`

Some DCE rewrites simplify meaning but still leave nested block shape behind.
Flatten is part of the pass's practical cleanup tail.

## `ReFinalize`

Once types and nesting changed, Binaryen recomputes final expression types.
This is part of the real pass boundary, not just a convenience.

## Pass interactions that are easy to miss

## `vacuum` and `remove-unused-names` are part of the documented story

The dedicated `dce_vacuum_remove-unused-names.wast` file is a strong signal from upstream.
It explicitly tests the combined cleanup lane.

So the durable rule is:

- DCE is expected to leave some cleanup work for `vacuum` and `remove-unused-names`
- those passes are not accidental neighbors

## `remove-unused-brs` follows immediately for a reason

After DCE has simplified dead-result structure, stale or simplified branch structure is often more obvious.
That is why Binaryen places `remove-unused-brs` right after the name cleanup.

## Nested reruns matter for real-world behavior

The `optimizeAfterInlining` helper in `opt-utils.h` includes `dce` in the rerun sequence on changed functions.
So DCE is not only a top-level early slot.
It is also part of the nested cleanup contract used by optimizing boundary passes.

## What a future port must preserve

A future Starshine port or refactor must keep these Binaryen-backed invariants honest:

- DCE is not generic local/global dead-store elimination
- effect-order preservation is the central safety rule
- branch-targeted blocks cannot be simplified like plain sequencing blocks
- dead typed control usually needs **voidification**, not blind erasure
- explicit `unreachable` tails can still be required after simplification
- local-type repair and EH nested-pop repair are part of the pass, not optional cleanup
- later passes (`vacuum`, `remove-unused-names`, `remove-unused-brs`) are expected to finish parts of the cleanup story

## Current freshness note

A narrow 2026-04-20 `main` check did not reveal an obvious post-`version_129` drift story.
The same pass shell and dedicated test-file set are still present there, so `version_129` remains a strong practical oracle for this dossier.
