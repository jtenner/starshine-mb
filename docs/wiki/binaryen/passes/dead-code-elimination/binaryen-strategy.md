---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-dead-code-elimination-current-main-recheck.md
  - ../../../raw/research/0449-2026-05-05-dead-code-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md
  - ../../../raw/research/0134-2026-04-20-dead-code-elimination-binaryen-research.md
  - ../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadCodeElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_vacuum_remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-stack-switching.wast
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./typed-control-voidification-and-eh.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `dead-code-elimination` strategy

## Major correction

A direct `version_129` source reread shows that Binaryen `dce` is much narrower than the older local dossier claimed.

It is **not** a broad effect-driven dead-result optimizer with helper block-target walkers, dedicated `visitDrop(...)` logic, flattening, and refinalization.

It is a small function-parallel postwalk that:

- trims dead suffixes after the first unreachable child,
- preserves earlier still-executing children by turning them into `drop`s when needed,
- changes some control-flow node types to `unreachable` when their concrete result type is no longer justified,
- and runs a narrow EH nested-pop fixup only when it introduced blocks into a function that contains `pop`.

## Upstream source rule

Use Binaryen `version_129` as the source oracle for this pass.

Primary files:

- `src/passes/DeadCodeElimination.cpp`
- `src/passes/pass.cpp`

Primary dedicated tests:

- `test/lit/passes/dce_all-features.wast`
- `test/lit/passes/dce_vacuum_remove-unused-names.wast`
- `test/lit/passes/dce-eh.wast`
- `test/lit/passes/dce-eh-legacy.wast`
- `test/lit/passes/dce-stack-switching.wast`

The reviewed official Binaryen GitHub `version_129` release page was re-checked on 2026-04-22 and showed publish date **2026-04-01**.
A 2026-05-05 current-main recheck found no teaching-relevant drift between `version_129` and current `main` in `src/passes/DeadCodeElimination.cpp`.

## Public pass identity and placement

`pass.cpp` registers:

- `dce`
  - description: `removes unreachable code`

That short description is plain, but accurate.
The file really is centered on unreachable-shape cleanup.

In the canonical no-DWARF default function pipeline, Binaryen places it here:

- `ssa-nomerge -> dce -> remove-unused-names -> remove-unused-brs -> ...`

That scheduler position matters because DCE is an early cleanup pass, not a final simplifier.
The dedicated combo lit file with `vacuum` and `remove-unused-names` reinforces that point.

## Pass shell

Binaryen implements `dce` as one:

- `WalkerPass<PostWalker<...>>`

Key pass-level properties:

- `isFunctionParallel() = true`
- `requiresNonNullableLocalFixups() = false`

That second point is another correction to the older dossier.
The file does **not** ask the pass runner for later non-nullable-local fixups here.

## The real helper stack

### `TypeUpdater`

This is the main stateful helper in the pass.
It is used to:

- initialize rewrite bookkeeping before walking a function body,
- note replacements when expressions are swapped,
- note recursive removals when dead subtrees are trimmed away,
- check whether a block still has incoming `break`s,
- and change expression types to `unreachable` when that is now justified.

If you remember only one helper for this pass, remember `TypeUpdater`.

### `EHUtils::handleBlockNestedPops(...)`

This is the only explicit end-of-function repair in the file.
Binaryen runs it only if both are true:

- the function contains `pop`, and
- DCE created at least one new block while simplifying

That means EH repair is real, but narrowly scoped.

## The actual algorithm

## 1. Seed `TypeUpdater`, then do a child-first walk

`doWalkFunction(...)` first lets `TypeUpdater` walk the body, then runs the postwalk over the same body.
So the pass is designed around local rewrite bookkeeping from the start.

## 2. Non-control expressions: keep what executes, drop what becomes dead

If the current node is **not** a control-flow structure and has type `unreachable`, DCE checks whether one child is already unreachable.

If so:

- children before the first unreachable child are preserved as `drop child`
- the first unreachable child is kept as-is
- later children are recursively marked removed
- if multiple preserved pieces remain, DCE wraps them in a fresh block

This is the main source-backed meaning of the pass name.
It does not ask whether those earlier children are effect-free.
It simply preserves the parts that still execute before control becomes unreachable.

## 3. `block`: trim the suffix, maybe collapse type to `unreachable`

For `block`, DCE scans the child list for the first unreachable child.
If one exists:

- everything after it is recursively removed
- the block list is truncated at that point
- a one-item block containing only literal `unreachable` is replaced by that child directly

Then DCE applies one more rule:

- if the block still has a concrete type,
- its last surviving child is unreachable,
- and `TypeUpdater` sees no `break`s targeting it,
- change the block type to `unreachable`

This is not generic block elimination.
It is suffix trimming plus type correction.

## 4. `if`: unreachable condition or both-unreachable arms

For `if`, DCE has only two special cases.

### Unreachable condition

If the condition itself is unreachable:

- recursively mark both arms removed
- replace the entire `if` with the condition

### Both arms unreachable

If the `if` has an `else`, is not already unreachable, and both arms are unreachable:

- change the `if` type to `unreachable`

That is narrower than “dead branch simplification.”
It is about expressing the now-proven control result type honestly.

## 5. `loop`: only the fully-dead-body case

Loops can legitimately have an unreachable-typed body for ordinary control-flow reasons, such as looping back to the top.
So Binaryen only handles the simplest case here:

- if the body is literal `unreachable`, replace the loop with the body

## 6. `try` and `try_table`: narrow EH reachability rules

### `try`

If the try body is unreachable and **all** catch bodies are unreachable, DCE changes the node type to `unreachable`.

### `try_table`

If the body is unreachable, `try_table` cannot finish normally either, so DCE changes its type to `unreachable`.

The dedicated EH lit files are what make these rules easy to trust and easy to teach.

## 7. End-of-function EH repair is conservative and conditional

`visitFunction(...)` does exactly one repair:

- if the function had `pop` and the pass added a block, run `EHUtils::handleBlockNestedPops(...)`

The legacy EH lit file shows why this matters: adding blocks can move `pop` into invalid nested positions, so DCE cleans up only that exact hazard.

## What the real source does **not** support

These older local claims are not part of the actual `version_129` pass:

- no `BranchSeeker`
- no `UnneededBlockSeeker`
- no `EffectAnalyzer`
- no `canRemove(...)`
- no dedicated `visitDrop(...)`
- no general typed-control voidification engine
- no `Flatten::flatten(...)`
- no `ReFinalize`
- no `handleNonDefaultableLocals(...)`

Those ideas may be relevant to neighboring passes, but they are not Binaryen `dce` as shipped in `version_129`.

## Beginner-safe summary

A safer beginner summary is:

- Binaryen `dce` is an early unreachable-shape cleanup pass.
- It preserves still-executing earlier children with `drop`s when a later child makes an expression unreachable.
- It trims dead suffixes in blocks.
- It updates the type of some control nodes to `unreachable` when their concrete result is no longer real.
- It performs only one narrow EH repair at function end.

That is smaller, and more accurate, than the older story.

## Porting invariants

A future Starshine port should preserve these exact source-backed rules:

- walk children first
- treat non-control and control structures differently
- preserve earlier still-executing children as `drop`s before the first unreachable child
- remove later siblings after the first unreachable child
- use break-target knowledge before changing a block type to `unreachable`
- keep the `if`, `loop`, `try`, and `try_table` special cases distinct
- run EH nested-pop repair only when `hasPop && addedBlock`
