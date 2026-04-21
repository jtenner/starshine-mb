# 0117 - `simplify-locals-nostructure` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what upstream `simplify-locals-nostructure` actually does, what source files and helper analyses matter, which local / control / trap / unreachable shapes it rewrites, what it deliberately refuses to do, and what a future Starshine port must preserve.

## Why this pass

- The updated pass tracker still listed `simplify-locals-nostructure` with wiki status `none` when this run started.
- It was also the first suggested next dossier target in `docs/wiki/binaryen/passes/tracker.md` after the earlier `code-pushing`, `optimize-casts`, `code-folding`, `merge-blocks`, `rse`, and `local-subtyping` dossiers landed.
- No dedicated living folder existed yet under `docs/wiki/binaryen/passes/simplify-locals-nostructure/`, so this was still an eligible new dossier rather than overlap with an existing deep page.
- The pass matters to both of the main Binaryen parity stories in this repo:
  - the canonical Binaryen no-DWARF `-O` / `-Os` path
  - the saved generated-artifact `-O4z` audit
- It sits in an especially helpful neighborhood for future Starshine work:
  - after `code-pushing`
  - after `tuple-optimization`
  - before `vacuum`
  - before the first `reorder-locals`
- That makes it one of the missing scheduler neighbors that still blocks fully honest preset placement around the already-implemented `tuple-optimization` and `reorder-locals` work.
- The name is unusually easy to misunderstand. It sounds like:
  - “full simplify-locals, but maybe slightly weaker”
  - or “a flat / non-nesting pass”
  - or “the same as no-tee”
- The actual `version_129` implementation is more specific:
  - it is exactly `SimplifyLocals<true, false, true>`
  - it still allows tee creation
  - it still allows nesting into existing expression positions
  - it specifically disables the block / `if` / loop return-building structure rewrites
  - it still runs the late equivalent-get canonicalization and final dead-set cleanup

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/simplify-locals/index.md`
- `docs/wiki/binaryen/passes/simplify-locals/binaryen-strategy.md`
- `docs/wiki/raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/SimplifyLocals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/local-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `src/ir/equivalent_sets.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
- `src/ir/linear-execution.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `README.md`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
- `test/passes/simplify-locals-nostructure.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
- `test/passes/simplify-locals-nostructure.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
- `test/passes/simplify-locals-notee-nostructure.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
- `test/passes/simplify-locals-notee-nostructure.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
- `test/passes/simplify-locals-nonesting.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
- `test/passes/simplify-locals-nonesting.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
- `test/passes/simplify-locals.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
- `test/passes/simplify-locals.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
- `test/passes/simplify-locals_all-features.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals_all-features.wast>
- `test/passes/simplify-locals_all-features.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals_all-features.txt>
- `test/passes/simplify-locals_all-features_disable-exception-handling.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals_all-features_disable-exception-handling.wast>
- `test/passes/simplify-locals_all-features_disable-exception-handling.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals_all-features_disable-exception-handling.txt>

## Fast answer

Binaryen’s `simplify-locals-nostructure` pass is the **early no-structure member of the simplify-locals family**.

What it really does in `version_129` is:

1. instantiate the shared simplify-locals engine as `SimplifyLocals<true, false, true>`
2. count `local.get` uses up front
3. run a fixpoint over linear traces
4. on the first cycle, sink only easy single-use locals
5. on later cycles, allow tee creation for multi-use locals
6. keep effect- and control-based invalidation conservative
7. skip the structure-building rewrites for:
   - loop returns
   - block returns
   - `if` / `if-else` returns
8. still run the late equivalent-local get canonicalization
9. still run the final dead-set cleanup through `UnneededSetRemover`
10. refinalize when a sink or canonicalization changes visible types

Important durable facts:

