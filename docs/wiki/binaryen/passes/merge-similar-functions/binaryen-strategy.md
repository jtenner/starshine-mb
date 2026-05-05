---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-merge-similar-functions-current-main-recheck.md
  - ../../../raw/research/0443-2026-05-05-merge-similar-functions-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md
  - ../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md
  - ../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeSimilarFunctions.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./profitability-indirection-and-type-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen strategy for `merge-similar-functions`

## What the pass really is

The reviewed implementation is a **late whole-module size optimization**.
Its purpose is not to delete exact duplicates, but to turn a class of **near-duplicate functions** into:

- one shared helper body, plus
- many tiny per-function thunks.

The shared helper is parameterized by the pieces that differ between the originals.
In `version_129`, those differences are intentionally narrow:

- literal payloads in `const` nodes
- and, when reference types plus GC are enabled, some direct `call` targets

So the best mental model is:

- **function parameterization for code size**
- not DFE
- not inlining
- not region outlining
- not semantic whole-program equivalence proving

## Scheduler placement

`src/passes/pass.cpp` registers `merge-similar-functions` as a normal public pass.

The important scheduler detail is in `PassRunner::addDefaultGlobalOptimizationPostPasses()`:

- `duplicate-function-elimination`
- `duplicate-import-elimination`
- `merge-similar-functions` when `shrinkLevel >= 2`
- `simplify-globals-optimizing` or `simplify-globals`
- `remove-unused-module-elements`
- later late-global cleanup like `string-gathering`, `reorder-globals`, and `directize`

That means:

- it is real upstream public surface
- it is a **late global post-pass**, not a hot per-function pass
- it belongs to Binaryen's shrink-oriented schedule, not the repo's current no-DWARF `-O` / `-Os` page

## Core data structures

### `EquivalentClass`

Represents one mergeable family.
It holds:

- one primary function
- the full set of functions considered equivalent except for parameterizable differences

The primary function is the body Binaryen clones into the new shared helper.

### `ParamInfo`

Represents one synthetic parameter in the shared helper.
It stores:

- all concrete per-function values for that synthetic parameter
- every use site in the primary function that should become a `local.get`

The value set is stored as either:

- a literal vector, or
- a callee-name vector for the call-target-parameterization path

This split is why the shared helper can emit either:

- ordinary constant expressions in the thunks, or
- `ref.func` payloads passed to a function-ref param

## Main algorithmic phases

## Phase 0: early rejection

Before considering the more interesting comparison logic, Binaryen rejects pairs that differ on:

- import status
- top-level function type
- total local count

That keeps the rest of the algorithm focused on same-signature, same-local-layout candidates.

## Phase 1: coarse grouping by hash

The pass begins by hashing each defined function.
The hash is not ordinary “full body equality.”
Binaryen customizes `FunctionHasher` so the digest ignores:

- `Const` immediates
- direct `Call` targets

while still keeping the rest of the structure.

Important detail: the custom call hashing still includes:

- recursively hashed call operands
- `call->isReturn`

The point of this phase is speed:

- avoid comparing every function against every other function
- only do the slower exact comparison inside same-hash buckets

## Phase 2: exact equivalence-class formation

Every hash bucket is then split into real equivalence classes.
Binaryen uses `ExpressionAnalyzer::flexibleEqual(...)` with a custom comparer.

Two bodies can end up in the same class only if they match on:

- node ids
- node result types
- overall structure
- call operand structure
- callee signature compatibility when the only difference is the call target

This is the phase that keeps the pass from over-merging.

Important teaching point:

- matching hash does **not** mean mergeable
- the hash is only a prefilter
- the exact class split is a separate and stricter source-backed stage

## Phase 3: derive synthetic parameters

Once a class has at least two functions, Binaryen walks the primary body and all siblings in lockstep.
The implementation uses an internal DFS `DeepValueIterator` over `Expression**` slots.

Whenever it sees a differing parameterizable site, it derives a synthetic parameter.

Two difference kinds are supported.

### Difference kind 1: literal payloads

