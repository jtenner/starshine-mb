---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/DeadCodeElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/dce-stack-switching.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# `dead-code-elimination`: control-type changes and EH repair

This page replaces an older wrong summary.
The earlier dossier talked about broad typed-control **voidification**.
The 2026-05-05 current-main recheck kept the narrower source-backed contract unchanged, and the 2026-06-28 `version_130` source refresh found the same shape.
The source-confirmed Binaryen pass does something narrower:

- it sometimes changes a control-flow node's type to `unreachable`, and
- it sometimes replaces an entire node with an already-unreachable child,
- then it may run one narrow EH nested-pop fixup.

That is not the same thing as a general result-to-void rewrite engine.

## The safe mental model

For Binaryen `dce`, the right question is usually **not**:

- “can I erase this typed wrapper because its value is dead?”

The right question is:

- “has this control structure become unable to finish normally?”

If the answer is yes, DCE often changes the node's type to `unreachable`.

## `block`: concrete type can collapse to `unreachable`

After trimming dead suffixes, DCE checks a block with three conditions:

- the block still has a concrete type,
- its last surviving child is unreachable,
- and `TypeUpdater` sees no `break`s targeting the block.

Only then does DCE change the block type to `unreachable`.

So the real source-backed rule is:

- the pass does **not** generally voidify blocks,
- it narrows concrete block type to `unreachable` when the block no longer has a normal way to produce its value.

The incoming-break check is the key safety gate.

## `if`: two narrow cases

### Unreachable condition

If the condition itself is unreachable, DCE removes the arms and replaces the `if` with the condition expression.

### Both arms unreachable

If the `if` has an `else`, is not already unreachable, and both arms are unreachable, DCE changes the `if` type to `unreachable`.

Again, this is not a generic dead-result-to-void rewrite.
It is a reachability/type fact.

## `loop`: only replace when the body is literally unreachable

The source comment is explicit here: loops can have unreachable body type for ordinary reasons like branching back to the loop top.
So DCE only handles the strongest case:

- the body expression itself is `unreachable`

Then the loop is replaced by the body.

## `try` and `try_table`: EH reachability, not generic EH simplification

### `try`

If the try body is unreachable and every catch body is unreachable, DCE changes the try node type to `unreachable`.

### `try_table`

If the `try_table` body is unreachable, then the whole `try_table` cannot finish normally, so DCE changes its type to `unreachable`.

The modern EH test file exists largely to lock in these exact reachability distinctions.

## Why the old "voidification" story was misleading

The earlier pages implied a pass that broadly kept control wrappers but erased their result type.
That is not what `version_129` `DeadCodeElimination.cpp` actually implements.

What the source actually does is much smaller:

- replace some nodes with an unreachable child,
- trim dead suffixes,
- or mark a node itself as unreachable.

That is a control/reachability normalization story, not a generic "dead result wrapper" story.

## EH repair is one exact end-of-function hook

The pass tracks two booleans while walking a function:

- `hasPop`
- `addedBlock`

At function end it runs:

- `EHUtils::handleBlockNestedPops(curr, *getModule())`

only if both booleans are true.

So the real EH rule is:

- DCE does not run a broad EH repair pipeline,
- it only repairs the nested-`pop` hazard introduced when DCE-created blocks interact with `pop`.

## Why `dce-eh-legacy.wast` matters

The legacy EH file includes cases where DCE creates new blocks around surviving effects while a `pop` remains part of the reachable path.
That file is the strongest direct evidence for the `hasPop && addedBlock` rule.

Without that repair, DCE could leave `pop` in an invalid nested position after simplifying a larger expression.

## Why `dce-stack-switching.wast` matters

The stack-switching file guards against a tempting mistake: assuming a surrounding `drop` means a result type is dead.

In the `resume` / `resume_throw` tests, the result type of a handler block must remain because the handler can branch to that block and still depend on its typed label contract.

So a future port must preserve this lesson:

- result-dead-looking surface syntax does not override handler-target liveness.

## Starshine local representation boundaries as of 2026-06-28

Starshine now has focused and generated coverage for modern `try_table`, including a `catch_ref` leaf in `dead-code-elimination-all`. The remaining legacy EH and stack-switching surfaces are not silent parity claims; they are representation/tool boundaries:

- canonical `src/lib` instructions include `TryTable`, `Throw`, and `ThrowRef`, but no legacy `Try`, old-EH `Pop`, `Resume`, or `ResumeThrow` instruction;
- WAST legacy `try` / `rethrow` input is lowered before optimizer passes: legacy `try` becomes a synthetic block/check shape ending in `unreachable`, and accepted legacy `rethrow` lowers to `unreachable` rather than a preserved old-EH node;
- `pop` is not represented in the canonical instruction enum, so Binaryen's `hasPop && addedBlock` nested-pop repair has no local pass-time analogue to run;
- stack-switching `resume` / `resume_throw` is not represented in canonical `src/lib` or generated by GenValid.

Reopen these boundaries if Starshine adds canonical old-EH `try`/`pop`, stack-switching instructions, or a lowering path that preserves those nodes into `dead-code-elimination`, or if Binaryen changes DCE so the same safety issue has a modern `try_table`/`throw_ref` equivalent.

## Porting rules to preserve

- Do not implement generic control voidification under the name `dce`.
- Keep the block `hasBreaks(...)` guard before collapsing block type to `unreachable`.
- Keep `if`, `loop`, `try`, and `try_table` as separate special cases.
- Preserve the exact EH repair trigger for any future old-EH representation: `hasPop && addedBlock`.
- Treat stack-switching handler labels as part of the real liveness boundary if stack-switching enters the local IR.