- `no-structure` does **not** mean “no tee”.
- `no-structure` does **not** mean “no nesting”.
- `no-structure` does **not** mean “skip late cleanup”.
- The actual disabled feature is specifically the creation of new structured return values for blocks, loops, and `if`s.
- The pass still performs real local sinking, real tee creation, real equivalent-get canonicalization, and real dead-set removal.
- The main scan is deliberately linear-trace based, not a full CFG dataflow pass.
- The late equivalent-copy phase is deliberately narrower here than in full `simplify-locals`: it canonicalizes gets, but it does not remove equivalent sets because `removeEquivalentSets = allowStructure`.

A safer short description is:

> `simplify-locals-nostructure` is Binaryen’s early local-traffic cleanup pass that still sinks and tees locals, but deliberately refuses to create new structured block / if / loop return values.

That matches the implementation much better than the name alone.

## Naming and variant identity

The most important source-level fact is the template instantiation.

In `SimplifyLocals.cpp`, the relevant public constructors are:

- `createSimplifyLocalsPass()` -> `SimplifyLocals<true, true>()`
- `createSimplifyLocalsNoTeePass()` -> `SimplifyLocals<false, true>()`
- `createSimplifyLocalsNoStructurePass()` -> `SimplifyLocals<true, false>()`
- `createSimplifyLocalsNoTeeNoStructurePass()` -> `SimplifyLocals<false, false>()`
- `createSimplifyLocalsNoNestingPass()` -> `SimplifyLocals<false, false, false>()`

So the no-structure variant is exactly:

- `allowTee = true`
- `allowStructure = false`
- `allowNesting = true`

That one line already corrects three common misunderstandings.

## Where it appears in the scheduler

## Top-level no-DWARF path

Binaryen `version_129` `pass.cpp` places `simplify-locals-nostructure` in the default function pipeline after the early tuple/local-prep cluster.

In the canonical no-DWARF path tracked in this repo, the relevant neighborhood is:

- `precompute`
- `code-pushing`
- `tuple-optimization`
- `simplify-locals-nostructure`
- `vacuum`
- `reorder-locals`
- `remove-unused-brs`
- `heap2local`
- `optimize-casts`
- `local-subtyping`
- `coalesce-locals`
- `local-cse`
- `simplify-locals`

That ordering matters.

The upstream scheduler comment says:

- do not create `if` / block return values yet

The later full `simplify-locals` pass is the place where those structure-building rewrites are intentionally allowed.

## `-O4` / flatten special path

`pass.cpp` also uses a no-structure family member earlier in the heavy `-O4` path:

- `flatten`
- `simplify-locals-notee-nostructure`
- `local-cse`

That is a separate, stricter variant.

This is another reason it is important to distinguish:

- no-structure
- no-tee-no-structure
- full simplify-locals

instead of treating them as one fuzzy “locals cleanup” pass.

## Saved generated-artifact `-O4z` audit

The saved ordered audit in this repo records `simplify-locals-nostructure` as a real missing top-level slot:

- slot `22`: `simplify-locals-nostructure`

The saved Binaryen debug log also shows many later repeated executions of the same neighborhood.
A repo-local count over `.artifacts/o4z-wasm-opt-debug.log` finds `18` occurrences of `running pass: simplify-locals-nostructure`, not just the one top-level slot.

That matters because it confirms the nested rerun story is real for this pass too.

## Nested reruns

`opt-utils.h` shows that Binaryen’s `optimizeAfterInlining(...)` helper prepends `precompute-propagate` and then reruns the default function optimization pipeline on touched functions.

That means `simplify-locals-nostructure` can reappear under optimizing passes like:

- `dae-optimizing`
- `inlining-optimizing`
- `simplify-globals-optimizing`

For Starshine parity, the durable scheduler lesson is:

- the top-level `simplify-locals-nostructure` slot matters
- the nested rerun sites matter too
- the exact neighboring passes (`code-pushing`, `tuple-optimization`, `vacuum`, `reorder-locals`) are part of its practical meaning

## Actual implementation structure

## 1. The pass is a shared engine with one disabled capability

