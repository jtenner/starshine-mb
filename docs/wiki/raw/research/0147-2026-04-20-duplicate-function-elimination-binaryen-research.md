# 0147 - Binaryen `duplicate-function-elimination` research

## Scope

- Continue the Binaryen pass wiki-ing campaign after the refreshed `remove-unused-brs` dossier.
- Follow the repo wiki workflow in `docs/README.md`.
- Re-check the tracker, pass index, canonical no-DWARF path, and `agent-todo.md` before choosing a pass.
- Because the tracker no longer has a `none` queue, an implemented-landing queue, or the old tuple / RUME / RUB fallback gaps, justify any already-`deep` fallback explicitly.
- Deepen the existing `duplicate-function-elimination` folder with direct `version_129` source-backed teaching material.
- File the durable conclusions back into:
  - `docs/wiki/binaryen/passes/duplicate-function-elimination/`
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
5. re-checked the relevant backlog surface in `agent-todo.md`

At that point:

- the saved-audit `none` queue was already empty
- the implemented-landing queue was already closed
- the old tuple-opt major-gap fallback was already closed
- the old `remove-unused-module-elements` source-structure fallback was already closed
- the old `remove-unused-brs` implementation-map / WAT-shape fallback was already closed

So this run needed a justified major-gap fallback.

I picked `duplicate-function-elimination` for four source-backed reasons:

- It is still one of the most scheduler-relevant implemented module passes in the repo:
  - Binaryen `version_129` runs it at the start of the global pre-pass cluster
  - and then runs it again in the global post-pass cluster after `dae-optimizing` and `inlining-optimizing`
- The existing folder was already broad, but the core teaching contract was still stale in an important way:
  - the old dossier largely inherited a March `v125` view
  - and it treated Binaryen DFE as if type compaction, name stripping, and other metadata normalization were part of the upstream pass itself
- Direct `version_129` source review showed a much narrower official implementation:
  - one module pass
  - hash defined functions
  - exact-compare within hash buckets
  - remove duplicates
  - rewrite function references
  - rerun according to an option-dependent iteration budget
- That gap is major because future Starshine work could otherwise target the wrong parity surface.
  - The current MoonBit pass does extra useful work, but those extras are not the same thing as Binaryen's official DFE contract.

So this thread is not about changing tracker status.
It is about closing a still-real official-source gap in an already-deep folder: the existing DFE docs needed to separate **upstream DFE proper** from **current Starshine-local extras**.

## Official Binaryen source inventory

Primary `version_129` sources used for this research:

- core pass implementation:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp>
- pass registration and scheduler placement:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- helper surfaces the pass actually depends on:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- representative official test families:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_annotations.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_branch-hints.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=1.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=2.wast>

## Freshness and source-trust rule

This dossier treats Binaryen `version_129` as the release oracle.

I also did a narrow current-main check on the core file and dedicated lit surface:

- all five dedicated `duplicate-function-elimination*` lit files are byte-identical between `version_129` and `main`
- the core implementation has only a tiny non-semantic drift:
  - `std::set<Name> duplicates` became `std::unordered_set<Name> duplicates`
- the algorithm shape, option-dependent iteration budget, helper usage, and test expectations are otherwise unchanged on the checked surfaces

That is intentionally a **narrow** freshness statement, not a whole-repo equivalence proof.
The durable rule for the living pages should be:

- use `version_129` as the normative algorithm oracle
- record current-main drift explicitly when it matters
- do not silently rewrite the `version_129` teaching story as if the released algorithm already included unrelated local or trunk-only behavior

## Repo-local sources used for context

- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `agent-todo.md`
- the older archived DFE note:
  - `docs/wiki/raw/research/0067-2026-03-24-duplicate-function-elimination.md`
- the later health rerun note:
  - `docs/wiki/raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`
- in-tree implementation/tests:
  - `src/passes/duplicate_function_elimination.mbt`
  - `src/passes/duplicate_function_elimination_test.mbt`
  - `src/passes/optimize.mbt`
  - `src/passes/registry_test.mbt`
  - `src/cmd/cmd_wbtest.mbt`

## High-level conclusion

Binaryen `duplicate-function-elimination` is much narrower than the current local MoonBit implementation.

The upstream `version_129` pass is basically:

1. choose an iteration budget from optimization settings
2. hash all functions in parallel
3. bucket **defined** functions by hash
4. exact-compare candidates inside each bucket
5. keep the earliest equal function as the survivor
6. remove later duplicates
7. rewrite function references through `OptUtils::replaceFunctions(...)`
8. repeat until no replacements remain or the budget is exhausted

That is the real official contract.

It is **not** a type-section compactor.
It is **not** a name-section stripper.
It is **not** a generic metadata normalizer.
It is **not** a HOT pass.

## Biggest beginner correction

The old easy misunderstanding was:

- “Binaryen DFE merges duplicate functions and then also compacts simple duplicate function types, rewrites lots of type-index users, strips names, and canonicalizes element forms.”

