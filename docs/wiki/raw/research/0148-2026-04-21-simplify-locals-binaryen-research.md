# 0148 - Binaryen `simplify-locals` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the refreshed `duplicate-function-elimination` dossier.
- Follow the repo wiki process in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the tracker now has no `none` queue and no implemented-landing queue, justify any already-`deep` fallback explicitly.
- Refresh the `simplify-locals` folder with direct `version_129` source-backed teaching material.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/simplify-locals/`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`

## Candidate selection

I followed the campaign instructions in order:

1. read `docs/README.md`
2. read `docs/wiki/binaryen/passes/tracker.md`
3. read `docs/wiki/binaryen/passes/index.md`
4. read `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
5. re-checked the relevant `SL` backlog slice in `agent-todo.md`

At that point:

- the saved-audit `none` queue was already empty
- the implemented-landing queue was already closed
- the older tuple-opt, RUME, RUB, and DFE major-gap fallbacks were already closed
- many other candidate passes were either explicitly excluded by the campaign prompt or already had fresher `version_129` implementation/test-map teaching material than `simplify-locals`

So this run needed a justified major-gap fallback.

I picked `simplify-locals` for four source-backed reasons:

- It is still one of the most scheduler-relevant implemented hot passes in the repo:
  - an early no-structure variant runs on the canonical no-DWARF path
  - the full structured pass runs later on that same path
  - aggressive settings also add the `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude
- The active `SL` backlog slice in `agent-todo.md` still depends on understanding the late full-pass slot and its surrounding cleanup neighborhood correctly.
- The existing folder was broad, but it was still mostly a Starshine-port dossier descended from the older `0076` note:
  - it did not yet have a dedicated living page focused on the exact upstream file map, helper dependencies, and official lit surface
  - the landing page and strategy page were still anchored more to the older plan than to a direct `version_129` implementation walk
  - the folder did not yet make the exact public variant matrix explicit in the same way newer dossiers do
- Direct `version_129` source review shows a more specific and teachable official contract than the older folder presentation made obvious:
  - one templated pass family with three semantic axes
  - a first-cycle single-use sink phase
  - later general tee-aware sinking
  - optional structure synthesis for blocks / ifs / loops
  - a separate equivalent-copy late phase
  - a final dead-set cleanup via `UnneededSetRemover`

So this thread is not about changing tracker status.
It is about closing a real official-source teaching gap in an already-deep folder: the older `simplify-locals` docs needed a fresher `version_129` implementation map, variant/scheduler explanation, and upstream-facing WAT-shape catalog.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- pass registration and scheduler placement:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- nested rerun helper:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- generic pass-runner local-fixup contract:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- helper surfaces the pass actually depends on:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- representative official test families:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-global.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-effects_simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-atomic-effects.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-eh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-eh-legacy.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-gc-nn.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-gc-validation.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-strings.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-table_copy.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals-tnh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-locals_rse_fallthrough.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-main check on the core file and major dedicated lit surfaces.

Durable result:

- `SimplifyLocals.cpp` on current `main` differs from `version_129` only in a tiny non-semantic container change:
  - `std::map<Name, std::vector<BlockBreak>> blockBreaks` -> `std::unordered_map<Name, std::vector<BlockBreak>>`
  - `std::set<Name> unoptimizableBlocks` -> `std::unordered_set<Name>`
- the checked dedicated lit files are unchanged between `version_129` and current `main`:
  - `simplify-locals-gc.wast`
  - `simplify-locals-gc-nn.wast`
  - `simplify-locals-gc-validation.wast`
  - `simplify-locals-eh.wast`
  - `simplify-locals-tnh.wast`
  - `global-effects_simplify-locals.wast`

That is intentionally a narrow freshness statement, not a whole-repo equivalence proof.
The durable rule for the living pages should be:

- use `version_129` as the normative algorithm oracle
- record trunk drift explicitly when it matters
- do not invent a semantic-drift story when the current checked surfaces only show container-choice cleanup