The core engine in `SimplifyLocals.cpp` is a single template:

- `SimplifyLocals<allowTee, allowStructure, allowNesting>`

For this dossier, the important thing is not that Binaryen has five public names.
The important thing is that they all share one implementation and differ mainly by which rewrite families are enabled.

For `simplify-locals-nostructure`:

- tee creation is still enabled
- structure rewrites are disabled
- nesting into existing expression positions is still allowed

## 2. The pass starts by counting gets

`LocalGetCounter` from `local-utils.h` counts how many `local.get`s each local still has.

That count drives the main distinction between:

- single-use locals that can be inlined directly
- multi-use locals that may need a tee on later cycles
- locals with zero gets that the late cleanup can erase entirely

This is why the pass is not reducible to an adjacent set/get peephole.
The profitability and legality of the rewrite depends on future use count.

## 3. The fixpoint intentionally begins with a stricter first cycle

`doWalkFunction(...)` sets `firstCycle = true` and then iterates until no more useful changes are found.

The first cycle is intentionally conservative:

- `canSink(...)` rejects a set with more than one use when `firstCycle` is true
- so the first cycle only handles easy single-use sinks
- after that first cycle, Binaryen forces another cycle
- later cycles may create tees when `allowTee` is true

That split is part of the real Binaryen algorithm.
It is not just an incidental optimization hack.

## 4. The main scan is linear-trace based, not full CFG dataflow

The pass inherits from `LinearExecutionWalker` and keeps one map of pending sinkable sets for the current linear trace:

- `sinkables : local index -> SinkableInfo`

It also uses custom bookkeeping for non-linear points:

- `blockBreaks`
- `unoptimizableBlocks`
- `ifStack`

The important behavior is conservative.

When Binaryen reaches non-linear control, it does **not** try to preserve arbitrary equalities across the split.
Instead it typically:

- saves exactly what it knows for one branch side
- clears the active sinkable set
- or marks a target unoptimizable

So a faithful port should think:

- “cheap linear traces with conservative resets”

not:

- “full SSA or CFG propagation”.

## 5. `optimizeLocalGet(...)` has the core sink outcomes

When the scan sees a `local.get`, it checks whether there is a pending sinkable set for the same local.
If so, the canonical outcomes are:

### Outcome A: single-use sink

If the local has one use in this cycle:

- replace the `local.get` with the set’s value
- turn the old set origin into `nop`
- erase the sinkable entry

If the replacement value has a more refined type than the old `local.get`, the pass records `refinalize = true`.

### Outcome B: multi-use tee sink

If the local still has multiple uses, but teeing is enabled and this is not the first cycle:

- replace the `local.get` with the `local.set`
- turn that `local.set` into a `local.tee`
- nop the old origin
- erase the pending sinkable entry

This is why `simplify-locals-nostructure` still creates tees.
The dedicated `contrast` test locks that in.

## 6. `visitDrop(...)` immediately collapses `drop(tee(...))`

If sinking into a use site creates:

- `drop(local.tee ...)`

then `visitDrop(...)` rewrites it back to:

- `local.set ...`

This is a small but important cleanup rule.
Without it, the no-structure pass would leave behind a lot of pointless tee-shaped noise after an otherwise good sink.

## 7. Overwritten pending sets are removed before any read

During `visitPost(...)`, if the current `local.set` writes a local that already has a pending sinkable set, the earlier pending write is dead.

Binaryen then:

- converts the old set into `drop(oldValue)`
- removes the old pending sinkable
- keeps scanning with the newer write as the relevant one

This is another reason the pass is more than a set/get peephole.
It also does overwrite cleanup on the same linear trace.

## 8. The barrier model uses directional effect ordering

`checkInvalidations(...)` compares the current effects against every pending sinkable using:

- `effects.orderedAfter(info.effects)`

The important implication is that Binaryen is not using a vague “any side effect blocks everything” rule.
It is using directional reordering logic from `effects.h`.