If the same `const` node shape appears in all functions but the literal values differ, that value vector becomes a candidate `ParamInfo`.

### Difference kind 2: direct `call` target names

If the same direct `call` shape appears in all functions and call indirection is enabled, the pass can collect the differing callee names instead.

But this is only legal if:

- reference types are enabled
- GC is enabled
- the differing callees have the same function type

Otherwise the class can still match structurally as “same body shape,” but the parameter derivation path fails for that call-target difference.

### Reusing synthetic params

If two sites produce the same per-function diff-vector, Binaryen reuses the same synthetic param.

That means a future port must not naïvely invent one synthetic param per differing node.
The implementation explicitly compresses repeated difference-vectors.

## Phase 4: benefit and hard-limit checks

Not every legal class is profitable.
`hasMergeBenefit(...)` applies two important screens.

### Hard parameter-limit gate

The final synthetic signature must fit under `MaxSyntheticFunctionParams`.
In `version_129`, that constant is `255`.

So if:

- original params + synthetic params > 255

Binaryen rejects the class outright.

### Approximate size-benefit heuristic

Binaryen uses exact fixed weights in the implementation:

- `INSTR_WEIGHT = 1`
- `CODE_SEC_LOCALS_WEIGHT = 1`
- `CODE_SEC_ENTRY_WEIGHT = 2`
- `FUNC_SEC_ENTRY_WEIGHT = 2`

and compares a positive score from removed duplicated instructions against a negative score from thunk forwarding plus helper and function-section overhead.

This is why tiny “same except one constant” wrappers can remain unchanged in the tests.

## Phase 5: create the shared helper

`createShared(...)` performs the body rewrite.

It:

1. creates a fresh helper name using `Names::getValidFunctionName(...)`
2. builds a new signature with original params first and synthetic params appended after them
3. clones the primary body with `ExpressionManipulator::flexibleCopy(...)`
4. rewrites every parameterized const site into a `local.get` of the synthetic param
5. rewrites parameterized direct `call` sites into `call_ref`
6. shifts the original non-param locals upward so local indices still point at the same logical variables after the new params are inserted

That local-index repair is one of the pass's core correctness obligations.

## Phase 6: replace originals with thunks

Each original function becomes a thin wrapper that:

- reads its original params with `local.get`
- adds one argument per synthetic param
- materializes literals directly or uses `ref.func` for call-target params
- calls the shared helper

When tail calls are enabled and the original rewrite shape allows it, the thunk path uses `return_call`, while the shared helper preserves the original call's `isReturn` bit when rebuilding parameterized call sites as `call_ref`.

So the visible output contract is:

- original function names remain
- shared helper gets a generated `byn$mgfn-shared$...` name
- public entrypoints now forward into the helper

## Exact mechanics page

The algorithm above is still a summary.
For the source-confirmed details that are easiest to mis-port, see:

- [`./equivalence-classes-param-derivation-and-thunk-rewrites.md`](./equivalence-classes-param-derivation-and-thunk-rewrites.md)

That page isolates:

- same-hash versus same-class
- the lockstep DFS `DeepValueIterator` walk
- exact diff-vector reuse
- helper clone-and-rewrite mechanics
- non-param local-index shifting
- original-name-preserving thunk replacement

## Call-target parameterization in plain language

This is the most beginner-surprising part of the pass.

Suppose the only meaningful difference between two large wrappers is:

- function A calls `$foo`
- function B calls `$bar`

If:

- reference types + GC are enabled, and
- `$foo` and `$bar` have the same signature,

Binaryen can rewrite the shared helper so it takes a function reference parameter.
Then:

- thunk A passes `(ref.func $foo)`
- thunk B passes `(ref.func $bar)`
- shared helper uses `call_ref`

This is why the pass is not merely about constants.
But it is also why the type barriers are strict.

## Important helper dependencies

## `FunctionHasher`

Provides the hash-based coarse grouping step that keeps the pass scalable.

## `ExpressionAnalyzer::flexibleEqual`