## Repo-local sources used for context

- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `agent-todo.md`
- the older simplify-locals note:
  - `docs/wiki/raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md`
- in-tree implementation/tests/docs:
  - `src/passes/simplify_locals.mbt`
  - `src/passes/simplify_locals_test.mbt`
  - `src/passes/pass_manager.mbt`
  - `src/passes/pass_manager_wbtest.mbt`
  - `src/passes/perf_test.mbt`
  - `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt`
  - `docs/wiki/binaryen/passes/simplify-locals/`

## High-level conclusion

Binaryen `simplify-locals` is broader than "remove dead locals" and narrower than "generic local dataflow optimizer."

The upstream `version_129` pass family is basically:

1. count `local.get` uses
2. run a first cycle that prefers single-use sinks and forbids tee creation
3. rerun more general linear-trace sinking cycles that may create tees when the variant allows it
4. optionally synthesize block / `if` / loop result structure when the variant allows it
5. run a separate late equivalent-copy pass that canonicalizes among known-equal locals
6. run `UnneededSetRemover` to erase or drop now-dead writes
7. refinalize when the rewrite sharpened types
8. rely on the pass runner to perform nondefaultable-local fixups afterwards

That is the real official contract.

It is **not** a CFG liveness pass.
It is **not** a full SSA construction pass.
It is **not** just one peephole.
It is **not** one public mode: the five public pass names really matter.

## Biggest beginner correction

The easy wrong mental model is:

- `simplify-locals` just erases `local.set` / `local.get` pairs that are adjacent or obviously dead

The safer source-backed mental model is:

- Binaryen uses a cheap linear-execution model to push sinkable writes toward their next reads
- it tracks effect ordering to decide when the move is still legal
- it treats block / `if` / loop result synthesis as a separate optional layer
- it then runs a later equal-local canonicalization pass and a final dead-set cleanup pass

That difference matters because it explains all of these otherwise surprising facts:

- first-cycle behavior is intentionally different from later cycles
- `simplify-locals-nostructure` and `simplify-locals` are not interchangeable
- some one-armed `if` rewrites are deliberately speculative and guarded hard
- Binaryen may change a `local.get` to a more refined equivalent local late in the pass
- nondefaultable-local validity is partly handled outside `SimplifyLocals.cpp` itself

## Exact implementation structure

## Phase 0: one templated pass family, not five independent implementations

`SimplifyLocals.cpp` defines one template:

- `template<bool allowTee = true, bool allowStructure = true, bool allowNesting = true> struct SimplifyLocals`

The five public pass names from `pass.cpp` are just instantiations of those three axes:

- `simplify-locals` -> `<true, true, true>`
- `simplify-locals-notee` -> `<false, true, true>`
- `simplify-locals-nostructure` -> `<true, false, true>`
- `simplify-locals-notee-nostructure` -> `<false, false, true>`
- `simplify-locals-nonesting` -> `<false, false, false>`

That is already one of the most important teaching facts.
The family is structured around three semantic switches:

- whether the pass may create `local.tee`
- whether the pass may synthesize control-result structure
- whether the pass may create new nesting at all

## Phase 1: count gets and run a deliberately asymmetric cycle structure

`doWalkFunction(Function* func)` begins by bailing out if the function has no locals at all.
Then it runs `LocalGetCounter::analyze(func)`.

The cycle logic is also explicit and important:

- `firstCycle = true`
- first run focuses on single-use locals only
- later runs allow the more general tee-aware sinking surface
- late optimizations only run when the main sinking work appears stable
- late optimizations are deliberately not allowed to loop forever by themselves because get canonicalization is not guaranteed to converge

This is a big beginner correction:

- Binaryen is not doing one monotonic local rewrite sweep
- it is doing a staged fixpoint with a special first cycle and a separate late pass

## Phase 2: linear-trace sinking state is cheap and deliberately local