That logic can block motion for reasons including:

- local read/write conflicts
- mutable-global conflicts
- memory and table conflicts
- shared-memory order constraints
- control-flow transfer
- throwing behavior
- trap-vs-global-state hazards
- dangling `pop`

This is the core semantic safety story of the pass.

## 9. `try` / `try_table` adds an extra explicit barrier

In `visitPre(...)`, Binaryen does an additional pass-specific check:

- when entering `try` or `try_table`
- forget any pending sinkable whose value may throw

Reason:

- moving that value into the `try` could make it get caught there, changing semantics

This is one of the easiest pass-specific hazards to miss if someone only skims the generic effect rules.

## 10. `canSink(...)` is a small but important gate

A `local.set` is sinkable only if all of these hold:

- it is not already a tee
- its value does not contain a dangling `pop`
- if we are on the first cycle, or teeing is disabled, it has at most one use

That means `simplify-locals-nostructure` is still intentionally conservative on the first pass even though teeing is allowed overall.

## 11. What no-structure actually disables

The structure-building entry points are:

- `optimizeLoopReturn(...)`
- `optimizeBlockReturn(...)`
- `optimizeIfElseReturn(...)`
- `optimizeIfReturn(...)`

Those are only called when `allowStructure` is true.

So in the no-structure variant, Binaryen deliberately does **not** create new:

- loop result carriers
- block result carriers
- `if` / `if-else` result carriers
- synthetic `local.get` else-arms for one-armed `if` return lifting

This is the defining semantic difference from the full pass.

## 12. The late equivalent-copy phase still runs here

After the main sink loop stabilizes, `runLateOptimizations(...)` executes `EquivalentOptimizer`.

That phase still does meaningful work in the no-structure variant.

It tracks equivalent locals and can rewrite `local.get`s toward a better equivalent representative based on:

- more refined local type
- or more remaining gets

Subtle but important fact:

- `EquivalentOptimizer` sets `connectAdjacentBlocks = true`

So this late canonicalization phase is slightly more permissive across adjacent block structure than the main sink loop.

## 13. But equivalent-set deletion is disabled here

The late phase also has:

- `removeEquivalentSets = allowStructure`

So in `simplify-locals-nostructure`:

- get canonicalization is still on
- removing redundant equivalent copy sets is off

This is a major “sounds like vs actually does” correction.

The no-structure variant is not simply “full simplify-locals, but it avoids block returns.”
It also preserves some copy-set structure that the full pass may delete later.

## 14. The final dead-set cleanup still runs here

After equivalent-get canonicalization, Binaryen still runs `UnneededSetRemover` from `local-utils.h`.

That helper removes:

- sets whose local has zero gets
- sets or tees that simply write back the same local value
- tee chains that collapse to a same-value write

Side effects are preserved:

- dead pure `local.set` -> `nop`
- dead effectful `local.set` -> `drop(value)`
- dead `local.tee` -> raw value

This is a big reason the no-structure variant is still a meaningful cleanup pass on its own.

## 15. `ReFinalize` is part of the contract

The pass refinalizes when:

- a single-use sink replaces a `local.get` with a more refined value type
- equivalent-get canonicalization switches a get to a more refined local type
- late dead-set cleanup exposes more refined values after tee removal

A future Starshine port that copies the sink logic but skips refinalization would not be an honest Binaryen port.

## Helper dependency map

## `LocalGetCounter`

From `local-utils.h`.

Role here:

- counts `local.get`s
- drives single-use versus tee decisions
- lets late cleanup recognize zero-get locals

## `LinearExecutionWalker`

From `linear-execution.h`.

Role here:

- gives the main pass its cheap linear-trace model
- calls out non-linear control points conservatively
- keeps this pass cheaper and structurally simpler than a full CFG walk

## `EffectAnalyzer`

From `effects.h`.

Role here:

- gates sinkability and invalidation
- models local/global/memory/table/control conflicts
- encodes trap, throw, and dangling-`pop` barriers
- helps implement the explicit `try` / `try_table` guard

