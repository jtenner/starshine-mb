# 0142 - `reorder-locals` Binaryen research

## Scope

- Deepen the existing `reorder-locals` landing page into a real Binaryen dossier.
- Re-check the upstream implementation against Binaryen `version_129`, not the older `version_125` research baseline.
- Separate the actual pass algorithm from the already-known Binaryen multivalue writeback instability that can make raw emitted wasm diverge even when the sorter itself matches.
- File the durable conclusions back into `docs/wiki/binaryen/passes/reorder-locals/`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/index.md`, and `docs/wiki/log.md`.

## Candidate choice

I followed the campaign instructions in order:

1. read `docs/README.md`
2. read `docs/wiki/binaryen/passes/tracker.md`
3. read `docs/wiki/binaryen/passes/index.md`
4. read `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
5. read the `RL` slice in `agent-todo.md`

The updated tracker already showed `ssa-nomerge` as deepened and named `reorder-locals` as the strongest remaining implemented landing-page target. The folder still only had:

- `index.md`
- `parity.md`
- `multivalue-call-scope.md`

So `reorder-locals` was still eligible and was the correct pick for this run.

## Oracle version and freshness check

Primary upstream oracle:

- Binaryen `version_129`

Official source surfaces checked:

- pass implementation:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderLocals.cpp>
- scheduler / registration:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- dedicated pass tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/reorder-locals_print_roundtrip.txt>
- multivalue / writeback boundary sources relevant to the known parity caveat:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-ir-builder.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-stack.cpp>

I also did a narrow direct source diff against current GitHub `main` for:

- `src/passes/ReorderLocals.cpp`
- `test/passes/reorder-locals.wast`
- `test/passes/reorder-locals.txt`
- `test/passes/reorder-locals_print_roundtrip.wast`
- `test/passes/reorder-locals_print_roundtrip.txt`

Result:

- no diff in any of those files

So the durable freshness conclusion for this dossier is:

- treat Binaryen `version_129` as the released oracle
- current `main` does not currently show semantic or dedicated-test drift for this pass

## Repo sources relevant to the Starshine side

- implementation:
  - `src/passes/reorder_locals.mbt`
- focused tests:
  - `src/passes/reorder_locals_test.mbt`
- module-pass dispatcher:
  - `src/passes/pass_manager.mbt`
- registry / preset policy:
  - `src/passes/optimize.mbt`
  - `src/passes/optimize_test.mbt`
  - `src/passes/registry_test.mbt`
- CLI coverage:
  - `src/cmd/cmd_wbtest.mbt`
- earlier historical notes:
  - `docs/wiki/raw/research/0073-2026-04-02-reorder-locals-binaryen-comparison.md`
  - `docs/wiki/raw/research/0074-2026-04-02-binaryen-multivalue-call-local-disparity.md`
  - `docs/wiki/binaryen/passes/reorder-locals/parity.md`
  - `docs/wiki/binaryen/passes/reorder-locals/multivalue-call-scope.md`

## High-level conclusion

`reorder-locals` is a much smaller and more literal pass than its name suggests.

It is **not**:

- liveness-based local minimization
- dead-store elimination
- local coalescing
- type-aware local packing
- a CFG or dominance analysis pass
- a writeback-layer multivalue repair pass

It **is**:

- a function-parallel local-usage counter
- over all locals, including params
- that keeps params fixed at the front
- sorts body locals by descending access count
- breaks nonzero ties by first observed access
- breaks zero-count ties by original index
- drops the final zero-count body-local suffix after sorting
- rewrites local uses to the new indices
- and rewrites Binaryen's function-local name maps to match

That sounds tiny because it is tiny.

But the practical contract is still important:

- it runs three times in the canonical no-DWARF function pipeline
- it helps later local-cleanup passes by compacting the live body-local set
- and the dedicated print-roundtrip tests show that a correct implementation must preserve the reordered declaration order through Binaryen's binary writer, not just in-memory AST state

## Exact Binaryen implementation structure

`src/passes/ReorderLocals.cpp` contains a single pass struct:

- `struct ReorderLocals : public WalkerPass<PostWalker<ReorderLocals>>`

