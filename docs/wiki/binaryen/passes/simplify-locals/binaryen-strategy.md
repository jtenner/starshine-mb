---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md
  - ../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./variant-matrix-and-scheduler.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `simplify-locals` strategy

## Upstream source rule

Use Binaryen `version_129` as the current source oracle for this pass family.

Primary files:

- `src/passes/SimplifyLocals.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/pass.h`

Most important helper dependencies:

- `src/ir/linear-execution.h`
- `src/ir/effects.h`
- `src/ir/equivalent_sets.h`
- `src/ir/local-utils.h`
- `src/ir/branch-utils.h`
- `src/ir/find_all.h`
- `src/ir/manipulation.h`
- `src/wasm-builder.h`

Representative shipped lit tests:

- `simplify-locals-global.wast`
- `global-effects_simplify-locals.wast`
- `simplify-locals-atomic-effects.wast`
- `simplify-locals-eh.wast`
- `simplify-locals-eh-legacy.wast`
- `simplify-locals-gc.wast`
- `simplify-locals-gc-nn.wast`
- `simplify-locals-gc-validation.wast`
- `simplify-locals-strings.wast`
- `simplify-locals-table_copy.wast`
- `simplify-locals-tnh.wast`
- `simplify-locals_rse_fallthrough.wast`
- the `flatten_simplify-locals-nonesting_*` combo files

## High-level intent

Binaryen uses `simplify-locals` to recover tighter tree-shaped value flow from frontend- or previous-pass-introduced local traffic.

That sounds like a simple peephole pass, but the real `version_129` implementation is broader.

It combines:

- use-count-aware local sinking
- effect-ordering-based invalidation
- optional tee creation
- optional block / `if` / loop result synthesis
- a separate late equal-local canonicalization phase
- final dead-set cleanup
- in-pass refinalization plus pass-runner nondefaultable-local fixups

A good short description is:

- **sink local writes through linear traces, optionally turn control into direct value producers, then canonicalize equal locals and delete what became dead**

## The pass family in one table

| Layer | What Binaryen does | Why it exists |
| --- | --- | --- |
| Template axes | `allowTee`, `allowStructure`, `allowNesting` | One implementation powers five public pass names |
| Get counting | `LocalGetCounter` | Decide whether direct sinking or teeing is even legal/useful |
| Main linear walk | `LinearExecutionWalker` plus `sinkables` | Track one straight-line trace cheaply without building a full CFG |
| Pre/post invalidation | `EffectAnalyzer` on both sides of nodes | Keep motion honest around calls, globals, memory, GC, EH, traps, and branches |
| Main sink step | `optimizeLocalGet` | Replace a `local.get` with a pending write, with first-cycle and tee gates |
| Structure rewrite step | block / if / loop return formation | Remove locals that only shuttle structured results |
| Enlargement retries | append trailing `nop` slots and rerun | Some structure rewrites need room before they can fire |
| Late equivalent phase | `EquivalentSets` and adjacent-dominator walk | Canonicalize copy locals after main sinking is stable |
| Final dead-set cleanup | `UnneededSetRemover` | Delete or drop now-dead writes without losing effects |
| Validation repair | `ReFinalize` + `TypeUpdating::handleNonDefaultableLocals` | Keep sharpened types and nondefaultable locals valid |

## Phase 0: one templated family, not five separate algorithms

`SimplifyLocals.cpp` defines a single template:

- `SimplifyLocals<allowTee, allowStructure, allowNesting>`

That means the public pass names differ by three explicit semantic switches, not by unrelated implementations.

The core beginner lesson is:

- `simplify-locals`
- `simplify-locals-notee`
- `simplify-locals-nostructure`
- `simplify-locals-notee-nostructure`
- `simplify-locals-nonesting`

all share the same major algorithm phases, but they disagree on what kinds of rewrites are allowed to materialize.

See [`./variant-matrix-and-scheduler.md`](./variant-matrix-and-scheduler.md) for the exact public mapping.

## Phase 1: count gets and run a deliberately asymmetric fixpoint