## `EquivalentSets`

From `equivalent_sets.h`.

Role here:

- tracks which locals currently hold the same value in the late phase
- supports get canonicalization and, in other variants, equivalent-set deletion

## `Properties::getFallthrough(...)`

From `properties.h`.

Role here:

- lets the late phase look through trivial wrappers when deciding whether a set is really copying another local’s current value

## `UnneededSetRemover`

From `local-utils.h`.

Role here:

- performs the final dead-set cleanup outside SSA assumptions
- preserves side effects while removing dead locals

## `ReFinalize`

Role here:

- repairs surrounding expression types after more refined values become visible

## What the shipped tests tell us

The dedicated no-structure test files are unusually informative here because they lock the exact boundary between:

- teeing still enabled
- structure lifting disabled
- late get canonicalization still enabled
- dead-set cleanup still enabled

The most useful test pairs were:

- `simplify-locals-nostructure.wast/.txt`
- `simplify-locals-notee-nostructure.wast/.txt`
- `simplify-locals.wast/.txt`
- `simplify-locals_all-features.wast/.txt`
- `simplify-locals_all-features_disable-exception-handling.wast/.txt`
- `simplify-locals-nonesting.wast/.txt`

Together they show the real upstream distinction between:

- no-structure
- no-tee-no-structure
- no-nesting
- full simplify-locals

## Important positive shapes

## Positive family 1: single-use sink into an existing consumer

This is the easiest success case.

If a local is written once and then read once in a later compatible site, Binaryen can inline the value directly into that use.

The `contrast` test shows this for existing value expressions like:

- `drop(local.get $y)`
- `drop(local.get $z)`

which become direct `drop(if ...)` and `drop(block ...)` uses.

## Positive family 2: later cycles may tee a multi-use local

The same `contrast` test shows the most important variant fact.

Input:

- one write to `$x`
- then two `if (local.get $x)` uses

No-structure output:

- the first use becomes `local.tee $x (...)`
- the second use remains `local.get $x`

So teeing is a real positive rewrite family here.

## Positive family 3: overwrite elimination removes dead earlier sets

When a later set to the same local appears before any real read, the earlier one is dead.

Binaryen keeps the earlier value only as a `drop(...)` when needed for effects.

## Positive family 4: local-only effects may still allow sinking

The `implicit-trap-and-local-effects` test shows an important nuance.

A trap-capable producer may still sink past a later local-only effect when that local effect does not create the kind of global semantic hazard that a memory or mutable-global effect would.

## Positive family 5: late get canonicalization still happens

The `multi-pass-get-equivs-right` test shows that even in no-structure mode, Binaryen still canonicalizes later gets toward a better equivalent local.

So the pass is not “main sink loop only.”
The late phase is part of the real contract.

## Positive family 6: dead unreachable local traffic still cleans up

The `no-unreachable` test shows that no-structure still reaches the final dead-set cleanup.

A dead tee around `unreachable` collapses all the way to plain `unreachable`.

## Important negative / bailout shapes

## Negative family 1: no new `if` return values

If both arms set the same local and a later `local.get` consumes it, full `simplify-locals` may turn that into an `if (result ...)` plus one outer set.

`simplify-locals-nostructure` does **not** do that.

The dedicated `contrast` output keeps:

- the `if`
- the arm-local `local.set`s
- the later `drop(local.get ...)`

## Negative family 2: no new block return values

Likewise, block / `br`-based local-carrier shapes are left structural.

The no-structure variant does not rewrite them into a value-returning block with one outer set.

## Negative family 3: no one-armed `if` speculative lifting

The full pass has a speculative one-armed `if` rewrite that can synthesize an else-side `local.get` for defaultable locals.

No-structure skips that entire family because it lives behind `allowStructure`.

## Negative family 4: no equivalent-set deletion

