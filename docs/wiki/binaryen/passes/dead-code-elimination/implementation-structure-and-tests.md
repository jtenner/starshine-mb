---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md
  - ../../../raw/research/0250-2026-04-22-dead-code-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadCodeElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_vacuum_remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-stack-switching.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./typed-control-voidification-and-eh.md
  - ./wat-shapes.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `dead-code-elimination`: implementation structure and test map

This page closes a real teaching gap in the older dossier.
The earlier pages described a much broader pass with helper walkers, effect-driven dead-result pruning, flattening, and refinalization.
A direct re-read of Binaryen `version_129` shows the real pass is much smaller and more specific.

## Why this follow-up was needed

The existing folder already had a deep landing page, but it still lacked one compact source-confirmed answer to two practical questions:

1. what code actually owns Binaryen `dce`?
2. which shipped tests prove each part of the contract?

That mattered because the older living pages overstated the pass.
The source file does **not** implement a general dead-result optimizer over effect analysis.
It implements a single function-parallel postwalk that rewrites unreachable shapes and adjusts types with `TypeUpdater`.

## Exact upstream files that matter

### Core implementation

- `src/passes/DeadCodeElimination.cpp`
  - the whole public pass implementation in `version_129`
  - there is no sibling helper file for the core algorithm

### Registration and scheduler placement

- `src/passes/pass.cpp`
  - registers public pass name `dce`
  - short description: `removes unreachable code`
  - places `dce` immediately after `ssa-nomerge` in the no-DWARF default function pipeline

### Dedicated test surfaces

- `test/lit/passes/dce_all-features.wast`
  - large all-features shape roster for ordinary expression and control-flow rewrites
- `test/lit/passes/dce_vacuum_remove-unused-names.wast`
  - proves the intended neighborhood with `vacuum` and `remove-unused-names`
- `test/lit/passes/dce-eh.wast`
  - modern EH and `try_table` surface
- `test/lit/passes/dce-eh-legacy.wast`
  - legacy EH plus `pop`-movement safety surface
- `test/lit/passes/dce-stack-switching.wast`
  - stack-switching `resume` / `resume_throw` label-liveness surface

## Real implementation structure

Binaryen `version_129` `dce` is one small `WalkerPass<PostWalker<...>>` with four noteworthy pieces of state or behavior.

### 1. Function-parallel postwalk shell

The pass is declared as a function-parallel postwalk over expressions.
That means the algorithm is child-first and local to one function body at a time.
There is no module-wide fixed point and no separate analysis pass.

### 2. `TypeUpdater` owns the bookkeeping

The only persistent helper object in the pass is:

- `TypeUpdater typeUpdater;`

The pass uses it to:

- seed type/update state before walking the function body
- note replacements when `replaceCurrent(...)` swaps an expression
- note recursive removals when dead suffixes are trimmed away
- ask whether a `block` still has incoming `break`s
- change node types to `unreachable` when the concrete result type is no longer justified

This is the main source-backed correction to the earlier dossier.
The pass is centered on `TypeUpdater`, not on `EffectAnalyzer`.

### 3. Two EH-fixup booleans, not a broad repair pipeline

The pass tracks:

- `hasPop`
- `addedBlock`

Those are only used for one conservative end-of-function repair:

- if the function contains a `pop` and DCE created a new block, run `EHUtils::handleBlockNestedPops(...)`

That is much narrower than the old folder implied.
There is no general end-of-pass `Flatten::flatten(...)`, `ReFinalize`, or `handleNonDefaultableLocals(...)` call in `version_129` `DeadCodeElimination.cpp`.

### 4. One main visitor: `visitExpression(...)`

Almost the entire pass lives in one visitor.
It splits on whether the current node is a control-flow structure.

## Real algorithm by node family

### Non-control expressions

If a non-control expression has type `unreachable`, DCE checks whether **one of its children is already unreachable**.
If so, later children are dead and removed.
Earlier children are preserved by wrapping them in `drop`s, then the first unreachable child is kept, and if needed Binaryen materializes a new `block` containing:

- dropped earlier children
- the first unreachable child

This is the core “preserve what still executes, kill what cannot execute after the first unreachable child” rule.

### `block`

For `block`, DCE does two things.

1. It trims the suffix after the first child with type `unreachable`.
2. If the block still has a concrete result type but its last surviving child is `unreachable` and `TypeUpdater` sees no `break`s targeting the block, DCE changes the block type to `unreachable`.

If the trimmed block collapses to one child and that child is literal `unreachable`, DCE replaces the whole block with that child directly.

