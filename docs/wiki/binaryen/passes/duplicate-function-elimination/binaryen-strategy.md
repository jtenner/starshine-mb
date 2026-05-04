---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-duplicate-function-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md
  - ../../../raw/research/0242-2026-04-22-duplicate-function-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./type-compaction-and-metadata.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `duplicate-function-elimination` strategy

## Upstream source rule

Use Binaryen `version_129` as the primary source oracle for this pass.

Primary files:

- `src/passes/DuplicateFunctionElimination.cpp`
- `src/passes/pass.cpp`

Most important helper dependencies visible in the implementation:

- `FunctionUtils::equal(...)`
- `FunctionHasher`
- `ModuleUtils::iterDefinedFunctions(...)`
- `OptUtils::replaceFunctions(...)`

Dedicated official test surfaces:

- `test/lit/passes/duplicate-function-elimination_all-features.wast`
- `test/lit/passes/duplicate-function-elimination_annotations.wast`
- `test/lit/passes/duplicate-function-elimination_branch-hints.wast`
- `test/lit/passes/duplicate-function-elimination_optimize-level=1.wast`
- `test/lit/passes/duplicate-function-elimination_optimize-level=2.wast`

## High-level intent

Binaryen uses `duplicate-function-elimination` to delete duplicate **defined** functions and retarget users to the surviving definition.

The real contract is intentionally small:

1. hash candidate functions quickly
2. exact-compare only functions with matching hashes
3. remove later duplicates
4. rewrite function references
5. repeat when optimization settings justify it

That narrowness matters.
This pass is not where Binaryen performs type-section compaction or generic metadata normalization.

## Where the pass runs

In `pass.cpp`, the default no-DWARF optimizer inserts DFE twice.

### Early global pre-pass

`PassRunner::addDefaultGlobalOptimizationPrePasses()` begins with:

- `duplicate-function-elimination`

and the file comment explains why:

- removing duplicate functions is fast and saves work later

So DFE is an intentional early cheap cleanup.

### Late global post-pass

`PassRunner::addDefaultGlobalOptimizationPostPasses()` inserts DFE again after:

- `dae-optimizing`
- `inlining-optimizing`

The comment there is equally important:

- later optimizations show more functions as duplicate

So the second DFE run is not redundant.
It is a cleanup pass for duplication created by stronger transforms.

## Not a nested helper rerun

DFE is **not** part of Binaryen's `optimizeAfterInlining(...)` nested helper in `opt-utils.h`.
It is a top-level module pass scheduled by `pass.cpp`.

That means a faithful Starshine scheduler should model:

- an early pre-pass slot
- and a late post-pass slot

not a hidden per-function nested rerun.

## Phase 1: pass identity and fixup policy

The pass overrides two small but revealing methods.

- `invalidatesDWARF() -> true`
  - deduplication changes function identity enough that DWARF is no longer trustworthy
- `requiresNonNullableLocalFixups() -> false`
  - the pass does not rewrite bodies in a way that needs later nonnullable-local repair

So the pass is whole-module, but mechanically conservative.

## Phase 2: choose the iteration budget from pass options

The first substantial logic in `run(Module* module)` computes `limit` from optimization settings.

Source-backed rule:

- direct/default pass execution: `1` round
- `optimizeLevel >= 2`: `10` rounds
- `optimizeLevel >= 3` or `shrinkLevel >= 1`: `module->functions.size()` rounds, effectively “until done” for practical purposes

This is one of the most important scheduler details in the whole dossier.
The same pass name has different visible behavior depending on its option context.

## Phase 3: hash all functions in parallel

Each iteration starts by creating a `FunctionHasher::Map` and running `FunctionHasher` over the module.

Important details from `ir/hashed.h`:

- hashing is function-parallel
- the hash includes:
  - function type
  - local variable types
  - body hash via `ExpressionAnalyzer::flexibleHash(...)`
- the hash intentionally does **not** include metadata such as branch hints or debug info