Provides the structural “same body except allowed differences” proof.

## `ExpressionManipulator::flexibleCopy`

Provides the clone-and-rewrite machinery for building the shared helper body from the primary function.

## `ModuleUtils::iterDefinedFunctions`

Keeps the scan restricted to defined functions.
Imports are not eligible.

## `Names::getValidFunctionName`

Generates a collision-free helper symbol name.

## `MaxSyntheticFunctionParams`

Provides the hard signature-width cutoff that the pass must obey.

## Positive families

## 1. Large wrappers that only differ by one or more literals

This is the canonical happy path.
The shared helper replaces those literals with synthetic param reads.

## 2. Large wrappers that call different same-signature direct callees

With reference types + GC, these can become function-ref-param helpers that use `call_ref`.

## 3. Functions with repeated identical diff-vectors

Repeated sites can reuse one synthetic parameter.
This reduces glue size and is part of the real profitability story.

## 4. Existing params and locals

The pass preserves original params, appends synthetic ones, and repairs local indices for existing non-param locals.

## 5. Returning wrappers in tail-call-enabled modules

Tail-call style is preserved through `return_call` / `return_call_ref` when applicable.

## Negative and bailout families

## 1. Exact duplicates belong to DFE, not here

This pass is not the first tool for exact body duplication.
Its value begins where “almost the same” matters.

## 2. Tiny functions often fail profitability

Even legal merges may lose on code size once thunk and helper overhead are counted.

## 3. Imports never qualify

The source rejects imported functions up front.

## 4. Different top-level function signatures never qualify

The original wrapper functions themselves must have the same function type.

## 5. Different local counts never qualify

The pass assumes a single primary-body local layout that siblings can match.

## 6. Call-target parameterization fails on type mismatch

If differing callees do not share one safe function type, Binaryen will not merge through a function-ref parameter.

## 7. Same hash can still split into multiple non-mergeable classes

The coarse hash only means “worth checking.”
Different operand structure or stricter equality failures can still keep functions apart.

## 8. Signature-width overflow blocks otherwise-legal classes

Too many synthetic params kills the merge.

## Current-main drift check

A 2026-05-05 current-main recheck found no diff in `src/passes/MergeSimilarFunctions.cpp` compared with `version_129`.

That is narrow evidence, but it is enough to keep `version_129` as the main oracle for this dossier.

## Pass interactions

### Versus `duplicate-function-elimination`

- DFE removes exact duplicates.
- `merge-similar-functions` rewrites near-duplicates into helper-plus-thunk form.

They are neighbors in the same late size-oriented phase, but they solve different problems.

### Versus `duplicate-import-elimination`

- DIE canonicalizes imported declarations.
- `merge-similar-functions` canonicalizes defined wrapper bodies.

They are adjacent late module cleanups, not overlapping engines.

### Versus `simplify-globals*`

`merge-similar-functions` happens before late global cleanup in the reviewed scheduler, so the module may already be smaller and structurally simpler when the later global passes run.

### Versus inlining

Inlining expands bodies into callers.
`merge-similar-functions` shrinks near-duplicate callers or wrappers into one helper.
The directions are opposite.

## What a future Starshine port must preserve

A faithful port should preserve:

- late module-pass scheduling
- hash-prefilter + exact-compare structure
- the narrow allowed-difference surface
- call-target parameterization only under the same feature and type gates
- synthetic-param reuse for repeated identical diff-vectors
- local-index repair after appending params
- thunk replacement of originals
- the hard 255-param bound
- a conservative profitability check that leaves tiny functions alone

## Easy-to-miss teaching summary

If someone remembers only one sentence, it should be this:

> Binaryen `merge-similar-functions` is a shrink-oriented whole-module parameterization pass: it turns groups of near-identical functions into one cloned shared helper plus thin thunks, but only for a narrow source-backed set of differences and only when the helper-thunk rewrite is still worth it.

## Sources

- [`../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md`](../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md)
- [`../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md`](../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md`](../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md)
- [`../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md`](../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeSimilarFunctions.cpp>
