---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0128-2026-04-20-merge-locals-binaryen-research.md
related:
  - ./index.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
---

# Binaryen `merge-locals` strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is `src/passes/MergeLocals.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp` and the after-inlining helper in `src/passes/opt-utils.h`.
- The key helper contracts come from:
  - `src/ir/local-graph.h`
  - `src/passes/pass-utils.h`
- The shipped behavior examples come from `test/lit/passes/merge-locals.wast`.
- I also did a narrow freshness check against current upstream `main` for the two easiest drift points to miss:
  - the scheduler gate `optimizeLevel >= 3 || shrinkLevel >= 2`
  - the early bailout when local names are present
- As of `2026-04-20`, both still match `version_129` in substance.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

## High-level intent

Binaryen uses `merge-locals` to reduce alias-style local traffic before the later GC/type/coloring cleanup passes run.

That sentence is true but incomplete.

The actual implementation is a **LocalGraph-based single-set alias normalizer**.

The core question is not:

- “which locals look similar?”

It is:

- “which locals are really just one simple source story seen through several alias locals, and can we replace that whole story with one canonical slot?”

That extra “one simple source story” clause is the real pass.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Skip debug-sensitive functions | Bail out when local names exist | Avoid worsening local-name / debug-info behavior |
| Build eager graph facts | `LocalGraph(false)` + `computeSetInfluences()` | See transitive alias structure instead of only adjacent pairs |
| Filter candidates | Require exactly one set, a real value, a simple/reorderable value, and influenced gets still tied to that same set | Keep the optimization narrow and safe |
| Choose canonical slot | Reuse an existing tiny source local for direct copy chains, otherwise create one fresh temp | Normalize the whole alias group around one slot |
| Materialize rewrites | Graph-guided post-walk retargets gets/sets and drops redundant copy sets | Turn graph facts into actual IR changes |

## Phase 1: this is a function pass with a metadata bailout, not a DWARF-invalidating rewrite

`MergeLocals` reports `isFunctionParallel() == true`, so Binaryen treats it as a per-function pass that can run across functions in parallel.

Unlike some nearby passes, the interesting metadata behavior here is **not** an `invalidatesDWARF()` override.
The file does something narrower and more conservative:

- if the function already has a local name at index `0`, Binaryen returns immediately without running the pass

The source comment says those local names are useful in debug info, and that interpreted wasm may still carry them even though they are not valid in the wasm backend.

So the current implementation policy is:

- do not try to repair debug/name metadata after merging locals
- simply skip such functions instead

That is a real contract edge, not a side note.

## Phase 2: eager `LocalGraph` is part of the strategy

After the early bailout, `doWalkFunction(...)` does three structurally important things:

1. `noteNonLinear(...)`
2. build `LocalGraph(false)`
3. call `graph.computeSetInfluences()`

The `false` means **eager**, not lazy.

That matters because the source comment explicitly says:

- lazy mode can save memory
- but lazy mode can miss opportunities
- and lazy mode ran about `25%` slower on the Binaryen benchmark note captured in the comment

So the durable lesson is:

- Binaryen wants the more precise and more opportunity-rich graph here, even at some memory cost

## Phase 3: `LocalGraph` defines what “same source story” means

The pass depends on four `LocalGraph` ideas.

## 1. `getSetses(index)`

This gives every set site for a local.
`merge-locals` immediately uses it to enforce its most important narrowness rule:

- the candidate local must have **exactly one** set

## 2. `computeSetInfluences()`

This computes which gets are influenced by which sets.
The helper comment says this can work transitively when locals are set from other locals.

That is why the pass can see:

- direct copy chains
- transitive chains
- DAG-like fanout from one source

instead of only one adjacent `local.set` / `local.get` pair.

## 3. `getInfluences(set)`

This gives the gets influenced by one particular set.
`merge-locals` uses it to say:

- “show me the whole proven user set for this candidate source story”

## 4. `postWalkFunction(...)`

This is the graph-guided materialization stage.
The pass callback `postGraph(...)` uses it to retarget gets/sets and erase redundant copy sets after the mapping decisions are known.

## Phase 4: candidates are intentionally tiny in scope

Binaryen loops over every param + local index, but most locals are rejected quickly.
The candidate must satisfy all of these:

1. it was not already absorbed into an earlier canonical group
2. `graph.getSetses(i).size() == 1`
3. that single set has a real value
4. `FunctionUtils::isSimple(set->value)` is true
5. the influenced gets, after filtering, are still influenced by that exact set

Each filter is important.

## Exactly one set

This means the pass does **not** try to solve:

- multi-branch merge locals
- phi-like locals with several writes
- general-purpose mutable temporaries
- liveness-wide slot sharing

That work belongs to other passes, especially `coalesce-locals`.

## Real value

If the set has no value, there is no source expression to normalize around.
So the pass bails out immediately.

## `FunctionUtils::isSimple(...)`

