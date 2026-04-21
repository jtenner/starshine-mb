# 0114 - `rse` / `redundant-set-elimination` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented no-DWARF / `-O4z` Binaryen pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what upstream `rse` actually does, what helper analyses it depends on, which local-value and CFG shapes it rewrites, and which conservative bailouts a future Starshine port must preserve.

## Why this pass

- The updated pass tracker still listed `rse` / `redundant-set-elimination` with wiki status `none`, and it was still the first suggested next dossier target when this run started.
- No dedicated living folder existed yet under `docs/wiki/binaryen/passes/`, so this was still an eligible new dossier rather than overlap with an existing deep page.
- `rse` matters to both of the main local parity stories in this repo:
  - the canonical Binaryen no-DWARF `-O` / `-Os` path
  - the saved generated-artifact `-O4z` audit
- It sits very late in the cleanup cluster, after `coalesce-locals`, late `precompute`, late `optimize-instructions`, and late `heap-store-optimization`, which makes it especially useful for future Starshine preset honesty work.
- The user-facing name is misleading. The official README summary makes it sound like a tiny dead-store peephole, but the actual implementation is a hybrid of local value numbering, CFG merge reasoning, liveness/influence tracking, type-aware replacement, and conservative non-linear bailouts.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/RedundantSetElimination.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/local-graph.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- `src/ir/liveness.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/liveness.h>
- `src/ir/numbering.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `README.md`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
- `test/passes/rse_all-features.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- `test/passes/rse_all-features.txt`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.txt>
- `test/lit/passes/rse-gc.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>

## Fast answer

Binaryen's `rse` pass is a **late local-value cleanup pass**.

What it really does in `version_129` is:

1. track what value each local is currently known to hold
2. merge that knowledge across CFG predecessors when the merge is simple enough
3. use liveness/influence data to see whether an older `local.set` still matters
4. remove redundant `local.set` / `local.tee` operations when the stored value is unchanged or will never be needed
5. replace some `local.get`s with the current expression, another local, or a type-correct zero when the source proves that is safe
6. refinalize and vacuum the function afterward

Important durable facts:

- Despite the name, this pass is **not** generic redundant-write elimination over globals, memory stores, or GC field writes.
- In `version_129`, the pass is built around **locals**:
  - it visits `LocalSet`
  - it tracks `LocalGet`
  - it uses `LocalGraph` and `Liveness` helpers
- The official README summary is directionally right but too small. The pass is bigger than “delete one overwritten set.”
- Cross-block reasoning exists, but it is intentionally conservative:
  - exact value replacement only survives easy merges
  - non-linear control-flow barriers wipe the current-value cache
  - loop handling is deliberately disabled by source comment because the block-input model is not correct there yet
- The GC-specific part of the pass is not “eliminate `struct.set`.” It is **type-aware replacement of `local.get`** when a current local value is represented by a more refined GC expression such as `ref.cast` or `ref.as_non_null`.

## Naming and true scope

The official README one-liner for `rse` says, in essence, that the pass removes a `local.set` when a later set to the same local happens with no intervening uses, and can also remove the corresponding `local.get`.

That is a useful first approximation, but the implementation teaches several more exact rules:

- the pass is about **locals**, not all set-like instructions
- it is willing to kill a set even if there are later same-block reads, as long as those reads can themselves be rewritten
- it can track copied locals and predecessor merges instead of only looking for adjacent overwrite pairs
- it can substitute a later `local.get` with a more refined current expression
- it must respect CFG boundaries, block fallthrough values, and type assignability

So the safer short description is:

> `rse` is Binaryen's late local-set / local-get redundancy cleanup pass, powered by local liveness, local value numbering, and conservative CFG merge reasoning.

That sentence matches the implementation much better.

## Where it appears in the scheduler

## Top-level no-DWARF path

Binaryen `version_129` `pass.cpp` adds `rse` late in the default function optimization pipeline, guarded by `optimizeLevel >= 2`.

In the canonical no-DWARF path tracked in this repo, the tail neighborhood is:

- `code-folding`
- `merge-blocks`
- `remove-unused-brs`
- `remove-unused-names`
- `merge-blocks`
- `precompute`
- `optimize-instructions`
- `heap-store-optimization`
- `rse`
- `vacuum`

That ordering matters.

`rse` is deliberately placed after:

- local-shape cleanup (`simplify-locals`, `coalesce-locals`)
- structural cleanup (`code-folding`, `merge-blocks`, `remove-unused-brs`)
- late value simplification (`precompute`, `optimize-instructions`, `heap-store-optimization`)

And then a final `vacuum` runs after it to clear leftover drops, nops, and other tiny cleanup debris.

## Saved generated-artifact `-O4z` audit

The saved ordered audit in this repo records `rse` as a real missing top-level slot:

- slot `46`: `rse`

The same saved Binaryen debug log also shows nested reruns of the tail cleanup cluster later in the full optimization run, with repeated `... optimize-instructions -> heap-store-optimization -> rse -> vacuum` subsequences.

So `rse` is not just a one-off top-level detail. It also matters to the optimizing nested cleanup story.

## Nested reruns

`opt-utils.h` shows that Binaryen's `optimizeAfterInlining(...)` helper prepends `precompute-propagate` and then reruns the default function optimization pipeline on touched functions.

That means `rse` can reappear under optimizing passes like:

- `dae-optimizing`
- `inlining-optimizing`

The repo's no-DWARF page also records that `simplify-globals-optimizing` reruns the default function pipeline on changed functions, but without the prepended `precompute-propagate`.

For Starshine parity, the durable scheduler lesson is:

- the top-level `rse` slot matters
- the nested rerun sites matter too

## Actual implementation structure

## 1. The pass is organized around CFG basic blocks and locals

`RedundantSetElimination.cpp` builds a `LocalGraph` for the function and then walks the function while keeping a `LocalInfo` record for every local index.

Each `LocalInfo` tracks two things:

- `curr`
  - what the pass currently knows about the local's value
- `setses`
  - which `local.set`s (or parameter/self sentinels) still influence that value

The current-value state is not just “known” versus “unknown.” It has three states:

- `Unseen`
  - no exact current value is being tracked
- exact `Value`
  - all known paths agree on one value-numbered value
- `MergedValues`
  - several predecessor values meet here, so exact substitution is no longer possible even though influence information still matters

That is the core mental model for the whole pass.

## 2. Parameters start as live self-values

At function entry, every parameter local is seeded with:

- a unique value number
- a `Self` influence marker

This means the pass can reason about parameter-originated local values the same way it reasons about values created by explicit `local.set`s.

## 3. Value numbering is what makes “same value” bigger than textual equality

The pass does not compare expressions textually.

Instead it uses `ValueNumbering` from `src/ir/numbering.h`, together with a `FlexibleValues` callback that says:

- if an expression is a `local.get`
- and the pass currently knows the exact value of that local
- then treat the get as that current value instead

That is how Binaryen can understand cases like:

- copied locals
- repeated pure computations that hash to the same value number
- refined GC expressions that are still the same semantic value

The value numbering layer is one reason the pass is more sophisticated than a naive overwrite scan.

## 4. The pass has two main rewrite targets

### Redundant sets

When it visits a `LocalSet` / `LocalTee`, the pass asks:

- does this write store the same value the local already has?
- or is this stored value never needed by any future non-rewriteable read?

If yes, the write is redundant.

Rewrite rule:

- `local.set` -> `drop(value)`
- `local.tee` -> `value`

So the assignment disappears, but any needed value-producing side effects of the right-hand side stay intact.

### Redundant gets

When it visits other expressions, the pass also watches for `LocalGet`s that can be replaced with the current value representation.

Possible replacement shapes include:

- the current exact expression
- another `local.get` reached through copy propagation
- a zero literal of the requested type, when the source code uses the fallback zero-materialization path

This is the second half of why same-block reads do not necessarily keep a set alive.

## 5. Same-block reads can be rewritten away, so they do not always keep a set alive

The helper `isNeverRead(...)` is easy to misread.

It does **not** mean “no future `local.get` exists anywhere.”

The actual logic is closer to:

- if no future get depends on this set, it is dead
- or if all dependent gets are in the same basic block and the set does not influence the block's fallthrough value, then the set can still be removed because those same-block gets can be rewritten directly

That is a major implementation detail.

It means `rse` can remove an earlier set even when there are later reads, as long as those reads are locally replaceable and no later block still depends on the stored local state.

## 6. Cross-block reasoning exists, but only on a small lattice

At each basic-block entry, the pass merges predecessor information.

If every predecessor agrees on one exact value number for a local, the merged state stays exact.

If predecessors disagree, the state becomes `MergedValues{...}` and exact substitution stops for that local until a later write reestablishes certainty.

The pass still unions the influencing sets, which is useful for dead-set reasoning, but it no longer pretends to know one exact materializable expression.

This is the pass's mini-phi story.

It is intentionally much weaker than full SSA reasoning.

## 7. Copied locals inherit both value and influence history

If the pass sees:

```wat
(local.set $y
  (local.get $x))
```

then `$y` does not merely become “whatever expression was on the right-hand side.”

Instead `$y` inherits:

- the current value state of `$x`
- the influencing set history of `$x`

That makes later `$y` reads and later dead-set checks much more precise than a textual-copy model would be.

This copied-local inheritance is one of the most important things to preserve in a port.

## 8. Non-linear control flow is a deliberate barrier

`noteNonLinear()` wipes the tracked current-value state for all locals.