Even after get canonicalization proves two locals equivalent, the no-structure variant keeps some redundant copy sets that the full structured variant may later erase.

This is one of the least obvious but most important semantic limits.

## Negative family 5: throwing values do not sink into `try` / `try_table`

The explicit `visitPre(...)` barrier means potential throws are forgotten at a `try` boundary.

So even apparently local simplifications may stop cold there.

## Negative family 6: first cycle still refuses multi-use tee creation

Even though the variant allows tees overall, `firstCycle` still blocks the multi-use family.

So a port must preserve:

- easy single-use cleanup first
- tee creation only on later cycles

## Negative family 7: linear-trace control splits clear optimism

The main pass does not preserve arbitrary sinkable knowledge across non-linear control.

A future port should keep that conservatism instead of trying to invent a broader flow engine in the first implementation.

## The biggest “sounds like vs actually does” corrections

## What the name suggests

A beginner might hear `simplify-locals-nostructure` and imagine:

- simplify locals, but never build nesting
- simplify locals, but no teeing
- simplify locals, but skip the fancy late cleanup

## What `version_129` actually does

- teeing still happens
- nesting into existing expression positions still happens
- only the block / `if` / loop return-building transforms are disabled
- late equivalent-get canonicalization still runs
- final dead-set cleanup still runs
- only redundant equivalent-set deletion is disabled along with structure mode

That smaller and more precise reading is the one a future Starshine port should preserve first.

## Why it sits between tuple-opt and vacuum

This placement is not decorative.

- `code-pushing` and `tuple-optimization` may expose more obvious local traffic
- `simplify-locals-nostructure` then removes early local clutter without committing to block/if/loop return surgery too soon
- `vacuum` cleans up the garbage that earlier pass families left behind
- `reorder-locals` then works on a smaller, cleaner local set
- much later, after `local-cse`, the full `simplify-locals` run finishes the structure-sensitive cleanup

So the early and late simplify-locals passes are deliberately different tools.

## Future Starshine port contract

If Starshine ports `simplify-locals-nostructure`, preserve these facts first:

1. exact variant identity: `allowTee = true`, `allowStructure = false`, `allowNesting = true`
2. early no-DWARF scheduler placement after `tuple-optimization` and before `vacuum`
3. first-cycle single-use-only discipline
4. later-cycle tee creation for multi-use locals
5. linear-trace sink state with conservative resets at non-linear control
6. directional effect invalidation rather than a vague side-effect bit
7. explicit `try` / `try_table` throwing-value barrier
8. no block / `if` / loop return synthesis
9. late equivalent-get canonicalization still enabled
10. equivalent-set deletion still disabled in this variant
11. final dead-set cleanup through `UnneededSetRemover`
12. mandatory refinalization on refined-type exposure

Those are the durable upstream-level truths.

## Open questions and uncertainty

- I did not line-by-line audit every helper reachable from `EffectAnalyzer::checkPre` / `checkPost`; the main barrier families are clear from the pass and helper comments, but a future implementation thread may still want a closer audit of especially GC- and EH-specific flags before porting.
- I did not exhaustively catalog every function in `simplify-locals_all-features.wast`; the examples here focus on the recurring variant boundary and the most explanatory test families.
- The statement that the late equivalent-get phase is “slightly more permissive” comes from `connectAdjacentBlocks = true` in `EquivalentOptimizer`; that is a source-based inference about scope, not an explicit upstream prose summary.

## Suggested living-page breakdown

This raw note should be filed into living docs as:

- `docs/wiki/binaryen/passes/simplify-locals-nostructure/index.md`
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/variant-surface.md`
- `docs/wiki/binaryen/passes/simplify-locals-nostructure/wat-shapes.md`

## Sources

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/simplify-locals/index.md`
- `docs/wiki/binaryen/passes/simplify-locals/binaryen-strategy.md`
- `docs/wiki/raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals_all-features.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals_all-features_disable-exception-handling.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals_all-features_disable-exception-handling.txt>