`doWalkFunction(Function* func)` starts with two gates:

- bail out if the function has zero locals
- run `getCounter.analyze(func)`

Then the real cycle story begins.

### First-cycle rule

The source sets:

- `firstCycle = true`

and the first run allows only single-use sinking.
That is intentional.

The file comment gives the reason:

- single-use locals are easier to optimize
- they match common compiler output patterns well
- early easy wins can enable more general work later

### Later-cycle rule

After the first cycle, Binaryen reruns the main algorithm with tee-capable behavior when the selected variant allows it.

### Late-phase rule

If the main work appears stable, Binaryen runs `runLateOptimizations(func)`.
If the late phase enabled new main work, it loops again.
But Binaryen deliberately refuses to run endless late-only cycles because get canonicalization is not guaranteed to converge by itself.

That is a source-backed detail worth preserving.
The pass is not one monotonic walk.
It is a staged fixpoint with a deliberately special first round.

## Phase 2: the main walker tracks only cheap linear state

The pass inherits from `LinearExecutionWalker`.
Its main reusable state is small:

- `sinkables`
- `blockBreaks`
- `unoptimizableBlocks`
- `ifStack`
- `expressionStack` when `allowNesting == false`

That is the first big scope boundary.
Binaryen is not doing full CFG local motion here.
It is doing a cheap linear-trace approximation.

### `sinkables`

This is a map from local index to a pending sinkable `local.set` plus its precomputed `EffectAnalyzer` summary.

### `blockBreaks`

This remembers sinkable snapshots at named-block exits so the pass can later ask whether all exits set the same local and therefore justify a block result.

### `unoptimizableBlocks`

If the pass encounters an unsupported target user for a named block, it marks the block unoptimizable rather than trying to partially reason about it.

The source TODO here is explicit:

- `BrOn`, `Switch`, and related forms are not yet optimized by this structure-return logic

### `ifStack`

This stores the true-arm sinkable state while the walker processes the false arm of an if/else.

## Phase 3: effect-order invalidation is the real safety rule

The core correctness rule is not adjacency.
It is whether an earlier pending write may legally move across the code we just saw.

### `visitPre`

Before a node is processed:

- entering `try` or `try_table` invalidates pending values that may throw, because moving them inside could change catchability
- `EffectAnalyzer::checkPre(curr)` may invalidate earlier sinkables using `effects.orderedAfter(info.effects)`

### `visitPost`

After a node is processed:

- `EffectAnalyzer::checkPost(original)` applies the symmetric post-order invalidation rule
- if the current node is a `local.set` that overwrites an earlier sinkable set to the same local, the old write is rewritten immediately to `drop(oldValue)`

This is why the official tests focus so much on global, memory, table, string, GC, EH, atomic, and TNH ordering.
The pass's real safety theorem is:

- **only move the local write when the effect model still says the new order means the same thing**

## Phase 4: `optimizeLocalGet` is the heart of the pass

When the current node is a `local.get`, Binaryen checks whether that local currently has a pending sinkable write.
If so, the main rewrite happens here.

### Single-use sink

If this is the first cycle or the local has exactly one use left:

- replace the get with the set value directly

This can sharpen types.
The source calls out a GC example where replacing a get with a more refined ref type can sharpen the field type observed by a `struct.get`.
When that happens, the pass marks `refinalize = true`.

### Tee formation

If this is not the first cycle and the variant allows tees:

- replace the get with the original set
- convert that set into a tee

That is the main consume-now/keep-later rewrite.

### Nonesting restriction

If `allowNesting == false`, the pass rejects a sink that would create new nesting unless the consumer context is itself a `local.set` value position or the value is already just a trivial `local.get` copy.

That is the real meaning of the nonesting variant.
It preserves a flatter IR contract, not just "no tee."

### Type-sharpening consequence

A direct sink may change the type seen by the consumer in a way a tee does not.
That is why only the direct-sink case triggers the explicit source comment about possible refinalization.