The main pass inherits from `LinearExecutionWalker`.
Its core state is small and very local:

- `sinkables` for the current linear trace
- `blockBreaks` to remember sinkables at each branch exit of a named block
- `unoptimizableBlocks` when a block has unsupported control users
- `ifStack` to hold sinkables from the true arm while processing an if/else

This is not a CFG or SSA graph.
It is a linear-trace approximation that gets most of the practical wins without paying for a bigger analysis.

Two comments near the top of the file summarize the intended scope well:

- when control flow splits, the pass often invalidates everything rather than reasoning across arbitrary merges
- block returns are recognized only in a constrained "all exits set the same local" form

The source even leaves explicit TODOs for the broader future surface:

- partial traces
- `BrOn`
- `Switch`
- other unsupported target families

## Phase 3: pre/post invalidation is effect-ordering driven

The most important safety rule is not syntactic adjacency.
It is effect ordering.

During `visitPre`:

- entering `try` / `try_table` invalidates sinkables whose values may throw, because moving them inside could change whether they are caught
- `EffectAnalyzer::checkPre(curr)` can invalidate earlier sinkables whose effects cannot legally move across the current node

During `visitPost`:

- `EffectAnalyzer::checkPost(original)` performs the symmetric post-order invalidation logic
- if the current node is a `local.set` that overwrites an already-sinkable write to the same local, the old write is rewritten immediately to `drop(oldValue)`

The direct API call that matters is:

- `effects.orderedAfter(info.effects)`

That is the core "can this earlier set still move past the current expression?" question.

This is why the official tests care about:

- mutable vs immutable globals
- heap reads vs heap writes
- table reads vs `table.init`
- string construction vs array stores
- atomic acquire/release ordering
- `trapsNeverHappen`
- generated global-effects summaries across calls

## Phase 4: `optimizeLocalGet` is the center of the pass

When the current node is a `local.get`, the pass looks up whether the matching local currently has a pending sinkable set.
If so, there are several cases.

### Case A: single-use or forced-single-use cycle

If this is the first cycle, or if the get count says the local has only one use left, Binaryen replaces the `local.get` with the set value directly.

That can sharpen types.
The source calls this out explicitly with a GC example:

- if the replacement value is more refined than the local type, users like `struct.get` may now see a more refined heap type
- in that case the pass marks `refinalize = true`

### Case B: multi-use and tee allowed

If this is not the first cycle and the variant allows tees, Binaryen replaces the `local.get` with the original `local.set`, then turns that set into a tee.

This is the main "consume now, keep later" rewrite.

### Case C: nonesting variant special case

If `allowNesting == false`, the pass refuses a sink that would create new nesting unless the parent is a `local.set` value position or the value is already just a `local.get` copy.

That is the upstream reason `simplify-locals-nonesting` is not merely "no tee and no structure." It has its own stronger flatness promise.

## Phase 5: structure rewrites are a distinct optional layer

If `allowStructure` is true, the pass can do four source-backed structure rewrites.

### Block return rewrite

`optimizeBlockReturn(Block* block)` looks for a local index that is sinkable:

- in the current fallthrough trace
- and in every remembered branch exit for that named block

Then it moves the relevant `local.set` values into:

- the block's final value position
- each branch's payload position
- and wraps the block itself in a new outer `local.set`

Important guards:

- named block only
- no existing branch payloads
- unsupported target users mark the block unoptimizable
- `br_if` needs an extra hazard check if the moved set is inside the branch condition, because the new payload evaluates before the condition
- if the block lacks a trailing `nop` slot, the pass queues it for enlargement and retries next cycle

### If/else return rewrite

`optimizeIfElseReturn` looks for:

- one shared local index set in both arms
- or a set in the reachable arm when the opposite arm is unreachable

Again, Binaryen may need to enlarge the arm blocks with trailing `nop`s first and retry on the next cycle.

### One-armed `if` speculative rewrite

