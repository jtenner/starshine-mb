---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md
  - ../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md
  - ../../no-dwarf-default-optimize-path.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/localize.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./pattern-catalog.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `remove-unused-brs` strategy

This page is the source-backed answer to four questions:

1. what phases does upstream `RemoveUnusedBrs.cpp` actually contain?
2. which helpers and analyses are part of the real algorithm?
3. why does Binaryen run the pass multiple times in the scheduler?
4. what safety rules are easy to misunderstand?

## Upstream source rule

Treat Binaryen `version_129` as the normative release oracle for this page.

The core source stack is:

- `src/passes/RemoveUnusedBrs.cpp`
- `src/passes/pass.cpp`
- helper headers in `src/ir/`

The earlier archived comparison note is still useful, but this page is now grounded directly in the official `version_129` source structure rather than only in that earlier distillation.

## Scheduler placement matters

`pass.cpp` registers `remove-unused-brs` as a public pass and places it three times in the canonical no-DWARF `-O` / `-Os` function pipeline:

1. after the early `remove-unused-names`
2. again after `vacuum -> reorder-locals`
3. again after `merge-blocks`

The nearby comments in `pass.cpp` are part of the real pass story:

- `merge-blocks` makes `remove-unused-brs` more effective
- later `coalesce-locals` opens opportunities for another `remove-unused-brs`
- late `remove-unused-names` then benefits from that cleanup
- another `merge-blocks` cleans up the new blocks late RUB can create

So RUB is intentionally rerun because surrounding passes expose new branch shapes for it.

## Big picture: RUB is staged, not monolithic

The easiest correct mental model is:

1. track plain flowing exits and erase the ones that already land at the surrounding continuation
2. do a few direct control rewrites while that flow knowledge is fresh
3. reshape loops and blocks so more exits become obvious
4. run a separate GC branch optimizer
5. thread trivial jumps after the main shape settles
6. finish with a late optimizer for `br_if`, `br_table`, `select`, and local-set families

That is why a shallow summary like “removes unused breaks” undersells the real algorithm.

## Phase 0: shared state and pass options

The pass class keeps a small amount of explicit walker state:

- `anotherCycle`
- `neverUnconditionalize`
- `flows`
- `ifStack`
- `loops`
- `catchers`

Those fields matter because they show what the pass is **not**:

- not a generic CFG dataflow pass
- not an SSA pass
- not a liveness pass in the local-variable sense

Instead, it is a custom postwalk with a few targeted stacks and repeated local cleanup cycles.

`neverUnconditionalize` is especially important.
Binaryen uses it so branch-hint fuzzing can forbid transforms that would make previously conditional work execute unconditionally.
That is an official pass behavior, not just a local testing convenience.

## Phase 1: main flow cleanup fixpoint

The first major stage is the custom walk built around:

- `visitAny(...)`
- the pass-specific `scan(...)`
- `doWalkFunction(...)`

The core idea is simple:

- when a plain `br` or `return` is currently flowing straight to the surrounding continuation, it is redundant
- Binaryen records those flowing exits and removes them when the proof closes

Important details from the source:

- plain `br` with no value can become `nop`
- plain `br` with a value can become just that value
- `return` can similarly become `nop` or its value
- `if` without `else` stops value flow
- `if` with `else` merges arm-flow vectors carefully
- `none`-typed or unreachable-heavy shapes stop value flow in specific ways
- trailing `nop` at the end of a block is removed early because it blocks value flow for no semantic reason

This is the part of RUB that most closely matches the pass name.
It is also only the first part.

## Phase 2: early in-walk rewrites

The same broad stage also performs targeted rewrites that are easier before the later helper passes.

### Early `switch` cleanup

`optimizeSwitch(...)` handles easy switch families before the later final optimizer:

- trim trailing default targets
- remove leading default targets by offsetting the condition
- collapse a switch with only one real target into `br`
- collapse a two-option switch into `if`
- collapse very large mostly-default switches into nested `if` structure when that pays off

### Early one-arm `if` cleanup

The main `visitIf(...)` already handles:

- one-arm `if { br }` to `br_if`
- one-arm `if { br_if }` by combining conditions with `select`
- nested one-arm condition folding

Those rewrites are guarded by:

