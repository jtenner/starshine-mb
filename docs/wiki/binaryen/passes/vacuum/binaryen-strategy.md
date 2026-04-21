---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md
  - ../../../raw/research/0210-2026-04-21-vacuum-source-confirmation-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./effect-pruning-and-traps-never-happen.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `vacuum` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass.

Primary files:

- `src/passes/Vacuum.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/passes/opt-utils.h`
- `src/ir/branch-hints.h`
- `src/ir/drop.h`
- the shipped `vacuum-*` lit tests

For the compact owner/test map of those files, use [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

I also did a narrow 2026-04-20 freshness check against:

- GitHub `main` `src/passes/Vacuum.cpp`
- Chromium commit `f284d54...`
- Chromium commit `9ee4a25...`

Durable result:

- `f284d54...` is the actual 2026-02-27 `Vacuum.cpp` change that preserves explicit `unreachable` at function scope
- that change is already in `version_129`
- `9ee4a25...` is actually a `RemoveUnusedBrs.cpp` change
- current GitHub `main` still matches `version_129` `Vacuum.cpp` in substance

So the repo's older “trunk-only drift” framing for that `vacuum` behavior was too strong.

## High-level intent

Binaryen uses `vacuum` as a repeated cleanup pass that removes obviously unnecessary code *when* the result is unused, the remaining effects can still be represented honestly, and the surrounding type structure stays valid.

That is more precise than either of these summaries:

- `vacuum` just removes `nop`
- `vacuum` just removes dead code

The real pass is closer to:

- **unused-result effect pruning plus structural cleanup**

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Walk + refinalize | Bottom-up walk, then `ReFinalize` | Clean up safely without leaving broken types or EH state |
| Generic unused-result pruning | `optimize(curr, resultUsed, typeMatters)` | Remove pure wrappers while preserving effectful children |
| Block cleanup | TNH trap-path pruning, child compression, trivial-block collapse | Turn leftover residue into simpler block contents |
| If cleanup | constant/unreachable condition simplification, arm removal, hint flipping | Remove now-useless conditional structure |
| Drop cleanup | dropped tee -> set, dropped block-result popping, drop sinking | Clean common residue from other passes |
| EH cleanup | non-throwing `try` / `try_table` removal, no-effect catch-all `try` removal | Trim exception wrappers conservatively |
| Function cleanup | whole-body nop for void functions with no observable effects, plus explicit-`unreachable` safeguard | Delete entire vacuous bodies without breaking propagation |

## Phase 1: this is a function-parallel AST walker, not a dataflow pass

`Vacuum` inherits from `WalkerPass<ExpressionStackWalker<Vacuum>>` and reports `isFunctionParallel() == true`.

That already tells us a lot:

- the pass is per-function
- it is tree-shaped, not CFG-shaped
- it relies on local visitor logic and effect helpers, not on liveness or dominance

The driver is tiny:

- `walk(func->body)`
- `ReFinalize().walkFunctionInModule(func, getModule())`

That final `ReFinalize` is part of the strategy, not cleanup garnish.

## Phase 2: `optimize(...)` is the central algorithm

The core helper is:

- `Expression* optimize(Expression* curr, bool resultUsed, bool typeMatters)`

The important control rules are:

- `Type::none` forces `typeMatters = true`
- `Type::unreachable` is left unchanged
- if the result is actually used, the helper gives up immediately
- special nodes are left to their dedicated visitors:
  - `Drop`
  - `Block`
  - `If`
  - `Loop`
  - `Try`
  - `TryTable`

After that, the helper asks two questions.

### Question 1: must the parent itself stay?

That logic lives in `mustKeepUnusedParent(...)`.

The helper:

- checks `call` annotations via `Intrinsics`
- otherwise uses `ShallowEffectAnalyzer`

This means:

- a call marked `removableIfUnused` can disappear even before ordinary effect analysis says more
- but the ordinary case still depends on whether the parent node itself has unremovable side effects

### Question 2: which children still matter?

If the parent itself can go away, Binaryen scans the children with full `EffectAnalyzer` and collects only those with unremovable side effects.

Then it picks one of three outcomes:

- no effectful children -> return `nullptr`
- exactly one effectful child -> recurse into that child
- multiple effectful children -> use `getDroppedChildrenAndAppend(...)` if a valid replacement value can be synthesized

That third case is why `drop.h` matters here.

## Phase 3: multi-child pruning depends on defaultable dummy values

When multiple effectful children remain, Binaryen may need to preserve the parent's type while deleting the parent itself.

The rule is:

- if `curr->type.isDefaultable()`, append a dummy zero of the right type and return a rebuilt expression sequence
- otherwise keep the original node

That is the core type-preservation boundary.

It explains several shipped tests where `vacuum` can optimize unused `i32` or nullable-ref values more aggressively than non-defaultable or awkward reference cases.

## Phase 4: block cleanup is both structural and option-sensitive

`visitBlock(...)` does more than “remove nops from a list.”

## A. TNH backward scan

In `trapsNeverHappen` mode, Binaryen scans backward from an explicit `unreachable` inside a block.

It can turn preceding nodes into `nop` while it is still certain execution heads into that trap.

It stops when the current node:

- transfers control flow
- calls
- may not return
- has a dangling `pop`

That barrier set is important.

A future port must not treat TNH as “all trap-only code disappears everywhere.”

## B. Child-by-child pruning

Then the block children are processed with `optimize(...)`.

The last child is treated specially because it may still feed the block result.

If an unused child disappears:

- a final concrete child may need a zero placeholder
- a child of type `unreachable` is intentionally kept for DCE later

## C. Final block collapse

After compression:

- later siblings after an `unreachable` are truncated
- `BlockUtils::simplifyToContents(...)` removes trivial wrapper blocks

That is why the pass depends directly on `block-utils.h` even though the top-level idea sounds simple.

## Phase 5: `if` cleanup has several non-obvious contracts

`visitIf(...)` handles these families.

## Constant or unreachable condition

- constant condition -> pick the taken arm directly
- unreachable condition -> return the condition directly

## TNH unreachable-arm removal

If TNH is enabled and exactly one arm is definitely `unreachable`:

- replace the `if` with `drop(condition)` plus the other arm

But if both arms are unreachable:

- leave it for DCE

That asymmetry is explicit in the source comments.

## Empty-arm cleanup and condition flipping

If `ifFalse` is `nop`:

- just remove it

If `ifTrue` is `nop` but `ifFalse` is real:

- move the old `else` into `then`
- remove the `else`
- wrap the condition in `eqz`
- call `BranchHints::flip(curr, getFunction())`

That branch-hint update is part of the contract.

## `drop(if ...)` normalization

If both arms are `drop` of the same type:

- unwrap the arm values
- finalize the `if`
- rebuild as `drop(if ...)`

That removes duplicated dropping structure.

## Phase 6: loop cleanup is intentionally tiny

`visitLoop(...)` only removes a loop when:

- `curr->body->is<Nop>()`

The pass does not do richer loop reasoning here.

The TNH tests show why that conservatism exists:

- loops can be infinite
- loops can block trap reachability
- loops can hide other side effects

## Phase 7: `visitDrop(...)` is where many practical rewrites live

`visitDrop(...)` begins by running the generic helper on the dropped value.

Then it adds several special cases.

## Dropped tee -> set

If the remaining dropped value is a `local.tee`:

- turn it into a `local.set`

This is a real rewrite family, not an incidental printer cleanup.

## Entire drop disappears if effects allow it

If the resulting `drop` itself has no unremovable side effects:

- the drop becomes `nop`

## Popping a dropped block result

If the dropped value is a block whose last item only exists to feed the block result:

- optimize the last item as unused
- if it disappears, use `BranchUtils::BranchSeeker` on named blocks to see whether branches still carry values to that block
- if not, pop the last item and simplify the block

This is the most important place where the pass interacts with branch-result structure.

## Sinking a drop into one live `if` arm

If one `if` arm is concrete and the other is `unreachable`:

- Binaryen can move the drop inside the live arm
- then make the `if` itself produce no result

The source comment explicitly says this can enable more cleanup later.

## Phase 8: EH cleanup is deliberately asymmetric

`visitTry(...)` and `visitTryTable(...)` both remove wrappers when the body does not throw.

But only `try` gets the extra “catch-all and no observable effects means nop the whole thing” cleanup.

The `vacuum-eh.wast` tests make the reason clear:

- `try_table` has a profitable branch-conversion story that `remove-unused-brs` handles better

So a future port must preserve that asymmetry unless the upstream source changes.

## Phase 9: function-level cleanup includes the explicit-`unreachable` safeguard

After optimizing the function body directly, `visitFunction(...)` may nop the whole body of a `void` function if the function has no unremovable side effects.

But if the only remaining effect is a trap removable under TNH:

- Binaryen checks `FindAll<Unreachable>(curr->body)`
- if an explicit `unreachable` exists, it refuses to nop the whole body

This matters because:

- explicit `unreachable` should still propagate to callers and later passes

This safeguard is already part of `version_129`.

## Scheduler placement is part of the pass meaning

In the canonical no-DWARF default function pipeline, `vacuum` runs in four different cleanup roles:

1. after `simplify-locals-nostructure`
2. after `simplify-locals`
3. after `reorder-locals` / `coalesce-locals` cleanup churn
4. after `rse`

Those placements make sense once the pass is understood correctly:

- earlier local cleanup leaves wrappers, dropped values, and empty shells behind
- `vacuum` erases that residue cheaply
- later passes then see a cleaner tree

The pass is therefore a repeated cleanup handoff, not a singular late-pass flourish.

## What the pass sounds like versus what it actually is

What it sounds like:

- a boring `nop` collector

What it actually is:

- a local tree cleanup pass with:
  - effect-aware unused-result pruning
  - type-preserving replacement logic
  - explicit structural rewrites for `if`, `drop`, and EH forms
  - TNH-specific path cleanup
  - function-level no-oping with explicit-`unreachable` preservation
  - mandatory refinalization at the end

That is the behavior a future Starshine parity port must preserve.

## Bottom line

Binaryen `vacuum` is a deliberately small but carefully engineered cleanup pass.

Its strength comes from being:

- local
- repeated
- effect-aware
- type-safe
- and brutally practical about leftover residue

Its weakness, by design, is that it does **not** try to become DCE, CFG simplification, or a full EH optimization pass.