So the hash is only a candidate prefilter.
It narrows the exact-comparison work, but it is not a proof of equality.

## Phase 4: group only defined functions by hash

The pass uses `ModuleUtils::iterDefinedFunctions(*module, ...)` to populate the hash groups.

This is the exact source-backed reason imports are not DFE candidates.
Even though the equality helper has generic imported-vs-defined logic, the actual pass only ever groups defined functions.

## Phase 5: exact equality within each bucket

For each hash bucket with more than one function, Binaryen does a nested scan.

The key algorithmic properties are:

- function order inside a bucket follows module order
- the earliest function becomes the survivor
- later equal functions are mapped to that survivor
- functions already marked duplicate are skipped in later comparisons

This yields a stable “first survivor wins” rule.
That rule matters because it decides which name and which non-semantic metadata surface survive after deduplication.

## Phase 6: actual equality contract from `FunctionUtils::equal(...)`

The real equality helper is in `ir/function-utils.h`.

It checks:

- exact function-type equality
- exact non-param local-type equality
- semantics-altering function annotations
- imported-vs-defined status
- expression-body equality

It intentionally does **not** treat ordinary metadata as a blocker.
The helper comment explicitly says Binaryen wants to merge functions that differ only in metadata for optimization purposes.

This explains the official test behavior:

- different branch hints can still merge
- different source locations / debug comments can still merge
- different semantics-altering annotations such as `js.called`, `removable.if.unused`, or `idempotent` block merging unless both sides match

There is also an explicit TODO in the helper:

- expression-level annotations are not fully compared there yet

## Phase 7: remove duplicates and rewrite references

If at least one duplicate was found in an iteration:

1. `module->removeFunctions(...)` deletes the duplicate definitions
2. `OptUtils::replaceFunctions(...)` retargets users of those deleted names

The rewrite helper in `opt-utils.h` covers:

- direct call targets
- `ref.func` users in function code and module code
- `start`
- function exports

Because module code is included, this also covers places like:

- globals initialized by `ref.func`
- element expressions containing `ref.func`

The all-features lit file makes that visible with a global feeding a later `call_ref`.

## Phase 8: iterate when rewrites expose new duplicates

If replacements occurred, the pass loops again while `limit > 0`.

This is how Binaryen catches second-order cases like:

- two callers that were not originally equal because they called different functions
- those callees merge in round 1
- the callers become equal in round 2

The dedicated optimize-level tests exist specifically to lock in that story.

## What this pass does **not** do

These non-goals are crucial for keeping the wiki honest.

Official Binaryen DFE does **not** itself:

- compact duplicate function types after merge
- rewrite arbitrary type-index-bearing instructions as part of the DFE algorithm
- strip the wasm name section
- canonicalize element kinds back to compact function-list form
- rewrite function-annotation sections as a separate metadata pass
- run as a HOT pass
- participate in `optimizeAfterInlining(...)` nested cleanup

If local code does those things, that is a **local extension around DFE**, not the official DFE contract.

## Current freshness note

A narrow 2026-05-04 check still found no semantic post-`version_129` drift on the dedicated DFE surface.

- current `main` changes the duplicate-name container from `std::set<Name>` to `std::unordered_set<Name>`
- the dedicated lit files are unchanged

So the living wiki should continue to treat `version_129` as the released oracle for DFE behavior.

## What a future port must preserve

A future strict-parity Starshine scheduler or refactor must keep these source-backed rules honest:

- DFE is a module pass, not a HOT pass
- it runs twice in the default no-DWARF pipeline
- imported functions are excluded because grouping only considers defined functions
- hash equality is only a prefilter; exact equality decides safety
- non-semantic metadata differences do not block merges
- semantics-altering annotations do block merges unless they match
- the survivor is the earliest function in bucket order
- the visible amount of transitive cleanup depends on optimize/shrink settings
- reference rewriting is function-name rewriting, not a generic type/metadata cleanup phase

If local code intentionally broadens or narrows any of those rules, keep that as an explicit documented divergence.