- effect safety
- cost of unconditional execution
- multivalue limitations
- `neverUnconditionalize`

### Early `throw` to `br`

`visitThrow(...)` is an easy surface to miss if you only read the pass name.

When a `throw` is definitely caught by an enclosing `try_table` catch destination, and that catch does **not** transport `exnref`, Binaryen can rewrite the throw into a branch-like form:

- exact caught tag -> `br` with payload when needed
- `catch_all` without ref -> `br` plus dropped children as needed

Important boundaries:

- `catch_ref` and `catch_all_ref` are negative cases
- mixed old `Try` and `TryTable` control is intentionally not optimized here

So old-EH cleanup is a real part of RUB's upstream contract.

## Phase 3: loop cleanup

After each main walk cycle, RUB revisits recorded loops using `optimizeLoop(...)`.

The goal is not generic loop simplification.
It is specifically to expose removable exits.

Typical pattern:

- a loop body ends in a simple `br $loop`
- an earlier `if` or `br_if` decides whether to exit elsewhere
- RUB can move the trailing slice into an arm, or flip a nearby `br_if`
- once that happens, an outer branch to the exit block may become redundant and disappear in a later cycle

Important source-backed conditions:

- loop must be named
- body must be a block
- the trailing branch to the loop top must be simple
- intervening control-flow transfer blocks the transform
- some cases use `BranchSeeker::count(...)` to require a single-use-enough target before restructuring

## Phase 4: block sinking

`sinkBlocks(...)` is another stage that sounds cosmetic until you read the source.

It moves named exit blocks inward when they currently wrap only:

- one loop
- or one `if`

Why that matters:

- later branch cleanup works better when the relevant label is closer to the interesting branch
- the transform is therefore about enabling later cleanup, not about deleting a branch immediately

Important safety checks:

- if the `if` condition is unreachable, leave it alone for DCE
- the outer label cannot be used in the `if` condition
- Binaryen only sinks into an arm that does not already use that outer label

## Phase 5: GC-specific BrOn cleanup

`optimizeGC(...)` is a separate postwalk pass run after the main fixpoint.

It handles:

- `br_on_null`
- `br_on_non_null`
- `br_on_cast`
- `br_on_cast_fail`
- descriptor variants of `br_on_cast*`

Key helper dependencies here:

- `Properties::getFallthroughType(...)`
- `GCTypeUtils::evaluateCastCheck(...)`
- `ChildLocalizer`
- `getDroppedChildrenAndAppend(...)`
- `ReFinalize`

Typical outcomes:

- branch definitely taken -> plain `br`
- branch definitely not taken -> `drop` or plain fallthrough value
- known cast success -> `br`
- known cast failure -> plain fallthrough value
- success-only-if-non-null -> `br_on_non_null` plus appended `ref.null`
- unreachable input -> dropped children plus `unreachable`

Important beginner correction:

- GC branch cleanup is not a separate Binaryen pass here
- it is explicitly part of `RemoveUnusedBrs.cpp`

## Phase 6: jump-threading

After the main fixpoint and GC cleanup, RUB runs a dedicated `JumpThreader`.

This stage:

- collects scope-name uses with `operateOnScopeNameUsesAndSentTypes(...)`
- retargets branches through simple named block shells
- redirects unconditional jumps to where the child block itself immediately jumps
- can turn unconditional jumps to a child whose next step is `unreachable` into direct `unreachable`

The 2026-05-05 current-main recheck stayed aligned with that already-tracked drift note:

- in `version_129`, one-child named-block redirection requires the child block type to equal the parent block type
- current `main` still omits that type-equality guard on the reviewed surface

That is still a small but real drift worth preserving explicitly in the wiki.

## Phase 7: final optimizer

The late `FinalOptimizer` stage owns many of the most visible WAT-shape rewrites.

### Block-end `if br else br`

It can rewrite a block-tail `if` whose arms end in plain breaks into:

- `br_if` for one arm
- followed by the other arm's fallthrough body

### Adjacent `br_if` merge

When shrinking, adjacent `br_if` to the same target can merge into one `br_if` with `i32.or` on the conditions, but only when executing the later condition unconditionally is safe.

### `tablify(...)`

Binaryen recognizes dense runs of:

- `br_if target (i32.eq value const)`
- or `br_if target (i32.eqz value)`

