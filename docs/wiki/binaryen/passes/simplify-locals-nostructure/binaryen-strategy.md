---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md
  - ../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md
related:
  - ./index.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `simplify-locals-nostructure` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is the shared `src/passes/SimplifyLocals.cpp` template.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inlining helper in `src/passes/opt-utils.h`.
- The key helper contracts come from:
  - `src/ir/local-utils.h`
  - `src/ir/effects.h`
  - `src/ir/equivalent_sets.h`
  - `src/ir/linear-execution.h`
  - `src/ir/properties.h`
- The shipped behavior examples come from the dedicated no-structure and nearby-variant tests under `test/passes/`.
- The reviewed official Binaryen `version_129` release page rechecked on 2026-04-22 showed publish date **2026-04-01**, and a narrow same-day `main` spot check on `SimplifyLocals.cpp`, `pass.cpp`, `passes.h`, `opt-utils.h`, and the dedicated no-structure test files did not surface a new teaching-relevant drift beyond the current dossier claims. See [`../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md).

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>

## High-level intent

Binaryen uses `simplify-locals-nostructure` to remove early local traffic without creating new structured return values yet.

That sentence is true but incomplete.

The actual implementation is the shared simplify-locals engine with one specific capability turned off.

It is not:

- the same as `simplify-locals-notee`
- the same as `simplify-locals-nonesting`
- just a dead-set remover
- a whole-function CFG local optimizer
- the full late `simplify-locals` pass

Instead, the real `version_129` contract is:

- keep tee creation enabled
- keep nesting into existing expression positions enabled
- disable the block / `if` / loop return-building family
- still run the late equivalent-get canonicalization
- still run the final dead-set cleanup

## Variant identity is the first important fact

The shared implementation instantiates this public pass as:

- `SimplifyLocals<true, false, true>`

That means:

- `allowTee = true`
- `allowStructure = false`
- `allowNesting = true`

Those three facts are more informative than the CLI name by itself.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Variant gate | Instantiate `SimplifyLocals<true, false, true>` | Keep teeing and ordinary sink nesting, but delay structure-building rewrites |
| Count gets | Use `LocalGetCounter` before the fixpoint | Distinguish single-use sinks, later tee candidates, and dead locals |
| First-cycle sink pass | Only sink easy single-use locals | Grab common compiler-output wins before teeing complicates shapes |
| Later-cycle sink passes | Allow tee creation for multi-use locals | Remove more local traffic after the easy cases stabilize |
| Invalidate conservatively | Use directional effect ordering plus explicit `try` / `try_table` guards | Avoid reordering across conflicting locals, globals, memory, tables, traps, throws, or dangling `pop` |
| Skip structure rewrites | Do not call the block / `if` / loop return helpers | Leave new structured return values for the later full pass |
| Late equivalent-get cleanup | Canonicalize `local.get`s toward a better equivalent local | Improve type precision and reduce future get counts without deleting structured copy carriers |
| Final dead-set cleanup | Run `UnneededSetRemover` | Remove now-dead or same-value sets even outside neat SSA regions |
| Repair | Run `ReFinalize` when needed | Restore correct outer expression types after refined values become visible |

## Phase 1: get counting drives the whole pass

`LocalGetCounter` from `local-utils.h` counts how many `local.get`s each local still has.

That count is not bookkeeping noise.
It determines:

- whether a write has only one future use and can inline directly
- whether a later cycle may need a tee for the first use
- whether a local now has zero reads and can be cleaned up by the late sweep

That is why this pass is more than a tiny adjacent set/get peephole.

## Phase 2: the fixpoint deliberately starts with a stricter cycle

`doWalkFunction(...)` begins with `firstCycle = true` and then iterates until no useful main or late optimizations remain.

On that first cycle:

- `canSink(...)` rejects a set with more than one use
- so the pass only performs single-use sinks
- then Binaryen forces another cycle even if the first one looked done

Later cycles can then create tees because `allowTee = true`.

That split is part of the upstream algorithm, not an incidental micro-optimization.

## Phase 3: the main scan is linear-trace based

The pass inherits from `LinearExecutionWalker` and keeps a current map of pending sinkable sets:

- `sinkables : local index -> SinkableInfo`

It also tracks conservative control-flow state with:

- `blockBreaks`
- `unoptimizableBlocks`
- `ifStack`

The durable takeaway is that the pass reasons about:

- one current linear trace
- with explicit resets or small merges at non-linear boundaries

It is not a full CFG + dominance pass.

## Phase 4: `local.get` has two main positive rewrite outcomes

When `optimizeLocalGet(...)` finds a pending sinkable set for the same local, the rewrite depends on get count.

### Single-use case

If the local has one use in the current cycle:

- replace the `local.get` with the set’s value
- turn the old set origin into `nop`
- erase the pending sinkable

If the replacement value has a more refined type than the original get, Binaryen records `refinalize = true`.

### Multi-use case

If the local has multiple uses, teeing is enabled, and this is not the first cycle:

- replace the `local.get` with the `local.set`
- convert that set into a `local.tee`
- nop the old origin
- erase the pending sinkable

This is why no-structure still meaningfully differs from `simplify-locals-notee-nostructure`.

## Phase 5: `drop(tee(...))` is immediately cleaned up

Sinking a multi-use set into a dropped first use can create:

- `drop(local.tee ...)`

`visitDrop(...)` immediately turns that back into:

- `local.set ...`

That cleanup is small, but it is part of the real visible output boundary.

## Phase 6: overwritten pending sets become dead

During `visitPost(...)`, if a later set writes to a local that already has a pending sinkable set, the old pending write is dead.

Binaryen then:

- converts the old set into `drop(oldValue)`
- removes the old pending sinkable entry
- continues scanning with the newer write as the live candidate

So the pass also performs overwrite cleanup on a linear trace, not just set/get sinking.

## Phase 7: invalidation uses directional effect ordering

`checkInvalidations(...)` compares each pending sinkable against the current effects using:

- `effects.orderedAfter(info.effects)`

This is the main safety boundary.

It blocks motion across conflicts such as:

- local reads and writes
- mutable-global reads and writes
- memory and table access conflicts
- shared-memory ordering constraints
- control-flow transfer
- trap versus global-state mutation hazards
- dangling `pop`

A faithful port should preserve this directional barrier idea instead of collapsing it into one generic “has side effects” bit.

## Phase 8: `try` / `try_table` has an extra explicit throwing-value barrier

In `visitPre(...)`, when the current node is `Try` or `TryTable`, Binaryen drops any pending sinkable whose value may throw.

Reason:

- moving that value into the `try` would change where the throw could be caught

This is a pass-specific correctness rule worth preserving explicitly.

## Phase 9: what no-structure disables

The shared implementation contains these structure-building helpers:

- `optimizeLoopReturn(...)`
- `optimizeBlockReturn(...)`
- `optimizeIfElseReturn(...)`
- `optimizeIfReturn(...)`

Those helpers are only called when `allowStructure` is true.

So in `simplify-locals-nostructure`, Binaryen deliberately does **not** create new:

- loop result carriers
- block result carriers
- `if (result ...)` or `if-else (result ...)` carriers extracted from local traffic
- speculative one-armed `if` else-side `local.get`s

That is the defining semantic limit of this variant.

## Phase 10: the late equivalent-local phase still runs here

After the main sink loop stabilizes, `runLateOptimizations(...)` executes `EquivalentOptimizer`.

Important facts:

- it tracks equivalences between locals holding the same value
- it canonicalizes later `local.get`s toward a better representative
- “better” means either:
  - more refined local type
  - or more total gets remaining
- it sets `connectAdjacentBlocks = true`, so this late phase is slightly more permissive across adjacent block structure than the main sink walk

This is why the no-structure variant still does meaningful late cleanup.

## Phase 11: but equivalent-set deletion is still off here

`EquivalentOptimizer` also has:

- `removeEquivalentSets = allowStructure`

So in the no-structure variant:

- get canonicalization is **on**
- removing redundant equivalent copy sets is **off**

That subtle fact is one of the easiest things to miss when skimming only the pass name.

## Phase 12: `UnneededSetRemover` still finishes the pass

After the equivalent-local phase, Binaryen still runs `UnneededSetRemover` from `local-utils.h`.

That helper removes:

- sets whose local now has zero gets
- sets or tees that simply write back the same local value
- tee chains that collapse to the same local

It preserves side effects carefully:

- dead pure `local.set` -> `nop`
- dead effectful `local.set` -> `drop(value)`
- dead `local.tee` -> raw value

So even the no-structure variant has a real “finish the obvious leftovers” phase.

## Phase 13: `ReFinalize` is mandatory when types get sharper

The pass refinalizes when:

- a single-use sink exposes a more refined value type than the old `local.get`
- equivalent-get canonicalization switches a get to a more refined local
- dead-tee cleanup exposes a more refined inner value

That matters especially in ref-typed code, where a more refined child can change the visible type expectations of surrounding users.

## Helper dependency map

## `LocalGetCounter`

- Counts `local.get`s.
- Decides single-use versus later tee behavior.
- Lets the final cleanup find zero-use locals.

## `LinearExecutionWalker`

- Gives the pass its cheap linear-trace model.
- Notifies the pass at non-linear boundaries.
- Keeps the first implementation smaller than a CFG-based solver.

## `EffectAnalyzer`

- Implements the directional barrier model.
- Handles locals, globals, memory, tables, shared-memory order, control transfer, traps, throws, and dangling `pop`.
- Supports the explicit `try` / `try_table` throwing-value guard.

## `EquivalentSets`

- Tracks which locals currently hold the same value in the late phase.
- Supports get canonicalization and, in other variants, redundant copy-set removal.

## `Properties::getFallthrough(...)`

- Lets the late phase look through trivial wrappers when checking for same-value copies.

## `UnneededSetRemover`

- Performs the final dead-set cleanup outside a tidy SSA-only world.
- Preserves effects while erasing dead or same-value local traffic.

## `ReFinalize`

- Repairs outer expression types after refined values become visible.

## Scheduler placement is part of the meaning

In `pass.cpp`, Binaryen schedules `simplify-locals-nostructure` in the default no-DWARF function pipeline:

- after `code-pushing`
- after `tuple-optimization`
- before `vacuum`
- before the first `reorder-locals`

That placement says a lot about intended use:

- earlier branch and tuple cleanup may expose cleaner local traffic
- the no-structure pass removes early local clutter without committing to structural return rewrites
- `vacuum` can then delete the garbage it leaves behind
- `reorder-locals` benefits from the cleaner local set
- much later, after `coalesce-locals` and `local-cse`, full `simplify-locals` may finish the structure-sensitive cleanup

`opt-utils.h` then shows that after-inlining cleanup prepends `precompute-propagate` and reruns the default function optimization pipeline on touched functions, which means `simplify-locals-nostructure` also reappears under optimizing passes like `dae-optimizing` and `inlining-optimizing`.

## What the pass does **not** do

A future Starshine port should avoid accidentally broadening this pass beyond upstream behavior.

`simplify-locals-nostructure` does **not**:

- disable tee creation
- disable nesting into existing expression positions
- build new block / `if` / loop return values
- run the speculative one-armed `if` return-lifting family
- remove equivalent copy sets the same way the full structured variant can
- solve arbitrary CFG local propagation
- skip the final dead-set cleanup
- skip refinalization when refined values become visible

The real Binaryen contract is narrower and more variant-specific than the name suggests.

## The most important porting lessons

If Starshine ports `simplify-locals-nostructure`, preserve these facts first:

1. exact variant identity: `allowTee = true`, `allowStructure = false`, `allowNesting = true`
2. first-cycle single-use-only rule
3. later tee creation for multi-use locals
4. linear-trace sink state with conservative resets
5. directional effect invalidation
6. explicit `try` / `try_table` throwing-value barrier
7. no block / `if` / loop return synthesis
8. late equivalent-get canonicalization still enabled
9. equivalent-set deletion still disabled
10. final dead-set cleanup still enabled
11. mandatory `ReFinalize`
12. scheduler placement before `vacuum` / `reorder-locals` and before full `simplify-locals`

Those are the durable upstream-level truths.

## Sources

- [`../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md)
- [`../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`](../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- Binaryen `version_129` dedicated tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
