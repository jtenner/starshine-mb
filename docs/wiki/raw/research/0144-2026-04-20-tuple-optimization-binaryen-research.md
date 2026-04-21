# 0144 - Binaryen `tuple-optimization` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the new `remove-unused-names` dossier.
- Follow the repo wiki process in `docs/README.md`.
- Re-check the upstream implementation against Binaryen `version_129`.
- Justify an already-`deep` fallback pick explicitly, because the tracker now says the old implemented-landing queue is clear.
- Deepen the existing `tuple-optimization` folder with a fresher source-backed explanation of how Binaryen itself implements the pass.
- Keep the explanation beginner-friendly without hiding the important tuple-local, scheduler, and tee-ordering details.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/tuple-optimization/`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`

## Candidate selection

I followed the campaign instructions in order:

1. read `docs/README.md`
2. read `docs/wiki/binaryen/passes/tracker.md`
3. read `docs/wiki/binaryen/passes/index.md`
4. read `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
5. re-checked `agent-todo.md`

The tracker no longer had any pass with wiki status `none`, and the implemented-landing queue was already clear.
So this run needed a justified major-gap fallback instead of another obvious `none` or `landing` pick.

I picked `tuple-optimization` for three source-backed reasons:

- It is still on the canonical no-DWARF function path:
  - `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure`
- It is also still relevant to the saved generated-artifact `-O4z` audit, even though it is not one of the saved skipped-unimplemented slots:
  - the committed `.artifacts/o4z-wasm-opt-debug.log` shows repeated real `tuple-optimization` executions, both in the early top-level neighborhood and in later nested `precompute-propagate -> code-pushing -> tuple-optimization` reruns
- The existing folder was useful, but it was still mostly a port-plan / Starshine-history dossier:
  - it grew out of the older `0076` note
  - it did not yet have a dedicated living page focused on the exact upstream file map, implementation structure, helper dependencies, and official test-surface lessons
  - the landing page still had stale wording about red exact-shape expectations that no longer matched the newer parity page

So this is not a tracker-status promotion job.
It is a "the folder exists, but the Binaryen implementation teaching surface still has a real gap" job.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- implementation:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
- pass registration and scheduler placement:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- earlier tuple peephole that deliberately lives outside this pass:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
- tuple finalize semantics:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp>
- tuple validation rules:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp>
- dedicated upstream lit surface:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast>

## Freshness check

I also did a narrow direct source comparison against current GitHub `main` for:

- `src/passes/TupleOptimization.cpp`
- `src/passes/pass.cpp` around the `tuple-optimization` scheduler slot
- the tuple-specific `visitTupleExtract` section in `OptimizeInstructions.cpp`
- `test/lit/passes/tuple-optimization.wast`

Durable result:

- `TupleOptimization.cpp` is unchanged relative to `version_129`
- the relevant `pass.cpp` registration and scheduler lines are unchanged
- the tuple-specific `OptimizeInstructions.cpp` section is unchanged even though the file has unrelated drift elsewhere
- `tuple-optimization.wast` is unchanged

So the correct wiki rule for this pass is:

- treat Binaryen `version_129` as the released oracle
- do not carry an active current-main drift warning for the core tuple-opt implementation or its dedicated lit suite today

That statement is intentionally narrow.
It does not claim every neighboring file in the whole repo is identical.

## Repo-local sources used for context

Starshine-side files relevant to this dossier refresh:

- `src/passes/tuple_optimization.mbt`
- `src/passes/tuple_optimization_wbtest.mbt`
- `src/cmd/cmd_wbtest.mbt`
- `src/cmd/cmd_native_wbtest.mbt`
- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `docs/wiki/raw/research/0076-2026-04-01-tuple-optimization-binaryen-port-plan.md`
- `docs/wiki/raw/research/0115-2026-04-20-code-pushing-binaryen-research.md`
- `agent-todo.md` (`[TO]005`)

## High-level conclusion

Binaryen `tuple-optimization` is much smaller and narrower than the name suggests.

It is **not** a general multivalue optimizer.
It is **not** a CFG-sensitive tuple dataflow pass.
It is **not** a broad block / branch / return multivalue simplifier.

In `version_129`, it is a small function-parallel tuple-local splitter with this contract:

1. find tuple locals whose writers are only `tuple.make` or tuple-local copies
2. find tuple locals whose readers are only `tuple.extract` or tuple-local copies
3. mark copy-connected components bad if any member escapes that narrow contract
4. allocate one scalar local per tuple lane for every good tuple local
5. rewrite tuple writes into scalar local writes
6. rewrite tuple extracts into scalar local gets
7. leave the actual dead-lane cleanup to later local passes

That means the pass's most important teaching correction is:

- Binaryen is optimizing a very specific **tuple scratch-local** pattern
- it is not trying to lower arbitrary multivalue control-flow structure just because tuples are involved somewhere nearby

## Why the upstream implementation is easy to misread

The file is short.
That tempts readers into one of two wrong ideas.

### Wrong idea 1: “This pass barely does anything.”

It is true that the file is compact.
But it sits in a strategically chosen scheduler slot:

- after `optimize-instructions`, which can already remove the direct `tuple.extract(tuple.make(...))` family
- after `code-pushing`, which may sink tuple-producing work into a more local region
- before `simplify-locals-nostructure`, where scalar locals are much easier to clean up than tuple locals

So the pass is small because Binaryen gives it a narrow mission and good neighbors, not because the mission is irrelevant.

### Wrong idea 2: “Tuple optimization means Binaryen is lowering every multivalue shape.”

The source comment explicitly rejects that broader reading.
It says blocks and related constructs might be handled in theory, but that they are not obviously always worth lowering.

Upstream today only handles shapes that are “definitely worth lowering.”
That phrase matters.
The pass is intentionally conservative.

## Exact Binaryen implementation structure

`TupleOptimization.cpp` defines one pass:

- `struct TupleOptimization : public WalkerPass<PostWalker<TupleOptimization>>`

Two immediate pass-level facts matter:

- `isFunctionParallel() == true`
- the pass does not request heavyweight analyses such as CFG, effects, liveness, or dominance

The implementation is organized into a tiny set of phases.

### Phase 1: early gate in `doWalkFunction`

The pass immediately returns if:

- multivalue is disabled
- the function has no tuple locals at all

This is an important scheduler lesson.
The multivalue feature gate is semantic, but the tuple-local scan is also a real performance gate.
Binaryen does not bother walking the body further if no tuple local exists.

### Phase 2: collect three per-local structures during the post-walk

The walker fills:

- `uses`
- `validUses`
- `copiedIndexes`

The central idea is simple:

- if every use of a tuple local is one of the approved patterns, it is safe
- if any use falls outside that set, it is bad
- if two tuple locals copy each other, badness must spread across the whole connected component

#### `visitLocalGet`

- counts tuple-typed `local.get` uses

#### `visitLocalSet`

For tuple locals, it:

- counts writes as uses too
- counts a `local.tee` as two uses because it both writes and yields a value
- approves only three writer families:
  - `tuple.make`
  - tuple-local copy from `local.get`
  - reachable tuple-local copy from `local.tee`
- records tuple-local copy edges symmetrically in `copiedIndexes`

The reachable-tee rule is easy to miss and important:

- if the inner tee is `unreachable`, Binaryen refuses to treat it as a valid tuple copy
- the source comment explains why: unreachable code can make the apparent tuple type unreliable, so the pass deliberately leaves that cleanup to other passes first

#### `visitTupleExtract`

- approves tuple-local reads only when the extracted tuple comes from a tuple `local.get` or a tuple `local.tee`

This is a very strong scope limit.
The pass is not tracking all possible tuple consumers.
It approves exactly the readers it knows how to scalarize cleanly.

### Phase 3: badness propagation in `optimize`

After collection, `optimize`:

- seeds bad tuple locals where `validUses < uses`
- propagates badness across `copiedIndexes` with `UniqueDeferredQueue<Index>`
- marks the remaining used tuple locals as good

That queue choice matters conceptually even though the code is tiny.
Binaryen is doing connected-component poisoning, not isolated-local approval.

This is the pass's most important safety invariant:

- if any tuple local in a copy-connected component escapes, the whole component is disqualified

### Phase 4: allocate fresh contiguous scalar locals

For each good tuple local, Binaryen allocates:

- one new local per tuple lane
- contiguously

The pass stores only the base local index for each optimized tuple local.
All other lane locals are recovered by offset from that base.

This is not just a small convenience.
It is part of the code shape the rewrite phase depends on.

### Phase 5: `MapApplier` rewrites the function body

Binaryen then runs a nested `MapApplier` walker that performs the actual rewrite.

Its important helpers are:

- `getNewBaseIndex`
- `getSetOrGetBaseIndex`
- `visitLocalSet`
- `visitTupleExtract`
- `replacedTees`

#### `visitLocalSet`

When the target tuple local is good:

- writing `tuple.make` becomes one scalar `local.set` per lane
- writing from another tuple local becomes one scalar `local.get` plus `local.set` per lane

A subtle but important detail:

- Binaryen uses the **source tuple lane types** when copying from another tuple local
- it does not blindly re-read lane types from the destination tuple

That is how the pass preserves element subtyping correctly across tuple-local copies.
The dedicated lit suite has an explicit `nullref` to `eqref` example for this.

#### `visitTupleExtract`

When the source tuple local is good:

- `tuple.extract` becomes a scalar `local.get` of the right split lane local

#### `replacedTees`

This is the easiest internal detail to skip when skimming the file, but it is part of the real contract.

When a tuple `local.tee` is rewritten:

- the original tuple-valued tee expression disappears
- later users of that expression still need the same yielded lane value

So Binaryen stores a mapping from replacement expression to the original tee expression and, when needed, returns:

- `sequence(extra tee replacement work, local.get selected-lane)`

That mechanism is why the pass preserves tee ordering and tee result identity without leaving the tuple local itself around.

## Helper dependencies and what they mean

One major documentation gap in the old tuple folder was that it did not say clearly enough how *lightweight* the upstream helper story is.

The core upstream dependencies are only:

- `PostWalker`
- `Builder`
- `UniqueDeferredQueue`
- normal tuple / local AST node types from `wasm.h`

The key non-pass files that matter are not heavyweight dataflow helpers.
They are semantic neighbors:

- `pass.cpp`
  - tells you exactly where the pass is scheduled and why
- `OptimizeInstructions.cpp`
  - handles the direct `tuple.extract(tuple.make(...))` peephole **before** tuple-opt runs
- `wasm.cpp`
  - shows that `TupleMake::finalize()` produces a tuple type from its operands and that `TupleExtract::finalize()` simply projects one element or stays unreachable
- `wasm-validator.cpp`
  - shows the feature gate, the `tuple.make` arity rule, the tuple-extract bounds rule, and the subtype check between extracted element type and result type

So a future port should **not** assume this pass needs CFG, effects, liveness, or dominance.
If the target IR needs those analyses, that is probably because the target IR is not modeling Binaryen's tuple-local surface as directly as Binaryen does.

## Official test-surface lessons

The dedicated upstream lit file is unusually instructive for such a small pass.
It proves all of the following families.

### Positive families

- write-only tuple locals are still worth splitting (`just-set`)
- read-only tuple locals use default lane values from the new scalar locals (`just-get`)
- mixed read/write tuple locals split cleanly (`set-and-gets`)
- tuple-local copy chains split across all links (`tee`, `set-after-set`, `chain-3`)
- tuple-tee consumers preserve yielded values (`just-tee`, `tee-chain`)
- tuple locals with no later readers can still be optimized if the traffic stays in the approved copy family (`no-uses`)
- element subtyping across tuple-local copies is preserved (`tuple.element.subtyping`)
- tuple sizes do not need to match globally across the whole function; separate good tuple-local families can still be optimized independently (`two-2-three`, `three-2-two`)

### Negative / bailout families

- if a tuple local escapes as a whole tuple value, the whole component must stay untouched (`just-get-bad`, `corruption-*`, `chain-3-corruption`)
- setting a tuple local from a call is outside the pass's scope (`set-call`)
- tuple ops that do not involve locals are deliberately left for other passes (`make-extract-no-local`, `make-extract-no-local-but-other`)
- setting a tuple local from a `block` result is not handled here (`set-of-block`)
- unreachable tuple-like traffic should not crash the pass and generally does not count as valid optimizable traffic (`unreachability`, `unreachable.tuple.extract`)

Those test families are strong evidence for the correct beginner summary:

- this pass is a tuple-local scratch-storage splitter, not a generic multivalue lowering pass

## Scheduler meaning

The scheduler comment in `pass.cpp` says two things at once:

- run tuple-opt **before** local opts, because splitting tuples helps them
- do not run it too early; be **after** `optimize-instructions` at least, because that pass can remove tuple-related things first

The practical no-DWARF neighborhood is:

- `precompute`
- `code-pushing`
- `tuple-optimization`
- `simplify-locals-nostructure`

That neighborhood is not accidental.

- `precompute` can expose simpler tuple-producing expressions
- `code-pushing` can move work into a more local region before the tuple local is split
- `tuple-optimization` lowers good tuple locals into scalar locals
- `simplify-locals-nostructure` and later local-cleanup passes realize the payoff

The saved generated-artifact `-O4z` debug log also shows repeated later runs of:

- `precompute-propagate -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum`

So tuple-opt is part of both:

- the canonical top-level no-DWARF path
- the observed nested cleanup story in the saved generated-artifact optimize run

## What is easy to misunderstand

### 1. The pass does not optimize all tuple-producing expressions

It only optimizes tuple **locals** in a narrow approved writer/reader/copy family.

### 2. `tuple.extract(tuple.make(...))` is not the main rewrite here

That direct peephole belongs to `OptimizeInstructions.cpp`, not `TupleOptimization.cpp`.

### 3. The pass is not trying to invent better control-flow structure

The source TODO is explicit that block-related multivalue lowering is not obviously always profitable or smaller.
So Binaryen leaves that broader territory alone here.

### 4. The pass is more about helping later passes than about showing immediate code-size wins itself

The direct output often looks like “just more scalar locals.”
The real benefit comes later when local cleanup can see dead lanes, dead copies, and dead stores.

### 5. Tee handling is part of the core contract, not a tiny corner case

`replacedTees` exists because tee-preserving scalarization is central to this pass's correctness story.

## What a future Starshine port or maintenance pass must preserve

Even though Starshine already has a HOT-native implementation, the upstream Binaryen contract still gives a clear checklist.

A faithful implementation must preserve:

1. the multivalue feature gate
2. the “must actually have tuple locals” cheap function gate
3. the `uses` versus `validUses` safety model
4. connected-component poisoning across tuple-local copies
5. reachable-tee conservatism in unreachable code
6. contiguous per-lane scalar replacement semantics
7. tee result identity and ordering
8. element-type preservation across copied tuple lanes, including subtype cases
9. the division of labor with `optimize-instructions`
10. the scheduler neighborhood before local-cleanup passes

A faithful implementation does **not** need to preserve the exact C++ surface, but it should preserve those semantics.

## Durable documentation outcomes from this thread

This thread adds a fresher tuple-opt teaching surface that the older folder lacked:

- a new raw note anchored in official `version_129` sources and the saved generated-artifact debug log
- a refreshed landing page that removes stale parity wording and explicitly justifies the pass's continued relevance
- a refreshed Binaryen-strategy page with the exact upstream phase structure and “what it is not” corrections
- a refreshed WAT-shape page that leans more directly on the official lit families
- a new living page focused on the upstream implementation structure, helper dependencies, validation/finalize neighbors, and test-surface lessons

## Files updated in this change

- `docs/wiki/raw/research/0144-2026-04-20-tuple-optimization-binaryen-research.md`
- `docs/wiki/binaryen/passes/tuple-optimization/index.md`
- `docs/wiki/binaryen/passes/tuple-optimization/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/tuple-optimization/wat-shapes.md`
- `docs/wiki/binaryen/passes/tuple-optimization/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Sources

- Repo process and tracker context:
  - `docs/README.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
- Saved optimize-run context:
  - `.artifacts/o4z-wasm-opt-debug.log`
  - `docs/wiki/raw/research/0115-2026-04-20-code-pushing-binaryen-research.md`
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-validator.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/tuple-optimization.wast>
- Narrow freshness-check surface on current `main`:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TupleOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeInstructions.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/tuple-optimization.wast>