That statement describes the **current Starshine pass**, not the official Binaryen pass.

The safer source-backed mental model is:

- Binaryen DFE is a small module pass whose whole job is duplicate-function identity and function-reference rewriting.
- If a local implementation also performs type compaction, name stripping, annotation-map rewriting, or element-kind normalization, those are additional transforms layered on top.

That distinction matters for future parity work.
Without it, a port can accidentally chase local cleanup behavior as if it were a required Binaryen DFE invariant.

## Exact implementation structure

## Phase 0: pass shape and scheduler intent

`DuplicateFunctionElimination.cpp` defines a single `Pass` subclass.

Two small overrides already teach the real scope:

- `invalidatesDWARF() -> true`
  - merging functions necessarily disturbs debug mappings
- `requiresNonNullableLocalFixups() -> false`
  - the pass does not rewrite function bodies in a way that needs later local-type repair

So the pass is intentionally module-scoped but mechanically simple.

## Phase 1: choose the iteration budget

The first nontrivial logic in `run(Module* module)` is the limit computation.

Source-backed rule:

- default explicit pass execution without stronger optimize/shrink settings: `1` round
- `optimizeLevel >= 2`: `10` rounds
- `optimizeLevel >= 3` or `shrinkLevel >= 1`: effectively no practical limit (`module->functions.size()`)

This is a very important contract detail.
The same pass name does **not** imply the same amount of work in all scheduler contexts.

That is why the dedicated `duplicate-function-elimination_optimize-level=1.wast` and `duplicate-function-elimination_optimize-level=2.wast` files exist.
They are not redundant copies; they lock in the iteration-budget story.

## Phase 2: hash all functions in parallel

Binaryen uses `FunctionHasher` from `ir/hashed.h`.

That helper hashes:

- the function type
- local variable types
- the function body via `ExpressionAnalyzer::flexibleHash(...)`

Important subtlety:

- `FunctionHasher` does **not** hash metadata such as branch hints or debug info
- so the hash is only a candidate filter
- exact equality still happens later

The helper is function-parallel, which is why the pass stays fast enough to run both early and late in the default optimizer.

## Phase 3: bucket only defined functions by hash

The pass groups candidates with:

- `ModuleUtils::iterDefinedFunctions(*module, ...)`

This is the source-backed reason imports are never duplicate candidates here.
Even though `FunctionUtils::equal(...)` can talk about imported-vs-defined behavior generically, the actual DFE pass only feeds it defined functions.

## Phase 4: exact equality inside each bucket

For each hash bucket with more than one function, the pass does an O(N²) scan.

Important details from the file structure:

- bucket vectors preserve defined-function order
- the first surviving function is always earlier in module order
- later equal functions are mapped to that first survivor
- already-marked duplicates are skipped as the nested loops continue

This gives a deterministic “first survivor wins” rule.

That matters because one function's name and non-semantic metadata will survive while the other's will not.
The branch-hints and source-location tests make that visible.

## Phase 5: actual equality contract from `FunctionUtils::equal(...)`

The real equality helper lives in `ir/function-utils.h`.

It compares:

- exact function type equality
- exact non-param local-type equality
- semantic-altering function annotations via `Intrinsics::getAnnotations(...)`
- imported-vs-defined status
- and expression-body equality via `ExpressionAnalyzer::equal(...)`

It intentionally does **not** treat ordinary metadata as a blocker.
The file comment explicitly says Binaryen wants to merge functions that differ only in metadata, following LLVM's example.

That is the source-backed explanation for why the dedicated test suite shows these behaviors:

- differing branch hints still merge
- differing source file / debug location still merge
- differing semantic annotations such as `@binaryen.js.called`, `@binaryen.removable.if.unused`, and `@binaryen.idempotent` do **not** merge

There is also an explicit TODO in the helper:

- expression-level annotations are not fully compared here yet

That is worth recording because it explains why the equality contract sounds broader than the exact helper implementation really is.

## Phase 6: remove duplicates and rewrite surviving references

If at least one duplicate was found:

1. `module->removeFunctions(...)` deletes the duplicate definitions
2. `OptUtils::replaceFunctions(...)` rewrites users of the old function names

The helper surface in `opt-utils.h` is smaller than many older summaries implied.
It rewrites:

- direct call targets
- `ref.func` users in function code and module code
- `start`
- function exports

Because `ref.func` may appear in module code, that covers globals and element expressions that carry function references too.
The all-features test makes this visible with a global initializer that feeds a later `call_ref`.

## Phase 7: iterate if replacements unlocked new duplicates

After replacements, another round may discover newly identical callers.
That is the whole reason the pass has an iteration budget at all.

The dedicated optimize-level tests show the beginner version of this story:

- at low/default settings, one visible round can leave a second-order duplicate behind
- at `optimize-level=2`, later rounds can then merge that newly-exposed caller pair too