Two small pass-level facts matter immediately:

- `isFunctionParallel() override { return true; }`
- `requiresNonNullableLocalFixups() override { return false; }`

That already tells us a lot about the intended scope:

- the pass works one function at a time
- it does not need module-wide graph analyses
- it does not change local types
- it does not need the generic nondefaultable-local repair path that some GC-local rewrites need

### Core state

Binaryen stores three pieces of pass state:

- `counts[local]` = number of local accesses seen
- `firstUses[local]` = first-seen rank for that local
- `firstUseIndex` = next rank value, starting at `1`

One subtle detail worth recording:

- `firstUseIndex` is a pass field and is **not reset** inside `doWalkFunction(...)`

That looks suspicious at first glance, but it is harmless for the actual algorithm because:

- `firstUses` is reset per function
- only relative order within the current function is compared
- the absolute starting number does not matter as long as it increases monotonically during one function's walk

So this is not a hidden cross-function dependency; it is just a slightly non-obvious implementation detail.

### Phase 1: trivial early return

If `curr->getNumVars() == 0`:

- return immediately

That means:

- params-only functions are true no-ops
- the pass never invents work for functions that already have no body locals

### Phase 2: count local accesses

Binaryen sizes `counts` and `firstUses` to the total local count, which includes parameters.

Then it walks the function body and records accesses in exactly two visitors:

- `visitLocalGet(LocalGet*)`
- `visitLocalSet(LocalSet*)`

Every visit does:

- `counts[index]++`
- assign `firstUses[index] = firstUseIndex++` on the first sighting

Important nuance:

- Binaryen AST models `local.tee` as `LocalSet` with tee state
- so tees count here even though there is no separate `visitLocalTee(...)`

That is why a faithful Starshine raw-wasm port must count:

- `local.get`
- `local.set`
- `local.tee`

Even though upstream C++ only visits `LocalGet` and `LocalSet`.

### Phase 3: sort the old local indices into new order

Binaryen builds `newToOld = [0, 1, 2, ...]` over the full local range, then sorts it with one comparator.

The comparator rules are the real contract:

1. params always sort before non-params
2. params keep original order among themselves
3. among body locals:
   - higher `counts` sorts first
4. if counts tie:
   - if the count is zero, keep original order
   - otherwise, earlier `firstUses` rank sorts first

That yields the precise human rule:

- parameters stay fixed in front
- accessed body locals sort by descending access frequency
- ties among accessed body locals sort by first observed access
- unused body locals preserve original order until they are dropped

### Phase 4: restore parameter identity explicitly

After sorting, Binaryen still runs an explicit param-prefix repair loop:

- assert that the prefix still contains only params
- rewrite `newToOld[i] = i` for each parameter slot

This matters because the pass wants the final guarantee to be stronger than "the comparator should keep params first":

- params are not merely likely to stay fixed
- params are forcibly restored to exact identity order

### Phase 5: rebuild only the live body-local suffix

Binaryen swaps `curr->vars` out into `oldVars`, then walks the sorted body-local portion of `newToOld`.

For each body-local candidate:

- if `counts[index] > 0`, push its old type into `curr->vars`
- otherwise:
  - truncate `newToOld` at that position
  - stop immediately

This is why the pass drops all zero-count body locals even though it only checks for the **first** zero-count body local after sorting:

- the sort guarantees every later body local also has count `0`

Two practical consequences:

- write-only locals survive, because writes count
- a function can legitimately lose every body local declaration and become params-only or declaration-free after the pass

### Phase 6: compute the inverse map

Binaryen next builds `oldToNew`.

- params map to themselves
- live body locals map through the truncated `newToOld` list

Dropped body locals never need a valid inverse mapping because there must be no remaining uses of them.

### Phase 7: rewrite the AST local indices

A nested `ReIndexer` post-walker rewrites only:

- `LocalGet.index`
- `LocalSet.index`

Again, there is no separate tee visitor because `LocalSet` already covers tee form.

This is another important beginner correction:

- the pass does **not** inspect control-flow semantics or expression kinds specially
- it simply rewrites every local user node after the declaration order changes

So nested `block`, `loop`, `if`, `try`, and similar structure matter only because local users can appear inside them, not because the pass has special control-flow logic.

