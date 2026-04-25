---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md
  - ../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeSimilarFunctions.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./profitability-indirection-and-type-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Equivalence classes, param derivation, and thunk rewrites in `merge-similar-functions`

This page covers the exact mechanics that are easiest to gloss over when the pass is taught only as “merge near-duplicate functions.”

The real Binaryen `version_129` contract is more specific:

- first prove candidate functions are even comparable
- then hash them while ignoring only a narrow set of differences
- then split same-hash buckets into real equivalence classes
- then derive reusable diff-vectors in lockstep DFS order
- then clone one primary body into a shared helper
- then replace the originals with thunks

That ordering matters.

## Why this page exists

The existing dossier already explained what the pass does.
The major remaining gap was that it did not isolate the exact source-confirmed mechanics well enough for a future port.

Without these details, a port can easily go wrong by:

- treating same-hash functions as automatically mergeable
- deriving one synthetic param per differing node instead of reusing diff-vectors
- forgetting that call-target parameterization is feature-gated
- forgetting to shift old non-param local indices upward after appending synthetic params
- or accidentally moving public function identity from the original functions to the helper

## Stage 0: early rejection before the interesting logic starts

Binaryen refuses to compare two functions further unless all of these hold:

- both are defined, not imported
- `lhs->type == rhs->type`
- `lhs->getNumVars() == rhs->getNumVars()`

This is the first important beginner correction.
The pass is not trying to reconcile arbitrary local layouts or signature differences.

## Stage 1: same hash is only a coarse prefilter

`collectEquivalentClasses(...)` uses `FunctionHasher` with custom handling that ignores:

- `Const` immediate payloads
- direct `Call` target names

But it still keeps meaningful structure.

### What still matters in the hash

For direct calls, Binaryen still hashes:

- recursively hashed call operands
- `call->isReturn`

So the hash is **not** “ignore all call details.”
It is “ignore the direct callee name, but still care about argument structure and whether the call is a return-call shape.”

## Stage 2: same hash still does not mean same class

After hashing, Binaryen splits each same-hash group into real equivalence classes with `areInEquvalentClass(...)` and `ExpressionAnalyzer::flexibleEqual(...)`.

The custom comparer still requires:

- same expression id
- same expression result type
- same call operand count
- same call result type
- same callee function signature when direct callee names differ
- recursively equal call operands under the same comparer
- same literal type for differing `Const` nodes

That is why the source has an explicit “same hash but different instruction pattern” path.

## The exact allowed-difference surface

During equivalence checking, only two families may differ.

### 1. `Const`

The literal payload may differ, but the literal type must still match.

### 2. Direct `Call`

Direct call targets may differ, but only when call indirection is enabled.

`isCallIndirectionEnabled(...)` requires:

- reference types
- GC

Even then, the two callees must have the same function type.

So the pass is not a generic “parameterize any function-ish thing” optimizer.
It is a small source-backed family over `Const` and eligible direct `Call` sites.

## Stage 3: parameter derivation is a lockstep DFS walk

`EquivalentClass::deriveParams(...)` defines a small internal `DeepValueIterator` that walks `Expression**` slots in DFS order.

Binaryen uses:

- one iterator for the primary function body
- one parallel iterator per sibling function body

That means the pass is not scanning one body independently and asking “where do I see constants?”
It is walking all bodies in lockstep after equivalence has already proved they share the same structure.

## What becomes a synthetic param

At each visited site, Binaryen only tries to build a diff-vector for:

- `Const`
- `Call`, when call indirection is enabled

For everything else, the pass just advances sibling iterators after asserting that they are currently on the same instruction kind.

### "All same" means "no param"

Even at a `Const` or eligible `Call` site, Binaryen skips param creation if every function in the class has the same value there.

So synthetic params only represent real per-function differences.

## Diff-vector reuse is exact equality on the full vector

When a site differs, Binaryen builds one `ConstDiff`:

- either a `Literals` vector
- or a `std::vector<Name>` of callee names

Then it searches existing params for `param.values == diff`.

If found:

- append the current use site to that param's `uses`

If not found:

- create a new `ParamInfo`

