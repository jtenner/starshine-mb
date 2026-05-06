---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/research/0472-2026-05-05-reorder-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md
  - ../../../raw/research/0430-2026-04-27-reorder-locals-validation-bridge.md
  - ../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md
  - ../../../raw/research/0253-2026-04-22-reorder-locals-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0142-2026-04-20-reorder-locals-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./names-roundtrip-and-porting.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `reorder-locals` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.
For the immutable manifest of the reviewed official release, source, and representative test URLs, see [`../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-reorder-locals-primary-sources.md). For the 2026-05-05 current-main recheck, see [`../../../raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-reorder-locals-current-main-recheck.md) and [`../../../raw/research/0472-2026-05-05-reorder-locals-current-main-recheck.md`](../../../raw/research/0472-2026-05-05-reorder-locals-current-main-recheck.md); the 2026-04-27 validation and preset-readiness recheck remains linked through [`../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md`](../../../raw/binaryen/2026-04-27-reorder-locals-validation-primary-sources.md) and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

Primary files:

- `src/passes/ReorderLocals.cpp`
- `src/passes/pass.cpp`

Most important official test surfaces for this dossier:

- `test/passes/reorder-locals.wast`
- `test/passes/reorder-locals.txt`
- `test/passes/reorder-locals_print_roundtrip.wast`
- `test/passes/reorder-locals_print_roundtrip.txt`

Supporting official files for the known remaining parity boundary:

- `src/wasm/wasm-ir-builder.cpp`
- `src/wasm/wasm-stack.cpp`

I also did a narrow 2026-05-05 freshness check against current GitHub `main` for:

- `ReorderLocals.cpp`
- `pass.cpp`
- both dedicated pass tests and their golden outputs

Durable result:

- all of those surfaces still match `version_129` exactly

The reviewed official GitHub `version_129` release page also showed publish date **2026-04-01** when checked on 2026-04-22.
So the wiki should keep treating `version_129` as the semantic oracle here without an active trunk-drift warning.

## File landmarks worth keeping explicit

In the reviewed `version_129` source, the key mechanics are tightly concentrated:

- `ReorderLocals.cpp` lines `8-63`
  - `ReIndexer`, which rewrites only `LocalGet` and `LocalSet` users after the new numbering is known
- `ReorderLocals.cpp` lines `65-162`
  - the full pass body: access counting, first-use ranking, sorting, parameter stabilization, zero-count body-local truncation, inverse-map construction, local-user reindexing, and local-name-map repair

That exact concentration is part of the contract.
It is why this pass should be remembered as a tiny sorter-plus-name-repair pass, not as a hidden dataflow analysis.

## High-level intent

Binaryen uses `reorder-locals` to make local declarations smaller and more canonical **without** changing local types or proving deep dataflow facts.

The real intent is narrow:

- hot body locals should appear earlier
- untouched body locals should disappear
- parameter order should stay stable
- local names should still point at the right declarations afterward

That makes the pass useful as repeated cleanup glue between heavier local passes.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Count accesses | Walk `LocalGet` and `LocalSet` users | Measure local hotness cheaply |
| Record first use | Assign an increasing rank on first sighting | Canonicalize ties among live locals |
| Sort local indices | Keep params first, then sort body locals by count and first use | Rebuild declarations into a stable hot-first order |
| Drop zero-count tail | Stop at the first zero-count body local after sorting | Remove untouched body locals |
| Reindex users | Rewrite local indices in the function body | Keep uses aligned with the new declaration order |
| Rewrite names | Rebuild `localNames` / `localIndices` | Keep metadata aligned with the new numbering |

## Registered surface

`pass.cpp` registers:

- `reorder-locals`
  - sorts locals by access frequency

There is no extra mode split, no option flag, and no special GC or feature gate for the pass itself.

## Canonical no-DWARF placement

In `pass.cpp`, the default no-DWARF function pipeline uses `reorder-locals` three times:

1. `simplify-locals-nostructure -> vacuum -> reorder-locals`
2. `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals`
3. `... -> coalesce-locals -> reorder-locals -> vacuum`

That tells us the scheduler meaning is not just "sort locals once":

- earlier cleanup waves create garbage or dead declarations
- `reorder-locals` compacts the local table after those waves
- later coalescing and simplification can change the local set again
- so Binaryen runs the pass again instead of assuming one early reorder stays optimal forever

## Pass shape: one tiny function-parallel walker

`ReorderLocals.cpp` defines:

- `struct ReorderLocals : public WalkerPass<PostWalker<ReorderLocals>>`

Two pass-level properties immediately frame the contract:

- `isFunctionParallel() == true`
- `requiresNonNullableLocalFixups() == false`

The first means:

- the pass is intentionally per-function and embarrassingly parallel

The second means:

- reordering and dropping zero-access body locals should not invalidate local-type legality
- the pass is not expected to trigger Binaryen's generic nondefaultable-local repair machinery

## Phase 1: early return when there are no body locals

If a function has `getNumVars() == 0`:

- return immediately

That makes params-only functions true no-ops.

## Phase 2: count accesses and record first-use ranks

Binaryen allocates two arrays over **all** local indices, including parameters:

- `counts`
- `firstUses`

It then walks the function body and increments counts in exactly two visitors:

- `visitLocalGet(LocalGet*)`
- `visitLocalSet(LocalSet*)`

