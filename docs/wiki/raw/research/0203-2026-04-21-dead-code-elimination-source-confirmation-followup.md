# Binaryen `dead-code-elimination` source-confirmation follow-up (`version_129`)

Date: 2026-04-21
Status: completed follow-up
Pass: `dead-code-elimination` / upstream `dce`

## Why this follow-up existed

The pass tracker no longer had obvious `none` targets, so this thread needed a justified major-gap follow-up rather than a first-pass dossier.
`dead-code-elimination` was a good candidate because the existing local folder was deep enough to be useful, but it still lacked one compact source-confirmed implementation/test-map page and, more importantly, it still taught an over-broad model of the upstream pass.

The old living pages described Binaryen `version_129` `dce` as if it had:

- helper block-target walkers,
- `EffectAnalyzer`-driven dead-result pruning,
- a dedicated `visitDrop(...)` engine,
- broad typed-control voidification,
- `Flatten::flatten(...)`,
- `ReFinalize`, and
- nondefaultable-local repair.

A direct reread of the real `version_129` source showed that story was wrong.

## Canonical sources consulted

### Official Binaryen sources

- `src/passes/DeadCodeElimination.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/dce_all-features.wast`
- `test/lit/passes/dce_vacuum_remove-unused-names.wast`
- `test/lit/passes/dce-eh.wast`
- `test/lit/passes/dce-eh-legacy.wast`
- `test/lit/passes/dce-stack-switching.wast`

