# 0128 - `merge-locals` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented Binaryen local-cleanup pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what `merge-locals` actually does, which helper utilities it depends on, which IR / WAT shapes it rewrites or preserves, and what a future Starshine port must keep exact.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` still listed `merge-locals` with wiki status `none` when this thread started.
- The same tracker had already promoted `merge-locals` to the top suggested next target after the new `flatten` dossier landed.
- Unlike the earlier late-tail backlog, there were no remaining `both`-relevance `none` targets left; `merge-locals` was the strongest remaining saved-audit-only gap.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - slot `27`
- The saved Binaryen debug log shows it is not just a one-off top-level curiosity in that captured run:
  - top-level slot `27` took about `0.341063` seconds
  - the same full run executed `merge-locals` `18` total times because later optimizing reruns reused the same default function pipeline under the higher optimize settings
- `merge-locals` sits immediately before an already-documented neighbor cluster whose behavior is easier to understand once this pass is clear:
  - `heap2local`
  - `merge-locals`
  - `optimize-casts`
  - `local-subtyping`
  - `coalesce-locals`
- The current repo backlog still has **no dedicated `merge-locals` slice** in `agent-todo.md`.
  - The closest local planning note is still the older Batch 1 removed-pass note in `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`.
- The name is very easy to overread.
  - A shallow mental model like “merge similar locals” misses the important source-level truth:
    - Binaryen is **not** doing generic liveness-based local coloring here
    - Binaryen is **not** doing type refinement here
    - Binaryen is **not** doing full `coalesce-locals`-style slot reuse here
    - Binaryen is doing a much narrower LocalGraph-driven rewrite on locals that have exactly one sufficiently simple set and a well-defined influenced-get surface

That makes `merge-locals` a strong dossier target: it is still missing, it affects the same late local-cleanup cluster as several already-documented neighbors, and the real contract is much more precise than the CLI name suggests.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- neighboring dossiers:
  - `docs/wiki/raw/research/0113-2026-04-20-optimize-casts-binaryen-research.md`
  - `docs/wiki/raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md`
  - `docs/wiki/raw/research/0118-2026-04-20-coalesce-locals-binaryen-research.md`
  - `docs/wiki/raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md`
  - `docs/wiki/raw/research/0127-2026-04-20-flatten-binaryen-research.md`

### Official Binaryen `version_129` sources

- `src/passes/MergeLocals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `src/passes/pass-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass-utils.h>
- `src/ir/local-graph.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- `test/lit/passes/merge-locals.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>

### Freshness check on current upstream `main`