## Phase 5: `visitDrop` and overwrite cleanup are small but real phases

Two small visitors matter more than their size suggests.

### `visitDrop`

When a previously created tee is now immediately dropped, Binaryen collapses:

- `drop(local.tee ...)` -> `local.set ...`

That prevents the pass from leaving behind obviously gratuitous tees.

### Overwritten pending set cleanup

In `visitPost`, if the pass sees a new `local.set` to a local that already had a pending sinkable set, the earlier pending set is dead as a write.
Binaryen rewrites it to a `drop(value)` and clears it from the sinkable map.

This is a major source-backed reminder that the pass is not only about consumer-side sinking; it also cleans up now-dead overwritten producers while preserving effects.

## Phase 6: structure rewrites are a distinct optional layer

If `allowStructure` is enabled, the pass can synthesize result structure for three control families.

## A. Block return formation

`optimizeBlockReturn(Block* block)` looks for a local index that appears:

- in the fallthrough sinkables for the current trace
- and in every remembered exit trace for the named block

If found, Binaryen can:

- move the fallthrough set's value to the end of the block
- move each branch-side set into the branch value position
- wrap the now-value-producing block in one outer `local.set`

Important guards:

- named block only
- no preexisting branch payloads
- unsupported target users poison the whole block
- `br_if` needs a special condition hazard check if the moved set lives in the condition
- if the block lacks a trailing `nop` slot, the pass queues it for enlargement and retries later

The `br_if` hazard check is one of the easiest subtleties to miss.
The source explicitly avoids moving a set from a branch condition into the payload position when that would change which local value the condition observes.

## B. If/else return formation

`optimizeIfElseReturn` looks for either:

- one local index set in both arms
- or one sinkable local in the reachable arm when the other arm is `unreachable`

Then it moves the set values into arm result positions and wraps the whole if in the outer set.

Again, arm blockification and trailing-`nop` room may need to be created on a prior cycle.

## C. One-armed `if` speculative result formation

`optimizeIfReturn` handles the one-armed if case.
It is explicitly described in the source as a **speculative optimization**.

Binaryen creates:

- a value-producing if
- with the then arm returning the previous set value
- and the new else arm reading the local
- then wraps that if in the original outer local set

This can be profitable if later passes sink the outer set or simplify the new copy arm.
But the source is clear that it can hurt size or speed if those later cleanups do not happen.

Most important guard:

- the local type must be defaultable

The comment explains why nondefaultable locals are dangerous here:
new else-arm gets may not be structurally dominated, and later validation fixups would insert `ref.as_non_null` in ways that can create real runtime traps.
So Binaryen just skips the nondefaultable case.

## D. Loop return formation

`optimizeLoopReturn` is intentionally narrow:

- the loop must currently be void
- a sinkable local must exist
- the loop body must be or become a block with a trailing `nop` slot

Then the pass moves the set value to the loop body's end, turns the loop into a value producer, and wraps it in the original local set.

## Phase 7: some rewrites require an enlargement cycle first

The pass cannot always insert new block/if/loop result positions immediately because doing so would invalidate stored pointers into the current AST.
So `runMainOptimizations` maintains three queues:

- `blocksToEnlarge`
- `ifsToEnlarge`
- `loopsToEnlarge`

After the main walk, it blockifies or appends trailing `nop`s and then reruns another cycle.

This is not just implementation trivia.
It is part of the actual behavior:

- some structure rewrites only become possible after Binaryen has first created room for them

## Phase 8: late equivalent-copy cleanup is separate from the main sinker

`runLateOptimizations` constructs a nested `EquivalentOptimizer`.
This is a distinct algorithm, not just another mode of the sinkable-state pass.

Important design choices:

- `connectAdjacentBlocks = true`
  - the late phase may reason into immediately dominated adjacent blocks without constructing a full CFG
- `EquivalentSets` records equal-local groups
- `removeEquivalentSets = allowStructure`
  - structured variants are more willing to remove redundant copy sets entirely

### Equivalent-set removal