The pass triggers that barrier after encountering things like:

- branch instructions recognized by `BranchUtils::is(...)`
- control-flow structures recognized by `Properties::isControlFlowStructure(...)`

The point is simple:

- once control no longer flows linearly through the current block segment,
- exact current-value reasoning becomes much less reliable,
- so Binaryen drops it instead of being clever.

This is one of the main reasons the pass stays sound.

## 9. Loops are deliberately not optimized

One source comment is unusually blunt:

- there is currently no point optimizing loops here because `LocalGraph` block inputs are wrong in loops

That means the upstream implementation knowingly leaves loop precision on the table.

This is not an accident.

A future Starshine port should treat that as a real upstream conservatism boundary:

- either preserve the same loop bailout first,
- or replace it with a genuinely better loop-aware lattice
- but do not silently “optimize loops too” without proving the merge logic is sound.

## 10. The pass also does type-aware refinement for GC locals

The `rse-gc.wast` tests reveal an easy misconception.

The GC aspect of `rse` is **not** that it deletes GC field writes.

Instead, the pass can replace a `local.get` with a more refined current expression when that expression's type is a subtype of the `local.get`'s type.

Examples in the shipped GC lit tests cover:

- choosing a current `ref.cast` expression instead of a later nullable local get
- preserving a nullable refined expression rather than substituting a more refined but non-assignable non-null one
- declining substitution when different predecessor choices disagree
- preserving loop-target behavior instead of over-refining across a loop shape

So the GC contract is really:

- better typed local-value substitution
- plus conservative refusal when the type or merge story is not single-valued enough

## 11. The pass mutates liveness/influence data as it learns more

Several helper routines in the source are there to keep the local liveness graph honest after rewrites:

- `invalidateSetGetPairs(...)`
- `unneededLoad(...)`
- `fixPredecessorValues(...)`

The important practical meaning is:

- when the pass proves some old set no longer matters,
- it removes stale set->get influence edges,
- which can expose more dead sets later in the same walk

This is why a future port should not treat liveness as read-only input.

The pass updates its own bookkeeping while it optimizes.

## 12. Binaryen cleans up after the rewrite immediately

After a changed function walk, `visitFunction(...)` does two more things:

- `ReFinalize().walkFunctionInModule(...)`
- `vacuum.runOnFunction(...)`

That is important for two reasons:

- replacing `local.set` / `local.tee` with value or `drop` shapes changes local expression typing and nesting
- the pass intentionally creates tiny cleanup debris that it expects `vacuum` to simplify

So `rse` is not a pure one-shot peephole. It is a rewrite plus immediate local cleanup.

## Key helper dependencies

## `LocalGraph`

Main role:

- map `local.get` <-> `local.set` influences
- know which basic block each local op belongs to
- expose predecessor sets and fallthrough information

Durable takeaway:

- `LocalGraph` is the pass's control-flow and local-use backbone

## `Liveness`

Main role:

- support the `getGetSetses()` and `getSetInfluences()` relations consumed by `isNeverRead(...)` and the invalidation helpers

Durable takeaway:

- the pass's dead-set decisions are liveness-backed, not guessed from local AST proximity

## `ValueNumbering` / `FlexibleValues`

Main role:

- identify semantically identical current values, not just textually identical ones
- let exact local values substitute for `local.get` during numbering

Durable takeaway:

- this is why copied locals and refined expressions can still count as “the same value”

## `Properties`

Main role:

- expose block fallthrough values
- identify control-flow structures
- answer whether typed zero materialization is available through `LiteralUtils`

Durable takeaway:

- fallthrough and type repair are part of the contract, not afterthoughts

## `BranchUtils`

Main role:

- identify branch instructions for non-linear barriers

Durable takeaway:

- a branch is enough to make the pass drop its current exact-value cache

## `ReFinalize` and `Vacuum`

Main role:

- repair types after local expression replacement
- clean up rewrite leftovers

Durable takeaway:

- post-rewrite repair is built into the pass's normal behavior

## Important positive shapes from shipped tests

## Plain overwrite elimination

Input idea:

```wat
(local.set $x (i32.const 1))
(local.set $x (i32.const 2))
```

Binaryen removes the earlier set because the second write overwrites it before any needed read.

## Same-value set elimination

Input idea:

```wat
(local.set $x (i32.const 1))
(local.set $x (i32.const 1))
```

If value numbering proves the second store writes the value `$x` already holds, the store is redundant.

## Copy-chain cleanup

Input idea:

```wat
(local.set $y (i32.const 42))
(local.set $x (local.get $y))
(local.get $y)
```

The pass can conclude `$x` never needed a separate stored copy, because later reads can use the already-current `$y` value.

## Merge-with-agreement cleanup