`optimizeIfReturn` is the source's most openly speculative rewrite.
It turns

- `if (then (local.set $x value))`

into a value-`if` with:

- the then arm returning `value`
- an injected else arm reading `local.get $x`
- and an outer `local.set $x (...)`

The file comment is explicit that this can hurt size or speed if later passes do not capitalize on it.
So the pass guards it carefully.

Most important guard:

- the local type must be defaultable

The source explains why nondefaultable locals are dangerous here:

- the new else-arm `local.get` may not be structurally dominated by a set
- later local-fixup machinery would repair validation by inserting `ref.as_non_null`
- that repair can create a real runtime trap if the get was not actually safe

So the pass simply skips nondefaultable locals here.

### Loop return rewrite

`optimizeLoopReturn` handles a narrow case:

- void loop
- at least one sinkable local available
- loop body can be blockified with a trailing `nop`

Then it moves the sinkable set's value into the loop body's final position, turns the loop into a value-producing loop, and wraps the loop in the original `local.set`.

## Phase 6: rewrites may require explicit enlargement and another cycle

The pass often cannot splice a new result value into a block / if / loop immediately because that would invalidate pointers to stored sinkable sites.

So it queues:

- `blocksToEnlarge`
- `ifsToEnlarge`
- `loopsToEnlarge`

and, after the main walk finishes, `runMainOptimizations` blockifies or appends trailing `nop`s and marks `anotherCycle = true`.

This is a very practical implementation detail, but it is also part of the visible contract:

- some structure rewrites only happen after the pass makes room for them on a prior cycle

## Phase 7: late equivalent-copy cleanup is separate from main sinking

`runLateOptimizations` does not extend the same sinkable-state engine.
It creates a nested `EquivalentOptimizer` walker.

The important design choices are:

- `connectAdjacentBlocks = true`
  - the late copy canonicalization may look into immediately dominated adjacent blocks without building a full CFG
- `EquivalentSets` tracks which locals are known to carry the same value
- `removeEquivalentSets = allowStructure`
  - the structured variants are allowed to delete redundant copy sets more aggressively than the no-structure variants

Two late-phase behaviors matter most.

### Equivalent-set removal

When Binaryen sees `local.set B (local.get A)` and already knows `A` and `B` are equivalent, it can delete the copy set:

- a tee copy becomes just the tee value
- a plain set becomes `drop(value)`

### Canonicalize toward the best equivalent local

When multiple equivalent locals exist, `visitLocalGet` chooses a preferred representative.
The tie-break is not arbitrary.
Binaryen prefers:

1. a more refined local type
2. otherwise the local with more remaining gets

That is one of the most non-obvious parts of the pass.
The late phase is not just removing copies; it is also deliberately improving the surviving local choice for downstream passes.

## Phase 8: final dead-set cleanup is delegated to `UnneededSetRemover`

After equivalent cleanup, Binaryen runs `UnneededSetRemover` from `local-utils.h`.
That helper removes:

- sets whose locals now have zero possible gets
- sets that assign the same value the local already holds, including through tee chains

The helper preserves effects correctly:

- dead tee -> underlying value
- dead effectful set -> `drop(value)`
- dead pure set -> `nop`

So the real late pass boundary is:

- equivalent-copy cleanup
- then unneeded-set cleanup

not just one or the other.

## Phase 9: validation repair is split between local refinalize and pass-runner fixups

Inside `SimplifyLocals.cpp`, Binaryen explicitly triggers `ReFinalize` when:

- direct sinking sharpens types
- equivalent-local canonicalization changes a `local.get` to a more refined equivalent local
- `UnneededSetRemover` deletes a tee whose value was more refined than the local type

But the full validation story is wider than the file itself.

`Pass::requiresNonNullableLocalFixups()` defaults to `true` in `pass.h`, and `PassRunner::handleAfterEffects(...)` therefore runs:

- `TypeUpdating::handleNonDefaultableLocals(func, *wasm)`