If `local.set B (local.get A)` is redundant because `A` and `B` are already known equivalent, Binaryen can delete the set:

- tee copy -> just the tee value
- plain set -> `drop(value)`

### Canonicalize gets to the best equivalent local

When a get may legally read from several equivalent locals, Binaryen picks a preferred representative.
The tie-break is source-backed and important:

1. prefer a more refined type
2. otherwise prefer the local with more remaining gets

That is why the late phase is not just copy deletion.
It is also local-choice canonicalization for downstream passes.

## Phase 9: `UnneededSetRemover` is the final local cleanup layer

After the equivalent phase, Binaryen runs `UnneededSetRemover` from `local-utils.h`.
That helper removes:

- sets whose locals now have zero possible gets
- sets that store the same value the local already holds, including through tee chains

The helper preserves effects correctly:

- dead tee -> underlying value
- dead effectful set -> `drop(value)`
- dead pure set -> `nop`

So the full late boundary is:

- equivalent-copy cleanup
- then final dead-set cleanup

not just one or the other.

## Phase 10: validation repair is split across two layers

Inside `SimplifyLocals.cpp`, Binaryen may set `refinalize = true` when:

- direct sinking sharpens types
- equivalent-local canonicalization switches to a more refined local
- `UnneededSetRemover` removes a tee whose value was more refined than the local type

Then `doWalkFunction` runs `ReFinalize` if needed.

But the full validation story is wider.
Because `Pass::requiresNonNullableLocalFixups()` defaults to `true`, `PassRunner::handleAfterEffects(...)` automatically runs:

- `TypeUpdating::handleNonDefaultableLocals(func, *wasm)`

after `simplify-locals`.

That is why the dedicated GC validation tests are part of the real contract.
The pass's validation boundary is split between:

- local refinalization inside the file
- nondefaultable-local fixups after the pass

## Scheduler placement is part of the meaning of the family

### Early no-structure slot

In the canonical no-DWARF `-O` / `-Os` function pipeline, Binaryen runs:

- `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> ...`

The pass.cpp comment here is important and explicit:

- do not create if/block return values yet, because coalescing can remove copies that structure creation would inhibit

So the early slot is about cleaning local traffic without committing to structured result synthesis too early.

### Late full slot

Later, after `coalesce-locals` and optional `local-cse`, Binaryen runs:

- `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum`

This is where the full structured variant gets its chance.
The pass.cpp comment right before this region is also revealing:

- `simplify-locals opens opportunities for optimizations`

That is the official reason the pass appears late even though an earlier local simplifier already ran.

### Aggressive flatten path

At higher optimize settings, Binaryen also uses:

- `flatten -> simplify-locals-notee-nostructure -> local-cse`

That slot exists because flat IR produces many easy locals, but Binaryen still wants to preserve a relatively flat shape there instead of immediately reintroducing tees or structured result wrappers.

### Nested reruns

`opt-utils.h` uses `addDefaultFunctionOptimizationPasses()` inside `optimizeAfterInlining(...)`.
So the same family can appear again in nested optimizing reruns, not just at the top-level visible slots.

## What a future port must preserve

A future honest Binaryen-parity port must keep these source-backed rules explicit:

- the five public pass names are one templated family with three semantic axes
- the first cycle is intentionally stricter than later cycles
- effect ordering, not adjacency, is the central safety rule
- structure synthesis is optional and deliberately delayed relative to the early no-structure slot
- one-armed `if` rewriting is speculative and defaultable-only
- the nonesting variant promises more than just "no tee"
- late equivalent-copy cleanup is a separate phase with its own adjacent-dominator model
- `UnneededSetRemover` is a real part of the pass contract
- validation repair is split between in-pass refinalization and pass-runner nondefaultable-local fixups

## Current freshness note

A narrow 2026-04-21 current-main check found no meaningful semantic drift on the checked surfaces.
The core source difference is only `map/set` -> `unordered_map/unordered_set` container cleanup, and the checked dedicated lit files are unchanged.
So `version_129` remains the best released oracle for this dossier.