and converts them into one `br_table` wrapped in a fresh named block, provided:

- the tested value is safe enough to share
- the constants are unique
- the range is dense enough
- there are enough arms to matter
- there are no branch values to complicate emission

### `restructureIf(...)`

This is the late block-exit family the older comparison note highlighted.

Canonical form:

- named block
- first instruction is `drop(br_if $same_block ...)` or `br_if $same_block ...`
- no other branch targets that block

Positive outcomes:

- replace the whole block with `if`
- or replace it with `select`

Negative boundaries:

- side-effectful payload values
- reorder-unsafe condition/value pairs
- `neverUnconditionalize`
- too-costly unconditional execution

### `selectify(...)`

Binaryen turns a pure two-arm `if` into `select` only when:

- both arms are emit-select-compatible
- the condition is not unreachable
- both arms are side-effect free
- the condition does not invalidate either arm
- the cost model allows unconditional execution at the current shrink level

### `optimizeSetIf(...)`

This late stage also owns `local.set` / `local.tee` of an `if` result.
It can:

- extract a branch arm as `br_if` plus later set
- remove a copy arm when one arm is `local.get` of the same target local

### Constant-condition branch cleanup

Finally, RUB looks at `br_if` whose condition fallthrough is known constant and can turn them into:

- unconditional `br`
- or plain fallthrough, possibly keeping a branch value

That stage may force `ReFinalize` because block and expression types can change.

## Analysis and helper dependency story

RUB depends heavily on a small set of helper families.

### Branch helpers

From `branch-utils.h`:

- `BranchSeeker`
- `replacePossibleTarget(...)`
- `operateOnScopeNameUsesAndSentTypes(...)`
- `getUniqueTargets(...)`

These power:

- single-target proofs
- jump-threading
- branch retargeting
- switch simplification

### Effect and cost helpers

From `effects.h` and `cost.h`:

- `EffectAnalyzer`
- `AtomicCost`
- `ThrowCost`
- `CastCost`
- `TooCostlyToRunUnconditionally`

These decide when Binaryen is willing to replace branching with unconditional work.

### Shape and child helpers

From `properties.h`, `drop.h`, and `localize.h`:

- `Properties::canEmitSelectWithArms(...)`
- `Properties::getFallthrough(...)`
- `Properties::getFallthroughType(...)`
- `getDroppedChildrenAndAppend(...)`
- `ChildLocalizer`

These are what make the GC, constant-condition, and control-preserving rewrites valid.

### Branch-hint metadata helpers

From `branch-hints.h`:

- `copyTo`
- `copyFlippedTo`
- `applyAndTo`
- `applyOrTo`
- `flip`

Official branch-hints tests prove this metadata preservation is part of the pass contract.

## What is easy to misunderstand

### Misunderstanding 1: “RUB is only about dead exits.”

Wrong because the pass also:

- builds `br_table`
- builds `select`
- restructures `local.set(if ...)`
- rewrites caught `throw`
- simplifies BrOn GC control

### Misunderstanding 2: “RUB is just structural pattern matching.”

Wrong because many transforms depend on:

- effect invalidation
- unconditionalization cost
- branch-hint policy
- select-emission legality
- type refinalization

### Misunderstanding 3: “Later cleanup is just polish.”

Wrong because some of the most important Binaryen-visible shapes are only handled in the late `FinalOptimizer` stage after earlier flow cleanup has exposed them.

## Practical rule for Starshine work

When a new parity gap appears, ask these in order:

1. Is it an early flow-cleanup miss?
2. Is it a loop or block-shaping miss?
3. Is it GC or EH-specific RUB behavior?
4. Is it a late final-optimizer family like `tablify`, `restructureIf`, `selectify`, or `optimizeSetIf`?
5. Or is it a local HOT/lower/writeback issue around a function where local RUB reports `changed=false`?

That question order is much closer to the real Binaryen implementation than the older shorthand “dead branch cleanup” label.

## Sources

- [`../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-remove-unused-brs-current-main-recheck.md)
- [`../../../raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md`](../../../raw/research/0461-2026-05-05-remove-unused-brs-current-main-recheck.md)
- [`../../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md`](../../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md)
- [`../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md`](../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/localize.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