### Local Starshine context

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/dead-code-elimination/`
- `agent-todo.md`

## Agent-todo slice check

`agent-todo.md` **does** have dedicated DCE slices.
The relevant live backlog is still under `DCE - Dead Code Elimination`, including:

- `[DCE]001 - Binaryen-Shape Cleanup Hardening`
- `[DCE]002 - Prefix Regression and Artifact Replay`
- `[DCE]003 - Runtime Budget and Oracle Refresh`

So this pass remains directly connected to active implementation work.

## Main finding: the old folder overstated the pass

The real `version_129` implementation is a small function-parallel postwalk centered on `TypeUpdater`.

What the pass actually does:

- walks each function body in postorder,
- tracks replacements/removals with `TypeUpdater`,
- for non-control expressions with type `unreachable`, preserves earlier children as `drop`s, keeps the first unreachable child, and removes later children,
- trims block suffixes after the first unreachable child,
- changes some `block` / `if` / `try` / `try_table` node types to `unreachable`,
- replaces `loop` with its body only in the fully-dead-body case,
- and runs `EHUtils::handleBlockNestedPops(...)` only when the function both contains `pop` and DCE added blocks.

What the pass does **not** do in `DeadCodeElimination.cpp`:

- no `BranchSeeker`
- no `UnneededBlockSeeker`
- no `EffectAnalyzer`
- no `canRemove(...)`
- no dedicated `visitDrop(...)`
- no broad dead-result simplifier
- no `Flatten::flatten(...)`
- no `ReFinalize`
- no `TypeUpdater::handleNonDefaultableLocals(...)`

That is the central durable correction from this follow-up.

## Real implementation structure

### Pass shell

`DeadCodeElimination` is declared as a `WalkerPass<PostWalker<...>>` and is function-parallel.

Two small pass-level properties matter:

- `isFunctionParallel() -> true`
- `requiresNonNullableLocalFixups() -> false`

So the pass does not ask the pass runner for later non-nullable-local cleanup.

### State

The real state is tiny:

- `TypeUpdater typeUpdater`
- `bool hasPop`
- `bool addedBlock`

### Function setup

`doWalkFunction(...)` first lets `typeUpdater.walk(func->body)` seed the rewrite bookkeeping, then performs the postwalk.

### Expression visitor

Almost all behavior lives in `visitExpression(...)`, split into:

- non-control expressions
- control-flow structures (`block`, `if`, `loop`, `try`, `try_table`)

### End-of-function repair

`visitFunction(...)` only performs one repair:

- if `hasPop && addedBlock`, run `EHUtils::handleBlockNestedPops(curr, *getModule())`

That narrowness is important.
The old folder implied a much broader end-of-pass repair pipeline than the source actually has.

## Actual algorithm notes by shape

### Non-control expressions

If a non-control node has type `unreachable`, DCE scans its children.
If one child is unreachable, then:

- all earlier children are preserved as `drop child`
- the first unreachable child is kept as-is
- all later children are recursively removed
- if more than one item survives, DCE builds a new block

This is the main expression-level rewrite surface.

### Blocks

For `block`, DCE:

1. finds the first child with type `unreachable`
2. removes the suffix after that child
3. collapses a one-item block containing only `unreachable` to that child
4. changes block type to `unreachable` if the block still had a concrete type, now ends in `unreachable`, and has no incoming `break`s according to `TypeUpdater`

### Ifs

For `if`, DCE handles two exact cases:

- condition unreachable -> remove arms, replace whole `if` with condition
- both arms unreachable -> change `if` type to `unreachable`

### Loops

For `loop`, only the strongest dead-body case is handled:

- if the body node itself is literal `unreachable`, replace the loop with the body

The source comment explicitly warns that loop bodies can have unreachable type for normal looping reasons, so DCE stays conservative.

### `try` and `try_table`

For legacy `try`, DCE changes the node type to `unreachable` only if:

- the body is unreachable, and
- every catch body is unreachable

For `try_table`, DCE changes the node type to `unreachable` if the body is unreachable.

## What the lit tests prove

### `dce_all-features.wast`

This is the big ordinary-contract file.
It proves:

- block suffix trimming after `br`, `br_if`, `br_table`, `return`, and `unreachable`
- one-child block collapse to `unreachable`
- non-control unreachable-child rewrites that preserve earlier children as `drop`s
- `if` condition-unreachable collapse
- both-arms-unreachable `if` type collapse
- fully-dead loop body replacement

### `dce_vacuum_remove-unused-names.wast`

This file proves the intended pass neighborhood.
It is strong evidence that DCE is expected to expose opportunities for:

- `vacuum`
- `remove-unused-names`

rather than subsume those passes.

### `dce-eh.wast`

This file covers the modern EH surface:

- `try_table` reachability
- reachable-vs-unreachable catches
- dead wrappers around `throw` / `throw_ref`

### `dce-eh-legacy.wast`

This is the key file for the `pop` story.
It shows why DCE's only explicit function-end repair is `handleBlockNestedPops(...)`: newly created blocks can otherwise leave nested `pop`s in invalid positions.

### `dce-stack-switching.wast`

This file proves that a surrounding `drop` does **not** automatically kill a handler block's typed-label contract.
Stack-switching handlers can still branch to the block, so DCE must preserve that liveness boundary.

## Scheduler and neighborhood conclusions

`pass.cpp` still places `dce` immediately after `ssa-nomerge` in the no-DWARF default function pipeline.
Together with the combo lit file, that supports a narrower teaching story:

- `dce` is an early unreachable-shape cleanup pass
- `vacuum` and `remove-unused-names` remain real downstream cleanup owners

## Current-main drift check

A direct diff between:

- `version_129/src/passes/DeadCodeElimination.cpp`
- `main/src/passes/DeadCodeElimination.cpp`

showed no textual drift.
So the source-confirmed corrections above should be treated as current until a later upstream change lands.

## Documentation changes this follow-up should drive

1. Add a dedicated implementation/test-map page.
2. Rewrite the landing page so it no longer describes the pass as broad effect-driven dead-result cleanup.
3. Rewrite the strategy page around `TypeUpdater`, control-vs-non-control handling, and the narrow EH fixup.
4. Rewrite the typed-control page so it talks about type-to-`unreachable` changes rather than generic voidification.
5. Rewrite the WAT-shape page so it reflects the real unreachable-child/block-suffix/type-collapse surface.
6. Update tracker and index summaries so future threads do not pick this same gap again.

## Porting lessons for Starshine

If Starshine wants Binaryen-shaped DCE, it should preserve:

- child-first function-local rewrite order
- non-control unreachable-child rewrites that keep earlier children as `drop`s
- dead-suffix trimming after the first unreachable child in blocks
- break-target-aware block type collapse to `unreachable`
- the exact separate special cases for `if`, `loop`, `try`, and `try_table`
- the precise `hasPop && addedBlock` condition for EH nested-pop repair

And it should **not** silently port a much broader imagined DCE under the same name.