### `if`

For `if`, DCE handles two special cases.

1. If the condition is unreachable, the arms are recursively removed and the whole `if` becomes the condition.
2. If the `if` itself is not already unreachable, has an `else`, and both arms are unreachable, DCE changes the `if` type to `unreachable`.

That is narrower than “generic dead arm simplification.”
It is really type repair around already-unreachable parts.

### `loop`

`loop` gets only one very small rule:

- if the body is literally `unreachable`, replace the loop with the body

The source comment explicitly notes that loops can have unreachable body type for normal reasons like branching back to the top, so DCE only looks for the fully-dead-body case.

### `try`

For legacy `try`, DCE checks whether:

- the try body is unreachable, and
- all catch bodies are unreachable

If both are true and the try node is not already marked unreachable, DCE changes the try type to `unreachable`.

### `try_table`

For `try_table`, DCE uses the simpler rule that the construct can finish normally only if its body finishes normally.
So if the body is unreachable and the `try_table` type is still concrete, DCE changes the node type to `unreachable`.

## What the source does **not** do here

These older dossier claims are not source-confirmed for Binaryen `version_129` `DeadCodeElimination.cpp`:

- no `BranchSeeker` or `UnneededBlockSeeker`
- no `EffectAnalyzer`-based `canRemove(...)`
- no special `visitDrop(...)` dead-result engine
- no general typed-control voidification pass over `drop` wrappers
- no `Flatten::flatten(...)`
- no `ReFinalize`
- no `TypeUpdater::handleNonDefaultableLocals(...)`

Some of those ideas belong more to nearby passes like `vacuum`, or to older/imagined DCE designs, but they are not the actual `version_129` implementation in this file.

## Test map: what each lit file is really proving

### `dce_all-features.wast`

This is the broad ordinary-contract file.
It proves that DCE handles shapes like:

- blocks with dead suffixes after `br`, `return`, `br_table`, and `unreachable`
- ifs whose condition is unreachable
- ifs whose arms are both unreachable
- loops whose body becomes fully unreachable
- non-control expressions with an unreachable child where earlier children must be converted to `drop`

It is the best single file for the pass's ordinary AST rewrite surface.

### `dce_vacuum_remove-unused-names.wast`

This file proves a different point:

- Binaryen expects `dce` to leave useful cleanup opportunities for `vacuum` and `remove-unused-names`

So the file is not evidence that DCE alone does all final simplification.
It is evidence that the intended neighborhood matters.

### `dce-eh.wast`

This file covers modern EH and `try_table` behavior, including:

- reachable catch making later code still reachable
- both body and catch unreachable allowing later code to die
- `throw` and `throw_ref` dead-wrapper cleanup that preserves the actually executing path

### `dce-eh-legacy.wast`

This file covers legacy EH `try` plus the subtle `pop` story.
Most importantly, it demonstrates why `hasPop` plus `addedBlock` triggers `EHUtils::handleBlockNestedPops(...)` at function end.
The file includes shapes where DCE-created blocks would otherwise leave nested `pop`s in invalid positions.

### `dce-stack-switching.wast`

This file proves DCE must respect stack-switching label liveness.
In particular, a surrounding `drop` does **not** mean the block result is dead if stack-switching handlers can still branch to that block and use its result type.

## Scheduler map

`pass.cpp` keeps the top-level no-DWARF placement:

- `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> ...`

The combined test file and scheduler placement together support a simple rule:

- DCE should make later cleanup easier, not try to subsume `vacuum` or `remove-unused-names`.

## Current `main` drift check

The reviewed official Binaryen GitHub `version_129` release page was re-checked on 2026-04-22 and showed publish date **2026-04-01**.
A narrow `version_129` versus current `main` source diff on `src/passes/DeadCodeElimination.cpp`, `pass.cpp`, and representative ordinary/EH tests did not surface a teaching-relevant drift in the pass contract.
So the `version_129` file remains a strong current oracle for this dossier.

## What a future Starshine port must preserve

- Use a child-first function-local postwalk mental model.
- Preserve earlier children as `drop`s when a later child makes a non-control expression unreachable.
- Trim block suffixes after the first unreachable child.
- Use block-break knowledge before collapsing a concrete block type to `unreachable`.
- Keep the tiny special cases for `if`, `loop`, `try`, and `try_table` separate instead of pretending there is one generic dead-result rule.
- Preserve the EH nested-pop repair trigger exactly: `hasPop && addedBlock`.
- Do not over-implement the pass as a generic effect-driven dead-result optimizer unless the source oracle changes.