If two predecessor blocks both establish the same value for a local, a later read after the merge can still be replaced.

This is visible in the `if2` / `many-merges` style regression tests.

## GC refined local replacement

The `pick-refined` GC test demonstrates that a current `ref.cast` / refined local value may replace a later plain `local.get` when the refined expression is type-assignable to the use site.

## Important negative and bailout shapes

## Different predecessor values

If predecessor blocks establish different current values, Binaryen records `MergedValues` and stops exact substitution for that local.

The `different-choices` GC test is the cleanest shipped example.

## Loop precision bailout

Loop inputs are intentionally not optimized with the current implementation.

The `loop-target-preserved` test protects this conservative boundary.

## Non-linear barrier after branches / structures

Once the pass sees non-linear control flow, it clears exact current-value tracking.

So a would-be same-value read after a branch or nested structure often stays as a real `local.get`.

## Non-assignable refined expression

Even if a more refined current expression represents the same semantic value, the pass only substitutes it when its static type fits the `local.get`'s type.

The nullable-vs-non-null GC test cases exist to protect this detail.

## Not global / memory / field-store elimination

There is no `visitGlobalSet`, `visitStore`, `visitStructSet`, or `visitArraySet` logic in `RedundantSetElimination.cpp`.

That absence is not a documentation omission. It is the actual current scope.

## What is easy to misunderstand

## Misunderstanding 1: “RSE removes all redundant sets”

Too broad.

The implementation is local-only in `version_129`.

## Misunderstanding 2: “It just checks adjacent overwrites”

Too small.

The pass uses:

- value numbering
- predecessor merges
- set/get influence tracking
- type-aware local-get replacement

## Misunderstanding 3: “A later get means the earlier set must stay”

Not necessarily.

If the later get is in the same basic block and can be rewritten directly, the set may still be removable.

## Misunderstanding 4: “GC support means field-write elimination”

False.

The shipped GC tests are about refined local substitution.

## Misunderstanding 5: “Later vacuum is optional”

Misleading.

The pass itself already runs local refinalization and vacuum cleanup after changes, and the global pipeline still keeps a final `vacuum` slot after `rse`.

## Porting consequences for Starshine

A future Starshine `rse` port should preserve these upstream facts first:

1. treat the pass as **local-only** unless there is an explicit design choice to extend beyond Binaryen
2. preserve the exact scheduler meaning:
   - late top-level slot after late value cleanup
   - nested reruns under optimizing passes
3. keep copied-local inheritance of both value and influence history
4. keep same-block read rewriting as part of dead-set removal
5. preserve the conservative block-merge lattice:
   - exact value
   - merged-values set
   - unseen
6. preserve the non-linear barrier behavior
7. preserve the current loop conservatism unless a better proof-backed loop model is built
8. preserve type-aware refined-expression substitution for GC locals
9. refinalize and cleanup after rewrites
10. do not silently advertise the pass as global-store or GC-field-write elimination, because upstream `version_129` is not that pass

## Suggested initial Starshine implementation plan

A realistic first port should probably land in this order:

1. locals-only core
   - `local.set` / `local.tee` redundancy
   - exact current-value tracking in straight-line code
2. liveness-backed same-block dead-set removal
3. copied-local inheritance
4. easy predecessor merge agreement
5. conservative GC refined local-get replacement
6. explicit loop bailout
7. exact scheduler wiring and nested rerun coverage

That would match the shape of the upstream implementation much more honestly than a broad “redundant writes” pass claim.

## Uncertainty and inference notes

- I am confident about the pass's local-only scope because the actual visitor and helper surface in `RedundantSetElimination.cpp` only handles locals and local graph/liveness helpers.
- I am confident about the late scheduler placement and slot `46` because both the local saved audit artifacts and upstream `pass.cpp` agree.
- I am confident that GC relevance here is about refined local values, not field writes, because the shipped `rse-gc.wast` tests are exactly about refined local replacement.
- I am somewhat less confident about the deeper intention behind the zero-literal fallback in `replaceLoadCurr(...)`; the source makes the behavior clear, but the motivating family is less directly documented than the cast/refinement tests. In the living wiki I treat that as a real implementation fact but not the main conceptual story of the pass.
- I did not find evidence in the current official sources that `version_129` `rse` rewrites globals, memory stores, or GC field stores. If later upstream commits broaden the pass, the wiki should record that as drift instead of back-projecting it onto this `version_129` dossier.

## Sources

### Local repo sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `.artifacts/o4z-wasm-opt-debug.log`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `agent-todo.md`

### Official Binaryen `version_129`

- Pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- Scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Nested cleanup helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Local graph helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- Liveness helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/liveness.h>
- Value numbering helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- Properties helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- README pass summary: <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
- Shipped pass tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- Shipped pass output: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.txt>
- Shipped GC lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>