### Phase 8: rewrite function-local name metadata

Binaryen also rewrites:

- `curr->localNames`
- `curr->localIndices`

It iterates the final kept `newToOld` list and, for every surviving original index that had a name:

- inserts the name at the new local index
- records the reverse lookup in `localIndices`

Names for dropped locals disappear naturally because those original indices never reappear in the truncated list.

This metadata rewrite is a real part of the upstream pass contract, not optional polish.

## Analysis and helper dependencies

The notable thing about `reorder-locals` is how few heavyweight helpers it uses.

### What it depends on

- the generic `Pass` / `WalkerPass` surface
- `Function` helpers such as:
  - `getNumVars()`
  - `getNumLocals()`
  - `isParam(...)`
  - `getParams()`
  - `getVarIndexBase()`
- function-local name maps:
  - `localNames`
  - `localIndices`

### What it does **not** depend on

- `LocalGraph`
- CFG reasoning
- dominance
- liveness
- `Effects`
- branch utilities
- `ReFinalize`
- type-updating helpers
- non-nullable-local fixups
- EH repair
- flattening helpers

That absence matters because it separates the pass from several similarly named local passes that really do depend on those analyses:

- `coalesce-locals`
- `local-cse`
- `rse`
- `ssa-nomerge`

`reorder-locals` is much more mechanical.

## Scheduler placement and why it matters

`src/passes/pass.cpp` registers the pass as:

- `reorder-locals` = sorts locals by access frequency

In the canonical no-DWARF function pipeline for `version_129`, it appears three times:

1. after `simplify-locals-nostructure` and `vacuum`
2. after `simplify-locals` and `vacuum`
3. after the second `coalesce-locals`, followed by a final `vacuum`

The surrounding comments in `pass.cpp` are the best clue to intended meaning:

- `simplify-locals-nostructure` avoids creating if/block return values too early because coalescing may remove copies that would otherwise inhibit
- `vacuum` immediately follows because the previous pass creates garbage
- `reorder-locals` then compacts the remaining local traffic
- `coalesce-locals` runs later after even more local cleanup, then `reorder-locals` compacts again

So the pass is not just a one-off code-size trick. In the scheduler it acts as:

- a canonicalizer after cleanup churn
- a declaration trimmer before heavier or later local passes
- a repeated compactor after local topology has changed again

That is the main reason the pass matters more than its tiny source file suggests.

## Official test surfaces and what they prove

### `test/passes/reorder-locals.wast` / `.txt`

The dedicated golden pair covers the main algorithmic contract:

- a function where body locals with counts `1`, `2`, `3` reorder into descending count order
- a function where only one local is accessed and the zero-count suffix disappears
- a function where all body locals are unused and the final output contains no local declarations at all

The golden output also shows a useful beginner-facing fact:

- parameter-heavy traffic does not let body locals move across the parameter boundary

### `test/passes/reorder-locals_print_roundtrip.wast` / `.txt`

This pair is easy to underrate, but it matters a lot.

It verifies that once Binaryen has reordered locals in memory:

- the binary/text roundtrip preserves that new declaration order
- the writer does not silently re-normalize declarations back into old order

So a correct parity story for this pass includes both:

- the in-memory sorter
- the emitted declaration order after writing and reading modules again

That detail becomes important when comparing against Starshine because some apparent "reorder-locals mismatches" can actually come from surrounding writeback policy instead.

## Important shape families

### Positive shapes

- body local used more often than its peers -> moves earlier in the declaration list
- equal nonzero count but earlier first use -> wins the tie
- write-only local -> survives, because writes count
- tee-only local -> survives upstream because tee is a `LocalSet`
- stable accessed prefix plus unused tail -> only the unused tail disappears
- nested control-flow users -> all local indices are rewritten uniformly after the declaration reorder

### Negative or non-goal shapes

- params do not move, even if they are much hotter than body locals
- zero-count locals do not get stable new low indices; they are dropped instead
- the pass does not prove whether a write is semantically dead
- the pass does not merge compatible locals or reduce live overlap
- the pass does not change types, only order and liveness-at-zero-access
- the pass does not explain multivalue call local growth; that happens outside `ReorderLocals.cpp`