This is the source-confirmed rule behind the famous “use 42 twice / use 43 twice” family.
One helper param can feed multiple use sites because Binaryen keys reuse on exact per-function diff-vector equality.

## Stage 4: helper creation is clone-and-rewrite, not fresh synthesis

`createShared(...)` makes a new helper named like `byn$mgfn-shared$...` and builds its signature as:

1. all original params first
2. all synthetic params after them

Two index boundaries are central:

- `extraParamBase = primaryFunction->getNumParams()`
- `newVarBase = primaryFunction->getNumParams() + params.size()`

Then Binaryen clones the primary body with `ExpressionManipulator::flexibleCopy(...)` and a custom copier.

## What the custom copier actually rewrites

### 1. Parameterized const sites

A recorded const-difference use site becomes:

- `local.get(extraParamBase + paramIdx, paramType)`

### 2. Parameterized direct-call sites

A recorded call-difference use site becomes:

- cloned original operands
- plus a synthetic function-ref `local.get`
- rebuilt as `call_ref`
- preserving the original `call->isReturn` flag

That is why the all-features tests can show `return_call_ref` in the shared helper.

### 3. Old non-param locals

If a cloned `LocalGet` or `LocalSet` refers to a non-param local from the primary body, Binaryen shifts its index upward by the number of synthetic params inserted.

This is a core correctness invariant.
Without it, appending synthetic params would silently renumber the old local space.

## The helper's new param types

`ParamInfo::getValueType(...)` proves the exact synthetic-param typing rule:

- literal diffs use the literal type
- call-target diffs use a non-nullable ref type built from the callee heap type

So the pass is not passing symbolic names around.
It is passing real function refs for the call-target family.

## Stage 5: thunk replacement keeps the original function identities

`replaceWithThunk(...)` does not move public identity to the helper.
Instead:

- the helper gets the generated `byn$mgfn-shared$...` name
- each original function body is overwritten with a wrapper call into the helper

That means exports and direct users of the original names still go through the original functions.

## Exact thunk argument order

Each thunk forwards:

1. all original params first, via `local.get`
2. then the per-function synthetic payloads

Those payloads come from `ParamInfo::lowerToExpression(...)`:

- literals become `Const`
- callee-name payloads become `ref.func`

## Tail-call preservation is split across helper creation and thunk replacement

Two different source facts combine here:

- helper cloning preserves `call->isReturn` when rebuilding parameterized calls as `call_ref`
- thunk replacement chooses plain `call` versus `return_call` based on `module->features.hasTailCall()`

So a future port must preserve both sides if it wants to match the official `return_call` / `return_call_ref` test families.

## Thunks clear old locals

When Binaryen overwrites an original function with its new wrapper body, it also clears `target->vars`.

That matters because the thunk no longer needs the original local declarations.

## Same-shape examples that still do not merge

These mechanics explain several beginner-surprising bailouts.

### Same hash, different operand structure

If two calls differ by callee but also differ in argument expression structure, they can land in the same coarse hash family but still fail the real equivalence-class check.

### Same wrapper shape, different callee signatures

Even if only the callee name differs, Binaryen rejects the merge if there is no single safe function-ref param type for the helper.

### Same wrapper shape, no call indirection support

Without reference types plus GC, the call-target family is not even considered parameterizable.

## Porting checklist

A faithful port should preserve all of these exact mechanics:

- early import/signature/local-count rejection
- same-hash versus same-class distinction
- hashing that still includes call operands and `isReturn`
- lockstep DFS parameter derivation over all class members
- exact diff-vector reuse
- feature-gated call-target parameterization
- helper cloning through selective replacement
- non-param local-index shifting after synthetic params are appended
- original-name-preserving thunk replacement
- tail-call preservation on both helper and thunk sides

## Easy-to-miss summary

If someone remembers only one sentence from this page, it should be this:

> Binaryen `merge-similar-functions` is not just “helper plus thunks”; it is a specific hash-then-classify-then-lockstep-diff-derive-then-clone-and-shift-locals algorithm whose exact mechanics are part of the real pass contract.

## Sources

- [`../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md`](../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md)
- [`../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md`](../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md`](../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeSimilarFunctions.cpp>