for `simplify-locals` automatically.

That is the upstream reason the dedicated GC validation tests exist.
The pass's correctness boundary is split between:

- local refinalization inside the pass
- nondefaultable-local structural fixups after the pass

## Helper and analysis dependencies that matter

These helpers are part of the real source contract, not optional implementation noise:

- `LinearExecutionWalker`
  - provides the cheap straight-line trace model and the optional adjacent-block connection model used later by `EquivalentOptimizer`
- `EffectAnalyzer`
  - decides whether pending writes may move across current code, whether values may throw, and whether dangling `pop` blocks sinking
- `BranchUtils::getUniqueTargets(...)`
  - marks named blocks unoptimizable when the pass hits unsupported target users like `Switch` / `BrOn`
- `FindAll<LocalSet>`
  - used in the special `br_if` condition hazard check for block-return formation
- `EquivalentSets`
  - tracks late equal-local groups
- `LocalGetCounter`
  - powers both the first-cycle single-use bias and late copy canonicalization heuristics
- `UnneededSetRemover`
  - owns the final dead-set cleanup surface
- `Builder::blockifyWithName(...)`
  - creates the extra trailing `nop` slots that structure rewrites sometimes require before the next cycle

## Scheduler placement and variant meaning

The source-backed scheduler story is richer than one public pass name suggests.

### Public registration surface

`pass.cpp` registers all five names:

- `simplify-locals`
- `simplify-locals-nonesting`
- `simplify-locals-notee`
- `simplify-locals-nostructure`
- `simplify-locals-notee-nostructure`

### Canonical no-DWARF `-O` / `-Os` path (`version_129` optimizeLevel=2, shrinkLevel=1)

Relevant slots are:

- early: `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> ...`
- late: `... -> local-cse? -> simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum`

The pass.cpp comment on the early slot is important and source-backed:

- do **not** create if/block return values yet, because earlier copy cleanup such as coalescing can remove copies that structure creation would inhibit

Then later, right before the full pass, pass.cpp says:

- `simplify-locals opens opportunities for optimizations`

That is the official reason the late full structured pass exists after the local-cleanup cluster.

### Aggressive optimizeLevel>=4 path

When Binaryen enables flat IR, it runs:

- `flatten -> simplify-locals-notee-nostructure -> local-cse`

This is why the dedicated flatten/souper combo tests matter to the dossier.
They document the intentionally flatter early locals cleanup that happens before general higher-level structure is reintroduced.

### Nested reruns

`opt-utils.h` uses `addDefaultFunctionOptimizationPasses()` inside `optimizeAfterInlining(...)`.
So whatever variant mix the current optimize settings would normally schedule can also appear in nested cleanup reruns after inlining or other optimizing module passes.

## Official test map

The dedicated lit files teach the pass surface very clearly when grouped by purpose.

### Core effect-ordering and call/global precision

- `simplify-locals-global.wast`
  - immutable `global.get` may move across a call; mutable `global.get` may not
- `global-effects_simplify-locals.wast`
  - `--generate-global-effects` lets the pass distinguish a call that only reads a global from one that writes it

### EH and try-boundary behavior

- `simplify-locals-eh.wast`
- `simplify-locals-eh-legacy.wast`
  - may-throw values cannot be sunk into `try` / `try_table`
  - non-throwing values still can
  - equivalent-copy canonicalization may look past adjacent dominated code even with EH enabled

### GC, nondefaultable-local, and type-refinement behavior

- `simplify-locals-gc.wast`
  - heap read/write barriers
  - immutable-field reorder allowances
  - `br_on` blocks structure-return formation
  - one-armed `if` skips nondefaultable locals
  - direct type refinement and later refinalization
- `simplify-locals-gc-nn.wast`
- `simplify-locals-gc-validation.wast`
  - structural dominance and nondefaultable-local fixup behavior after sinking

### Strings, tables, shared atomics, and TNH