## Official test map and what each file teaches

## `duplicate-function-elimination_all-features.wast`

This is the best file for the basic rewrite surface.
It shows:

- `ref.func` keeps a duplicate function live until the reference is retargeted
- names that collide across namespaces are not globally renamed just because a function was deduplicated
- a global initialized with `ref.func $dup` must be rewritten to point at the survivor
- later `call_ref` code then uses that rewritten global successfully

In short:

- DFE is about function identity and function references, not arbitrary symbol renaming.

## `duplicate-function-elimination_annotations.wast`

This file teaches the semantic-annotation boundary.
It shows that functions stay separate when only one side has a semantics-altering annotation, including:

- `@binaryen.js.called`
- `@binaryen.removable.if.unused`
- `@binaryen.idempotent`

And it shows that when both functions carry the same semantics-altering annotation, they can merge again.

## `duplicate-function-elimination_branch-hints.wast`

This file teaches the opposite rule.
It shows that non-semantic metadata differences do **not** block merging, including:

- differing branch hints
- missing-vs-present branch hints
- differing source file locations / debug-info comments

Just as important, it shows the survivor rule:

- after merging, the surviving function keeps the earlier function's metadata surface

## `duplicate-function-elimination_optimize-level=1.wast`

This file teaches the conservative iteration budget.
It locks in the fact that low/default optimization does not keep iterating until every transitive caller cleanup opportunity is gone.

## `duplicate-function-elimination_optimize-level=2.wast`

This file teaches the higher-budget story.
It shows that the same pass at stronger optimize settings can continue far enough to remove second-order duplicates exposed by earlier rewrites.

## Scheduler placement in `pass.cpp`

The official no-DWARF default scheduler uses DFE twice:

- once at the start of global pre-passes
- again in global post-passes after DAE / inlining work may have created new duplicates

That means the pass is both:

- an early “save work later” cleanup
- and a late “cleanup new duplication after bigger transforms” pass

This is another place where the current local Starshine preset is narrower than the upstream contract.

## Important helper dependencies and what they are doing

- `FunctionHasher`
  - fast parallel candidate bucketing, deliberately not a proof of equality
- `FunctionUtils::equal`
  - the real semantic gate for merging
- `ModuleUtils::iterDefinedFunctions`
  - source-backed reason imports are excluded
- `OptUtils::replaceFunctions`
  - whole-module function-reference retargeting after deletion
- `PassRunner` options from `pass.cpp`
  - source-backed reason DFE behaves differently at direct/default, `-O2`, and `-O3` / shrink settings

## What upstream DFE does **not** do

This section is the most useful one for future parity work.

Official Binaryen `version_129` DFE does **not** itself:

- compact duplicate function types after merge
- rewrite unrelated type-index-bearing instructions as part of DFE
- strip the wasm name section as a DFE-specific cleanup
- canonicalize element kinds from expression form back to compact function-list form
- rewrite function-annotation sections as a dedicated metadata-normalization phase
- run as a nested optimizeAfterInlining helper
- become a per-function HOT pass

If a local implementation performs those actions, they should be tracked as:

- local extras
- adjacent cleanup decisions
- or deliberate combined-pass behavior

but not silently attributed to official DFE.

## Current Starshine comparison

The current MoonBit pass in `src/passes/duplicate_function_elimination.mbt` is broader than official Binaryen DFE.

Local code adds or folds in at least these surfaces:

- duplicate simple-type canonicalization
- wide type-index rewriting across many instruction families
- element-kind canonicalization
- name-section stripping
- function-annotation-section rewrite bookkeeping

That does not automatically make the local pass wrong.
But it **does** mean the old wiki phrasing overstated the official Binaryen contract.

The practical parity takeaway is:

- keep “core Binaryen DFE parity” separate from “current Starshine DFE-plus-extra-cleanup behavior”.

## Durable conclusions to file back into the living wiki

- Upstream Binaryen `version_129` DFE is a small hash / equality / rewrite module pass with an option-dependent iteration budget.
- The pass runs twice in the default no-DWARF pipeline: early pre-pass and late post-pass.
- Imported functions are not DFE candidates because the pass only buckets defined functions.
- Non-semantic metadata differences like branch hints and debug locations do not block merging.
- Semantic-altering function annotations do block merging unless they match.
- The existing Starshine pass does substantially more than the official DFE source, so parity notes must separate upstream contract from local extras.
- Current `main` shows only a tiny non-semantic container change on the checked core source surface, and the dedicated lit files are unchanged.

## Sources

Official Binaryen sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_annotations.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_branch-hints.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=1.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=2.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_annotations.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_branch-hints.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_optimize-level=1.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_optimize-level=2.wast>

Repo-local context:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/raw/research/0067-2026-03-24-duplicate-function-elimination.md`
- `docs/wiki/raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`
- `src/passes/duplicate_function_elimination.mbt`
- `src/passes/duplicate_function_elimination_test.mbt`
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`