## Multivalue call growth is a boundary problem, not a pass problem

The earlier repo research in `0074` already identified the big parity caveat:

- Binaryen can keep growing locals on repeated no-pass or `reorder-locals` roundtrips for multivalue call fixtures

Re-checking the upstream source confirms that this growth does **not** come from `ReorderLocals.cpp`.

Instead, it comes from surrounding Binaryen IR-builder and writer machinery:

- `wasm-ir-builder.cpp` hoists tuple values into scratch locals, packages them with `tuple.extract`, and materializes multivalue block / branch / call shapes through synthetic locals
- `wasm-stack.cpp` lowers tuple locals and scratch locals back into scalar wasm locals, groups locals by type in the binary writer, and allocates scratch locals for tuple extraction and other writeback duties

So the clean conclusion is still:

- `reorder-locals` itself is a tiny frequency sorter
- the persistent multivalue call instability belongs to the Binaryen representation boundary around tuple packaging and stacky writeback

That is why the existing `multivalue-call-scope.md` decision remains honest.

## Implications for Starshine

The Starshine implementation is deliberately a **module pass**, even though upstream Binaryen's algorithm is per function.

That is the right local design because Starshine's boundary-owned metadata lives at module scope:

- `NameSec.local_names`
- imported vs defined function numbering
- `raw_name_sec_payload`

A correct port therefore had to do more repo-local bookkeeping than Binaryen's AST pass file shows directly:

- compute parameter counts from module type info
- rewrite nested local indices in boundary `Expr`
- rebuild grouped body-local runs
- rewrite structured local-name metadata only for changed defined functions
- preserve imported-function local-name entries
- clear stale raw name payloads when layout changes

Those are Starshine porting consequences, not evidence that upstream `reorder-locals` is secretly more complicated.

## Current Starshine parity state

The current living parity page remains the right summary surface, but the important durable conclusion after this re-check is:

- the remaining pass-level red compare is **not** evidence that the raw sorting rule is still misunderstood

What is already solid:

- explicit module-pass implementation exists in-tree
- focused tests cover access counting, write-only locals, tee counting, nested rewrites, multiple defined functions, name rewrites, and the Binaryen-materialized carrier fixture
- explicit CLI/module-pass wiring exists
- the large `gen-valid` lane has strong green evidence

What remains open:

- one comparator-classified mismatch lane in the smaller smoke rerun
- non-converging Binaryen multivalue call writeback, which the current project already treats as out of scope for `reorder-locals` itself

## Biggest beginner-facing corrections

1. `reorder-locals` is **not** `coalesce-locals`.
   - It reorders and drops zero-access locals.
   - It does not reason about overlapping lifetimes.

2. The pass does **not** ignore writes.
   - `local.set` counts.
   - So write-only locals survive.

3. The pass is not just about AST order.
   - The official print-roundtrip tests show writer behavior matters too.

4. Non-converging multivalue call local growth is not proof the sort rule is wrong.
   - That growth comes from Binaryen's tuple packaging and binary writeback layers.

## Future port / maintenance rules

A future Starshine port or refactor must preserve these properties explicitly:

- parameters stay fixed in exact original order
- body locals reorder only by count, then first use, then original order for zeros
- write-only locals remain live for this pass
- zero-count body locals are dropped only after sorting, by truncating the zero-count suffix
- local-user indices are rewritten everywhere they appear
- local-name metadata is updated consistently with the new numbering
- writer / roundtrip parity must not silently re-normalize the declaration order
- multivalue call writeback non-convergence should stay documented as a boundary issue, not silently folded into the pass algorithm description

## Bottom line

`reorder-locals` is one of the smallest Binaryen optimization passes in this campaign, but it still teaches an important lesson:

- a tiny source file can have a larger practical contract because scheduler placement, local-name metadata, and binary roundtrips are part of what "correct" means.

The most accurate beginner summary is:

- Binaryen counts local traffic, keeps params fixed, sorts accessed body locals by heat and first sighting, drops never-touched body locals, and keeps names and printed local order in sync.

That is the contract the living wiki should preserve.