- `src/passes/MergeLocals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

I only used `main` for a narrow freshness check on the easiest drift points to miss:

- the scheduler gate `optimizeLevel >= 3 || shrinkLevel >= 2`
- the local-name bailout at the top of `doWalkFunction(...)`
- the eager `LocalGraph(false)` comment noting that lazy mode misses opportunities and ran slower on the Binaryen benchmark note captured in source

As of `2026-04-20`, those lines still match `version_129` in substance.

## Fast answer

Binaryen’s `merge-locals` pass is a higher-aggression function pass that rewrites groups of single-set locals so they all read from one canonical slot when Binaryen can prove that the group really comes from one sufficiently simple source.

The shortest accurate mental model is:

1. build a `LocalGraph`
2. compute which local gets are influenced by which sets
3. find locals with **exactly one set**
4. require that set’s value to be `FunctionUtils::isSimple(...)`
5. require every influenced get in the candidate group to still point back to that same single set
6. then either:
   - reuse an existing source local directly when the set is just `local.get` from a suitably tiny source chain, or
   - create one fresh temp local and redirect the whole influenced group to that temp
7. materialize the retargeted gets / sets with a graph-guided post-walk and drop redundant copy sets

The most durable source-derived facts are:

- `merge-locals` is registered as a function-parallel pass whose summary is “merges locals together when beneficial.”
- It is inserted in `pass.cpp` only when:
  - `options.optimizeLevel >= 3`, or
  - `options.shrinkLevel >= 2`
- That means it is **not** part of the canonical no-DWARF `-O` / `-Os` path tracked elsewhere in this repo.
  - But it does matter for stronger modes like `-O3`, `-Oz`, `-O4`, and the saved `-O4z` audit run.
- The pass is intentionally placed after `heap2local` and before:
  - `optimize-casts`
  - `local-subtyping`
  - `coalesce-locals`
- The pass is **not** `coalesce-locals` in miniature.
  - It does not do liveness-based coloring.
  - It does not consider arbitrary multi-set locals.
  - It does not change local types.
  - It does not refinalize.
- The pass skips whole functions that already carry local names.
  - The source comment says those names are useful in debug info, so Binaryen stops rather than worsening that situation.
- The pass uses an **eager** `LocalGraph(false)`.
  - The source comment explicitly says lazy mode can miss opportunities and was measured around `25%` slower on Binaryen’s benchmarks.
- The core candidate rule is very small:
  - exactly one set
  - that set has a value
  - the value is sufficiently simple / reorderable
  - the influenced gets still trace back to that exact same set
- The core helper dependency is `LocalGraph::computeSetInfluences()`.
  - That is how Binaryen sees transitive copy chains and DAG-like influence groups instead of only one local at a time.
- The pass has a split between:
  - **reuse an existing source local** when the candidate set is literally a `local.get` from a very small source chain, and
  - **allocate a fresh temp** when the candidate value is simple but not just a trivial reusable source local
- The shipped `merge-locals.wast` tests lock in the main user-visible families:
  - branching / arity cases
  - order-sensitive transitive copy chains
  - DAG-like influence sharing
  - loop-backedge copies
  - complex-value bailouts (`keepSimple*`)
  - conservative behavior around unreachable code (`between-unreachable`)

## Where it appears in the scheduler

## Registered pass surface

`pass.cpp` registers:

- `merge-locals`
  - description: “merges locals together when beneficial”

`passes.h` declares:

- `createMergeLocalsPass()`

There is no separate public `merge-locals-learning` or `merge-locals-always` variant in `version_129`.

## Higher-aggression placement, not ordinary `-O` / `-Os`

The relevant scheduler region in `pass.cpp` is:

- `heap2local`
- if `options.optimizeLevel >= 3 || options.shrinkLevel >= 2`:
  - `merge-locals`
- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`
- ...

That means the real scheduler story is:

- `merge-locals` is later than `heap2local`, so it can clean up the extra local traffic that heap promotion creates
- `merge-locals` runs before the more type-aware and slot-wide cleanup neighbors
- `merge-locals` is missing from the canonical no-DWARF `-O` / `-Os` page because those modes do not satisfy the higher optimization/shrink gate

So the pass is **O4z-only for this repo’s current audit/tracker vocabulary**, but not O4z-only in upstream Binaryen generally.

It is better described as:

- a higher-aggression pass
- absent from ordinary `-O` / `-Os`
- present once optimize level or shrink level climbs high enough

## Saved generated-artifact `-O4z` evidence

The saved ordered replay records:

- slot `27`: `merge-locals`

The saved Binaryen debug log records the same top-level neighborhood:

- `heap2local`
- `merge-locals`
- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`

and the top-level `merge-locals` slot took about `0.341063` seconds in that captured run.

The same saved debug log also records `18` total `merge-locals` executions. That is much more than one top-level slot, so a real implementation dossier must remember the nested-rerun story too.

## Nested reruns

`opt-utils.h` shows that `optimizeAfterInlining(...)` reruns `addDefaultFunctionOptimizationPasses(...)` on touched functions.

That means:

- under stronger optimize/shrink settings,
- later optimizing passes can trigger more `merge-locals` runs,
- and the saved `18`-run log count is exactly what we would expect from that design.

This matters for a future Starshine scheduler because a top-level pass list alone is not the whole story once the optimizing boundary passes exist.

## Actual implementation structure

## 1. Pass shape and the big early bailout

`MergeLocals` is declared as:

- `WalkerPass<PostWalker<MergeLocals>>`

and reports:

- `isFunctionParallel() == true`

So this is a straightforward per-function pass that Binaryen expects to parallelize across functions.

However, the most important early behavior comes before any graph work:

- if the function has a local name at index `0`, Binaryen immediately returns without running the pass

The source comment explains why:

- local names are useful in debug info
- they are possible in interpreted wasm even though they are not valid in the wasm backend
- this pass would worsen that situation

That means the current implementation chooses a **whole-function bailout** instead of trying to preserve or rewrite debug/name metadata.

This is one of the easiest details to miss if you only read the pass name.

## 2. The pass is built around `LocalGraph`, not liveness coloring

After the bailout, the pass does:

1. `noteNonLinear(...)`
2. build an eager `LocalGraph(false)`
3. `graph.build(func, module)`
4. `graph.computeSetInfluences()`

The eager graph choice is not incidental. The source comment says:

- lazy mode can save memory
- but lazy mode can miss opportunities
- and on the Binaryen benchmark note in source, lazy mode ran about `25%` slower

So the durable takeaway is:

- Binaryen values precision and predictable opportunity finding more than the smaller lazy graph here

That is a very different implementation personality from a simple local textual peephole pass.

## 3. `LocalGraph` gives the pass its real vocabulary

`src/ir/local-graph.h` explains the important graph concepts:

- `getSetses(index)`
  - all set sites for a local index
- `getGetses(index)`
  - all get sites for a local index
- `computeSetInfluences()`
  - a map from sets to the gets influenced by them, including transitive propagation through simple copy chains
- `getInfluences(set)`
  - the influenced gets for one set

The critical `LocalGraph` comment says the influence relation is defined so that:

- if a local has only one setting location,
- then that set influences all gets of the local,
- and the helper can compute this transitively for locals set from other locals

That is the key to the whole pass.

`merge-locals` is therefore not scanning WAT text for adjacent `local.set` / `local.get` pairs.
It is querying a graph of set/get influence facts.

## 4. Candidate locals must have exactly one set

The main loop iterates over all params + vars and immediately rejects locals when:

- the local was already rewritten as part of an earlier group, or
- `graph.getSetses(i).size() != 1`

That single-set requirement is the narrowest and most important contract boundary.

Binaryen is not trying to reason about:

- locals written in multiple branches
- phi-like multi-set locals
- general liveness merge points
- arbitrary mutable temporaries

It only handles locals whose provenance is small enough to describe as “one set, one real source story.”

## 5. The single set must have a real value, and that value must be simple

After finding the only set, the pass rejects candidates when:

- the set has no value
- `FunctionUtils::isSimple(set->value)` is false

That helper does not mean “syntactically tiny” in a casual sense.
`pass-utils.h` shows it means:

- the expression has no side effects under `EffectAnalyzer`
- the expression can be reordered safely
- the expression has no unremovable side effects

So the real rule is:

- the value must be effect-free and reorderable enough to treat as a safe merge source

This is why the shipped tests preserve complex control-heavy / looping source values under the `keepSimple1` and `keepSimple2` families.

## 6. Influenced gets must still point back to that exact set

Even after `LocalGraph` gives the influenced gets for the candidate set, Binaryen adds one more filter:

- erase any get whose recorded influencing set is not this exact set

The result must still be non-empty, or the candidate is abandoned.

That check matters because it prevents the pass from over-merging in cases where:

- a local has a nominally small graph neighborhood,
- but some gets can also be reached from another set story,
- so the candidate would no longer have a single trustworthy provenance.

This is the pass’s main bailout against “looks like one source locally, but not really across the graph.”

## 7. There are two canonical-slot strategies

Once a candidate passes the filters, Binaryen chooses one of two target strategies.

### Strategy A: reuse an existing source local directly

If the candidate set’s value is literally:

- `local.get $src`

and the source local also has a very tiny graph surface:

- exactly one get
- exactly one set

then Binaryen reuses that source local index as the canonical slot.

This is the pure copy-chain collapse case.

Beginner version:

- if this local is only a thin alias of one already-tiny source local,
- do not invent a new temp,
- just redirect the whole group back to the original source slot

### Strategy B: create one fresh temp local

Otherwise, if the value is simple but not just that trivial reusable `local.get`, Binaryen does:

- `Builder::addVar(func, set->type)`

and records a mapping from the new temp to the original local.

Beginner version:

- if the source story is simple enough to share,
- but not simple enough to collapse directly into an existing source local,
- materialize one canonical temp and make the whole group read that temp instead

This is an extremely important beginner correction.

`merge-locals` is allowed to create a new local.
It is not “only reduce locals, never add one.”

The point is to normalize a whole alias group around one canonical slot, even if that canonical slot is fresh.

## 8. The mapping is by local index, not by one specific get node

For each influenced get, the pass records:

- `originalToOptimized[get->index] = optimizedTo`

That means the rewrite model is whole-local for the proven group:

- once Binaryen has proved the local’s gets all belong to the same simple-source story,
- it remaps the local index itself to the canonical slot

This is why the early filtering is so strict.
Once the pass commits, it is doing an index-level rewrite, not a one-off get-site patch.

## 9. `LocalGraph::postWalkFunction(...)` materializes the rewrite

If no mappings were found, the pass exits.
Otherwise it calls:

- `graph.postWalkFunction(this, func, module)`

and the walker callback `postGraph(...)` performs the visible IR rewrite.

At the durable behavior level, this post-pass does three things:

- retarget eligible `local.get` nodes to the canonical slot
- retarget eligible `local.set` nodes to the canonical slot
- delete redundant copy-only sets when the graph-guided rewrite proves they are now pointless

I did **not** fully rederive every internal `LocalGraph` post-walk invariant from source beyond the visible pass callback and helper comments. So the safest precise claim is:

- the graph-guided post-walk is the materialization phase,
- and the shipped tests plus callback logic clearly show that Binaryen rewrites indices and drops redundant copy sets there.

That is an explicit inference from the source structure and test output, not a line-by-line restatement of all `LocalGraph` internals.

## Important helper dependencies

## `LocalGraph`

This is the main helper dependency.
It provides:

- set/get collections
- transitive set influence computation
- the graph-guided post-walk used to materialize rewrites

If a future Starshine port does not have something morally equivalent to `LocalGraph`, it will probably either:

- miss transitive / DAG opportunities, or
- over-merge unsafe multi-source cases

## `FunctionUtils::isSimple(...)`

This is the safety gate on mergeable values.
It relies on `EffectAnalyzer`, so the pass is explicitly depending on Binaryen’s effect model for reorder safety.

That means `merge-locals` is not a pure syntactic pass.

## `pass.cpp` and `opt-utils.h`

These files matter because scheduler placement is part of the real contract:

- higher optimize/shrink gate only
- after `heap2local`
- before `optimize-casts`, `local-subtyping`, and `coalesce-locals`
- rerun inside later optimizing cleanups under stronger settings

## What the shipped tests teach

`test/lit/passes/merge-locals.wast` is small but very informative.
The most important test families are:

- `arity0`
- `arity1`
  - branch / result-shape cases showing the pass can normalize alias locals even when the surrounding control surface is not just one straight-line basic block
- `order gets it right`
- `reorder it right`
- `transitive1`
- `transitive2`
- `update working get with influences`
  - order-sensitive and transitive copy-chain cases showing why LocalGraph influences matter
- `merge in a DAG`
  - one simple source story can fan out through multiple alias locals and still be normalized
- `loop-backedge`
  - loop-carried copy traffic is a real positive case
- `keepSimple1`
- `keepSimple2`
  - control-heavy / looping source values are deliberately left alone
- `between-unreachable`
  - the pass remains conservative and valid around unreachable/control-edge weirdness instead of trying to be clever there

These tests reinforce the actual contract:

- positive cases are about one simple source story flowing through alias locals
- negative cases are about complexity, multiple provenance, or awkward control structure

## Important positive, negative, and bailout shapes

## Positive family 1: simple one-source alias chain

Shape:

- one local gets one simple value
- a later local copies it
- maybe another local copies that copy
- all final uses still trace back to the same single source set

Expected behavior:

- the chain collapses to one canonical slot
- redundant copy sets disappear

## Positive family 2: DAG-like fanout from one simple source

Shape:

- one simple source local
- multiple local aliases in different regions still trace back to that one source story

Expected behavior:

- Binaryen can still normalize the whole alias group because influence tracking is not limited to a single linear pair

## Positive family 3: loop-backedge alias traffic

Shape:

- a loop backedge re-copies a local story through another local

Expected behavior:

- `merge-locals` can still collapse that copy chain
- the dedicated test proves Binaryen wants that case, not just straight-line cases

## Negative family 1: multiple sets to the same local

Shape:

- local has more than one set site

Expected behavior:

- immediate bailout

Why:

- the whole pass is built on a single-set provenance story

## Negative family 2: set value is not simple enough

Shape:

- the only set’s value is control-heavy, effectful, or otherwise not reorderable under `FunctionUtils::isSimple`

Expected behavior:

- bailout

Why:

- the pass is willing to retarget alias locals, but only for values that the effect model says are safe to treat as simple

## Negative family 3: influenced gets do not all belong to that one set

Shape:

- a candidate looks single-set locally,
- but some gets in the wider graph are influenced by another set story

Expected behavior:

- those gets are filtered out
- if no good influenced gets remain, the candidate is abandoned

Why:

- Binaryen wants one clear provenance story before doing an index-level rewrite

## Bailout family 4: local names present

Shape:

- function carries local names

Expected behavior:

- skip the whole pass for that function

Why:

- current implementation chooses debug/name preservation over optimization here

## Bailout family 5: unreachable/control weirdness

Shape:

- alias traffic appears around unreachable edges or otherwise awkward control transitions

Expected behavior:

- Binaryen stays conservative
- the pass should not miscompile or aggressively over-merge there

The dedicated `between-unreachable` test exists specifically because this boundary is easy to get wrong.

## What is easy to misunderstand

## Misread 1: “merge-locals is just a smaller coalesce-locals”

Wrong.

`coalesce-locals`:

- is liveness/value-aware slot coloring
- works across many locals with interference reasoning
- is nonlinear in number of locals
- is much wider in scope

`merge-locals`:

- is a LocalGraph single-set alias normalizer
- runs earlier
- is much narrower
- focuses on simple-source provenance and redundant alias locals

## Misread 2: “the pass is in the normal `-O` / `-Os` path”

Wrong for `version_129`.

The real gate is:

- `optimizeLevel >= 3 || shrinkLevel >= 2`

So it matters for stronger modes, including the saved `-O4z` audit, but not for the repo’s canonical ordinary no-DWARF path.

## Misread 3: “merge-locals only removes locals and never creates one”

Wrong.

Binaryen may allocate a fresh temp local to act as the canonical shared slot.
The pass is about simplifying an alias group, not about monotonically reducing the local declaration count at every intermediate step.

## Misread 4: “any one-set local can be merged”

Wrong.

The value must also be simple enough under `FunctionUtils::isSimple`, and the influenced gets must still cleanly trace back to the same set.

## Misread 5: “debug/name metadata is handled automatically”

Wrong.

The current implementation takes a simpler policy:

- if local names are present, skip the function

## Porting invariants for Starshine

A future Starshine port should preserve these source-derived invariants:

1. **scheduler gate**
   - only run at the stronger `optimizeLevel >= 3 || shrinkLevel >= 2` surface, not in the ordinary no-DWARF `-O` / `-Os` path
2. **scheduler placement**
   - place it after `heap2local` and before `optimize-casts`, `local-subtyping`, and `coalesce-locals`
3. **single-set provenance rule**
   - only attempt the optimization on locals with exactly one set story
4. **simple-value rule**
   - use an effect-aware notion of reorderable / simple source values, not a purely textual heuristic
5. **LocalGraph-like influence reasoning**
   - preserve transitive / DAG / loop-backedge alias opportunities without over-merging multi-source locals
6. **canonical-slot split**
   - preserve the difference between:
     - direct reuse of an existing tiny source local when the set is a direct `local.get`, and
     - fresh-temp canonicalization for other simple-source cases
7. **whole-function local-name bailout or equivalent metadata policy**
   - do not silently worsen local-name/debug info behavior
8. **conservative unreachable behavior**
   - preserve the `between-unreachable` style safety boundary
9. **no fake widening of scope**
   - do not quietly turn this pass into `coalesce-locals`, liveness coloring, type narrowing, or a general copy-propagation pass

## Uncertainty and inference notes

- I did **not** rederive every internal `LocalGraph::postWalkFunction(...)` mutation detail beyond what the helper comments, pass callback, and test outputs make durable. So when I say the post-walk “materializes” retargeted gets / sets and drops redundant copies, that is a source-backed high-confidence summary, but some of the intermediate callback mechanics remain an implementation-detail inference.
- I did a narrow freshness check against current upstream `main`, not a full trunk audit of every nearby helper file. So the note is still grounded in `version_129` first.
- `agent-todo.md` currently has no dedicated `merge-locals` slice. That absence is a repo-local planning fact, not an upstream claim.

## Bottom line

Binaryen’s `merge-locals` pass is a narrow, higher-aggression, LocalGraph-driven alias-local cleanup.

It is **not** the same thing as:

- ordinary copy propagation
- `coalesce-locals`
- local type refinement
- a generic late no-DWARF optimizer slot

The real contract is:

- one-set locals only
- simple reorderable source values only
- influenced gets must still trace back to that exact source story
- then normalize the whole group around one canonical slot, sometimes by reusing an existing source local and sometimes by creating a fresh temp

That is the behavior a future Starshine port must preserve.

## Sources

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

### Official Binaryen sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-locals.wast>
- narrow freshness checks:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