This is the safety gate most people underestimate.
`pass-utils.h` shows it is effect-aware, not just textual.
The helper uses `EffectAnalyzer` and requires the expression to be reorderable without unremovable side effects.

So the real rule is:

- the source value must be simple **enough to move the alias group around it safely**

This is why the `keepSimple1` and `keepSimple2` tests keep complex block/loop producers intact.

## Influenced gets must still agree on the source set

Even after `LocalGraph` gives the influenced gets for a candidate set, Binaryen still filters out any get whose recorded influencing set is not that exact set.

That means the pass is explicitly guarding against a subtle false positive:

- a local might look single-set locally,
- but some gets might actually belong to another reaching set story in the wider graph

If the remaining influenced-get set becomes empty, the candidate is abandoned.

## Phase 5: the pass has a real direct-reuse vs fresh-temp split

Once a candidate passes the filters, Binaryen chooses one canonical slot.
That choice is not uniform.

## Direct source reuse

If the candidate set’s value is literally a `local.get`, and the source local also has a very tiny graph surface:

- exactly one get
- exactly one set

then Binaryen uses that source local index directly as the canonical slot.

This is the pure copy-chain collapse case.

Good beginner wording:

- if local B is really just a very thin alias of local A,
- and A itself already has a very small clean source story,
- then redirect the whole chain back to A

## Fresh temp canonicalization

If the value is still simple but not that trivial `local.get` case, Binaryen allocates one new local of the set’s type and uses that as the canonical slot.

Good beginner wording:

- if the source story is simple enough to share,
- but it is not just “read one already-canonical local,”
- then create one dedicated temp and make the whole alias group read that temp instead

That means `merge-locals` can temporarily **add** a local in service of simplifying the alias structure.
It is not a monotonic “only delete locals” pass.

## Phase 6: mapping is whole-local for the proven group

The pass records mappings keyed by local index, not by one particular get node.

That means once Binaryen has proved a local belongs to the candidate’s simple source story, it rewrites the local index itself to the canonical slot.

This is exactly why the earlier filters are so strict.
The optimization is more powerful than a peephole, so the preconditions are narrower than a peephole too.

## Phase 7: materialization happens in the graph-guided post-walk

If Binaryen found no mappings, it exits.
Otherwise it calls `graph.postWalkFunction(this, func, module)`.

The durable user-visible outcomes of `postGraph(...)` are:

- eligible `local.get`s are retargeted to the canonical slot
- eligible `local.set`s are retargeted to the canonical slot
- redundant copy-only sets are removed when the rewrite made them pointless

I am intentionally describing the materialization step at that level.
The helper callback plus the shipped tests make that contract clear, while some lower-level internal `LocalGraph` mutation details are not worth overfitting into a beginner-facing summary.

## Scheduler placement is part of the meaning

`pass.cpp` inserts `merge-locals` only when:

- `options.optimizeLevel >= 3`, or
- `options.shrinkLevel >= 2`

and it places it here:

- after `heap2local`
- before `optimize-casts`
- before `local-subtyping`
- before `coalesce-locals`

That placement is not accidental.

## Why after `heap2local`

`heap2local` can create more local traffic and more copy-like alias families.
So `merge-locals` gets more to clean up there than it would earlier.

## Why before `optimize-casts` and `local-subtyping`

The already-documented `optimize-casts` dossier notes that `merge-locals` may appear immediately before it under stronger optimize/shrink settings.
That means Binaryen wants some alias cleanup done before cast reuse and local-type tightening reason about the local surface.

## Why before `coalesce-locals`

`merge-locals` handles the narrow, obvious, one-source alias families first.
Then `coalesce-locals` can do the more global slot-sharing work later.

So the two passes are complementary, not redundant.

## Nested reruns matter too

`opt-utils.h` shows that optimizing passes rerun `addDefaultFunctionOptimizationPasses(...)` on touched functions.
Under stronger optimize/shrink settings, that means `merge-locals` can execute again inside those nested cleanups.

The saved `-O4z` debug log proves this is not hypothetical:

- there is one top-level skipped slot `27`
- but `18` total `merge-locals` executions in the captured full run

## What the pass does **not** do

Binaryen `merge-locals` does **not**:

- run in the ordinary `-O` / `-Os` no-DWARF path
- do full liveness/coloring like `coalesce-locals`
- narrow or widen local types like `local-subtyping`
- optimize effectful or control-heavy source values freely
- merge arbitrary multi-set locals
- preserve local-name metadata while rewriting; instead it bails out
- act like a generic copy-propagation fixpoint across the whole function

The real contract is smaller and sharper than the name suggests.

## Bottom line

Binaryen’s `merge-locals` pass is a higher-aggression, LocalGraph-driven, single-set alias cleanup.

The pass only fires when a local group has one trusted simple source story, and it normalizes that group around one canonical slot.
Sometimes that slot is an old source local; sometimes it is a fresh temp.

That is the behavior a future Starshine port must preserve.