- `simplify-locals-strings.wast`
  - `string.new_*_array` and `string.encode_*_array` ordering versus array loads/stores
- `simplify-locals-table_copy.wast`
  - `table.get` may move across `nop`, but not across `table.init`
- `simplify-locals-atomic-effects.wast`
  - shared/unshared memory and shared/unshared GC atomic ordering, including acquire/release asymmetry
- `simplify-locals-tnh.wast`
  - `trapsNeverHappen` opens some trap-commuting reorders, but the pass still stays single-basic-block in scope

### Cross-pass and flat/nonesting interactions

- `simplify-locals_rse_fallthrough.wast`
  - a tee that may look redundant is still required once `br_if` fallthrough semantics are considered alongside `rse`
- `flatten_simplify-locals-nonesting_dfo_O3.wast`
- `flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
- `flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`
  - the flat/nonesting variant is not just theoretical; it is part of real aggressive combo surfaces

## Important shape families

The official test surface and source comments highlight these durable shapes.

### Positive families

- single-use `local.set(value)` -> later `local.get` sink
- later-cycle `local.tee` formation for multi-use locals
- overwrite cleanup that turns dead earlier sets into `drop(value)`
- block return formation when every relevant exit sets the same local
- if/else return formation when both arms set the same local or one arm is unreachable
- one-armed `if` speculative value formation when the local type is defaultable
- loop return formation in the narrow trailing-nop case
- late replacement of `local.get $copy` with a better equivalent local
- dead set cleanup after late equal-local canonicalization

### Negative and bailout families

- unsupported branch-target users such as `Switch` / `BrOn` make named blocks unoptimizable for block-return synthesis
- `br_if` condition movement is blocked when the moved set could change condition semantics
- nondefaultable locals block one-armed `if` result synthesis
- values with dangling `pop` cannot be sunk
- may-throw values cannot be moved into `try` / `try_table`
- nonesting mode rejects sinks that would introduce new nesting
- trap, memory, table, string, atomic, and global ordering still block otherwise tempting sinks

## What a future Starshine port or refactor must preserve

A future honest Binaryen-parity port must keep these source-backed facts explicit:

- the five public pass names are one templated family with three axes, not five unrelated algorithms
- first-cycle single-use bias is deliberate and important
- effect ordering is the central safety rule, not adjacency
- structure synthesis is optional and intentionally delayed relative to the early no-structure slot
- one-armed `if` return formation is speculative and defaultable-only
- late equivalent-copy cleanup is a separate phase with its own adjacent-dominator model
- final dead-set cleanup is owned by `UnneededSetRemover`, not by ad hoc earlier peepholes
- validation repair is split between in-pass refinalization and pass-runner nondefaultable-local fixups
- current `main` does not show a meaningful semantic drift story beyond tiny container cleanup on the checked surfaces

## Uncertainty and limits

A few source-backed caveats should remain explicit in the living docs:

- `SimplifyLocals.cpp` itself still contains TODOs for broader support such as partial traces and richer `BrOn` / `Switch` handling
- the one-armed `if` result rewrite is explicitly speculative in the source comments, so profitability is not a stable theorem of the pass
- the freshness check here is intentionally narrow; it should not be over-read as a whole-Binaryen guarantee that every neighboring helper file is frozen

## Living-page update plan

The durable conclusions from this note should be filed back into the living wiki as:

- refreshed `docs/wiki/binaryen/passes/simplify-locals/index.md`
- refreshed `docs/wiki/binaryen/passes/simplify-locals/binaryen-strategy.md`
- refreshed `docs/wiki/binaryen/passes/simplify-locals/wat-shapes.md`
- new `docs/wiki/binaryen/passes/simplify-locals/implementation-structure-and-tests.md`
- new `docs/wiki/binaryen/passes/simplify-locals/variant-matrix-and-scheduler.md`
- tracker/index/log updates that record this major-gap fallback as closed