The tie-break rule depends on `firstUses`:

- the first time a local is seen, it gets the next `firstUseIndex`

### Important tee detail

Binaryen does not have a separate `visitLocalTee(...)` here because:

- Binaryen IR represents `local.tee` as `LocalSet` with tee state

So the real semantic rule is still:

- gets count
- sets count
- tees count

A future port must preserve that rule even if the host IR uses separate set and tee node kinds.

### Slightly surprising but harmless detail

`firstUseIndex` is a pass field and is not reset inside `doWalkFunction(...)`.

That looks odd, but it does not change semantics because:

- `firstUses` is reset per function
- the pass only compares first-use ranks inside one function
- any monotonic range works, not just `1..N` starting fresh each time

## Phase 3: sort old indices into the new declaration order

Binaryen builds `newToOld = [0, 1, 2, ...]` and sorts it with one comparator.

The comparator is the heart of the pass:

1. params sort before non-params
2. params keep original order
3. among body locals:
   - larger `counts` sorts earlier
4. if counts tie:
   - if both counts are zero, smaller original index sorts earlier
   - otherwise, smaller `firstUses` rank sorts earlier

This yields the exact public contract:

- parameters are fixed
- used body locals are sorted by descending access frequency
- used-body-local ties are broken by first observed access
- unused body locals keep source order until they are removed

## Phase 4: forcibly restore parameter identity

After the sort, Binaryen still explicitly restores the parameter prefix:

- assert each prefix element is a param
- set `newToOld[i] = i` for each parameter slot

That means parameter immobility is not just a side effect of the comparator.
It is an explicit invariant.

## Phase 5: rebuild body locals and drop the zero-count suffix

Binaryen swaps `curr->vars` into a temporary `oldVars`, then iterates the body-local part of the sorted order.

For each sorted body-local candidate:

- if `counts[index] > 0`, keep that local's type in the rebuilt var list
- otherwise:
  - truncate `newToOld` at that point
  - break immediately

That works because the sorted body-local region now has this shape:

- all nonzero-count body locals first
- then all zero-count body locals

So one truncation removes the entire unused suffix.

### Consequences that are easy to miss

- write-only locals survive, because writes count
- the pass never asks whether a write is semantically dead
- a function can end up with zero body-local declarations after the pass

## Phase 6: invert the mapping

Binaryen builds `oldToNew` from the truncated `newToOld` list.

- params map to themselves
- live body locals map to their new positions

The pass does not need a mapping for dropped locals because there should be no remaining uses of them.

## Phase 7: reindex local users in the function body

A nested `ReIndexer` `PostWalker` rewrites only:

- `LocalGet.index`
- `LocalSet.index`

That is enough because:

- every local user is one of those two Binaryen node kinds
- tee uses piggyback on `LocalSet`

This is why `reorder-locals` is not a shape-driven control-flow pass.
It does not have special rules for `if`, `loop`, `try`, or branches. It simply rewrites the local user nodes wherever they occur.

## Phase 8: rebuild function-local name maps

After reindexing, Binaryen rewrites:

- `curr->localNames`
- `curr->localIndices`

It clears both, then repopulates them by iterating the kept `newToOld` list.

That means:

- surviving names move to the new indices
- dropped locals lose their names naturally
- parameter names stay put because parameter indices stay fixed

This metadata rewrite is part of the upstream algorithm, not a repo-local embellishment.

## What the pass depends on

- `WalkerPass` and `PostWalker`
- `Function` helpers such as:
  - `getNumVars()`
  - `getNumLocals()`
  - `getParams()`
  - `getVarIndexBase()`
  - `isParam(...)`
- function-local name maps:
  - `localNames`
  - `localIndices`

## What the pass notably does **not** depend on

- `LocalGraph`
- CFG analyses
- dominance
- liveness
- `Effects`
- `BranchUtils`
- `ReFinalize`
- EH repair helpers
- type-updating helpers
- non-nullable-local fixups

That absence is a big part of the teaching value here.
The pass sounds like it might belong with heavier local-analysis passes, but it does not.

## Why later passes are part of the meaning

Because `reorder-locals` keeps running after cleanup waves, its real meaning is partly scheduler-shaped.

Binaryen wants it to operate after passes that can change local traffic materially, such as:

- `simplify-locals-nostructure`
- `vacuum`
- `simplify-locals`
- `coalesce-locals`

So the honest summary is not just:

- sort locals by access frequency

It is also:

- repeatedly re-canonicalize the local table after cleanup passes have changed which body locals still matter

## What this pass does **not** do

These non-goals are important to keep explicit:

- no dead-store proof
- no lifetime overlap reasoning
- no local merging
- no type refinement
- no stack / tuple packaging logic
- no multivalue call writeback repair
- no writer-side grouped-by-type layout policy

Those last two belong to the Binaryen IR-builder and writer layers, not to `ReorderLocals.cpp`.

## Bottom line

Binaryen `reorder-locals` is a deliberately tiny pass.

Its defining rule is simple:

- keep params fixed, sort live body locals by heat and first use, then drop the untouched tail.

The reason it still deserves a full dossier is that the surrounding contract includes:

- repeated scheduler placement
- local-name maintenance
- and roundtrip-visible declaration order

A future parity port that matches only the comparator but ignores those surrounding rules is still incomplete.
