# Binaryen `merge-similar-functions` mechanics follow-up

Date: 2026-04-21
Status: archived research backing a living-dossier follow-up

## Scope and why this follow-up was justified

This thread had to continue the recursive Binaryen pass wiki campaign after the tracker had already been heavily filled.

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/merge-similar-functions/` folder

and then chose **`merge-similar-functions`** as an explicitly justified major-gap fallback.

Why this still counted as a real gap even though the folder already had a solid dossier:

1. the folder already explained the pass at a high level, but it still lacked one dedicated source-confirmed page for the **exact core mechanics**
2. the most port-critical details were still spread thinly across the strategy page and tests instead of being taught as one coherent algorithm
3. those details are easy to get wrong in a future Starshine port:
   - same-hash versus same-class
   - exact early eligibility filters
   - lockstep parameter derivation
   - diff-vector reuse
   - local-index shifting after synthetic params are inserted
   - thunk replacement preserving original public names and tail-call style
4. `agent-todo.md` still has **no dedicated `merge-similar-functions` slice**, so the wiki remains the main durable place to preserve these implementation facts

In short: the existing dossier was already good, but it still did not isolate the algorithmic heart of the pass well enough for a future port.

## Backlog status

`agent-todo.md` still has **no dedicated `merge-similar-functions` slice**.

That absence remains important because this pass is easy to mis-port as “parameterize every differing constant-like site,” while the actual Binaryen contract is much narrower and more mechanical than that.

## Sources reviewed for this follow-up

### Core implementation

- `src/passes/MergeSimilarFunctions.cpp`
- `src/passes/pass.cpp`

### Tests

- `test/lit/passes/merge-similar-functions.wast`
- `test/lit/passes/merge-similar-functions_types.wast`
- `test/lit/passes/merge-similar-functions_all-features.wast`
- `test/lit/passes/merge-similar-functions-param-limit.wast`

### Freshness check

- `main/src/passes/MergeSimilarFunctions.cpp`

A narrow current-main diff check found **no diff** between upstream `main` and `version_129` for `src/passes/MergeSimilarFunctions.cpp`.

Inference: for the mechanics covered here, `version_129` is still a stable oracle.

## Main follow-up conclusion

The real Binaryen `version_129` mechanics are best taught as a six-part algorithm:

1. reject obviously incompatible function pairs early
2. hash functions while ignoring only constant payloads and direct callee names
3. split same-hash buckets into true equivalence classes using exact structural comparison
4. walk the primary body and every sibling body in lockstep DFS order to derive reusable diff-vectors
5. clone the primary body into one shared helper while rewriting parameterized sites and shifting non-param locals upward
6. replace every original function body with a thunk that forwards original params plus the per-function payloads

That sounds similar to the older summary, but the exact mechanics matter.

## Exact early eligibility filters

Before considering a merge, Binaryen requires candidate functions to satisfy all of these:

- not imported
- same top-level function type
- same `getNumVars()` count

Those checks happen before the pass even gets to the more interesting flexible-equality logic.

This matters because a future port can be wrong in two opposite directions:

- too broad: trying to merge same-shape functions whose local layouts differ
- too narrow: assuming full body equality is needed before hashing

## Same hash is not the same thing as same equivalence class

This is one of the easiest things to miss.

### Hash stage

`collectEquivalentClasses(...)` builds hashes with a custom `FunctionHasher` configuration that ignores:

- `Const` immediates
- direct `Call` targets

But the custom hashing still keeps important structure:

- ordinary instruction ids and structure
- recursively hashed call operands
- `call->isReturn`

So the hash is not “ignore every call detail.”
It is only “ignore the direct callee name, but still care about argument structure and return-call shape.”

### Equality stage

After that, each same-hash bucket is split again with `areInEquvalentClass(...)` and `ExpressionAnalyzer::flexibleEqual(...)`.

The custom comparer still requires:

- identical expression ids
- identical expression result types
- equal call operand counts
- equal call result types
- equal callee function signatures when the direct callee names differ
- recursively equal call operands under the same comparer
- equal literal types for differing `Const` nodes

So Binaryen's real rule is:

> same hash only means “worth checking further”; real mergeability is decided by a stricter second pass.

The source comment `// Same hash but different instruction pattern.` is the direct proof that this distinction is intentional, not an incidental implementation detail.

## The exact parameter-derivation walk

The most important source-confirmed mechanics live in `EquivalentClass::deriveParams(...)`.

### Lockstep DFS over the primary and sibling bodies

Binaryen defines an internal `DeepValueIterator` that performs a DFS over `Expression**` slots, starting from the root body pointer.

The pass then walks:

- one iterator over the primary function body
- one parallel iterator per sibling function body

That means parameter derivation is not a post-hoc “search for constants.”
It is a lockstep structural walk that assumes the same traversal order because the equivalence-class check already proved the bodies match everywhere except at allowed-difference sites.

### What can become a synthetic param

At each primary-site visit, Binaryen only tries to derive a diff-vector for two families:

1. `Const`
2. `Call`, but only when `isCallIndirectionEnabled(...)` is true

Everything else is skipped after asserting that sibling iterators are currently sitting on the same expression kind.

### What `isCallIndirectionEnabled(...)` really means

The helper returns true only when the module has:

- reference types
- GC

So even if two wrappers differ only by direct callee name, the pass will not parameterize those calls unless the feature surface can express a function-ref parameter plus `call_ref`.

### “All same values” means no new param

Even at a `Const` or `Call` site, Binaryen does not automatically create a synthetic param.
If every function in the class has the same value there, the site is skipped.

That is why the three-function family `42, 42, 43` still produces a single reusable diff-vector rather than one parameter per function.

### Diff-vector reuse is exact equality on the full per-function vector

When a site does differ, the pass builds one `ConstDiff`:

- either `Literals`
- or `std::vector<Name>` for callee names

Then it searches existing `params` for `param.values == diff`.
If found, it appends the new use site to that existing param's `uses` list.
If not found, it creates a fresh `ParamInfo`.

This proves the real reuse rule is:

- not “same literal type”
- not “same source position kind”
- but exact equality of the **entire per-function difference vector**

That is the source-backed reason one helper param can feed multiple use sites.

## Exact helper-construction mechanics

`EquivalentClass::createShared(...)` is the clearest proof of how Binaryen turns that parameter data into real IR.

### Signature shape

Binaryen computes two key boundaries:

- `extraParamBase = primaryFunction->getNumParams()`
- `newVarBase = primaryFunction->getNumParams() + params.size()`

Then it builds the shared signature as:

1. all original params first
2. all synthetic params appended after them

Each synthetic param type comes from `ParamInfo::getValueType(...)`:

- literal diffs use the literal type
- call-target diffs use a non-nullable reference to the callee heap type

### Clone-and-rewrite path

The shared body is cloned with `ExpressionManipulator::flexibleCopy(...)` and a custom copier.

The custom copier does three essential jobs.

#### 1. Rewrite parameterized const sites to `local.get`

If a cloned expression is one of the recorded use sites for synthetic param `k`, Binaryen replaces it with:

- `local.get(extraParamBase + k, paramType)`

#### 2. Rewrite parameterized direct calls to `call_ref`

If the recorded site is a `Call`, Binaryen:

- clones the original call operands recursively
- creates the same synthetic-param `local.get`
- rebuilds the call as `builder.makeCallRef(...)`
- preserves the original `call->isReturn` flag

So the shared helper is not parameterizing “a callee name string.”
It is parameterizing a real function reference and then emitting `call_ref` or `return_call_ref` in the cloned helper body.

#### 3. Shift non-param locals upward

If a cloned `LocalGet` or `LocalSet` refers to a non-param local from the primary function, Binaryen rewrites its index to:

- `newVarBase + (oldIndex - primaryFunction->getNumParams())`

This is one of the most critical correctness details in the entire pass.
Without it, appending synthetic params would silently renumber the original local space and corrupt behavior.

### Helper type exactness

The new helper is created as:

- `Type(sig, NonNullable, Exact)`

That is a small but real source fact worth preserving in the living dossier.

## Exact thunk-replacement mechanics

`EquivalentClass::replaceWithThunk(...)` is simpler than helper creation, but it encodes two important facts.

### Original param forwarding order

Each thunk first forwards all original params as `local.get(i, targetParams[i])` in original order.

Then it appends the synthetic payload expressions for that specific function:

- `Const` payloads become literal expressions
- call-target payloads become `ref.func` expressions

### Original function identities survive

Binaryen does **not** rename the original functions into helpers.
Instead, the generated helper gets the new `byn$mgfn-shared$...` name, and each original function is overwritten with a tiny wrapper body.

That keeps:

- exports
- direct users of the original function name
- module identity anchored on the original functions

### Tail-call style preservation happens at thunk replacement time

`merge(...)` passes `module->features.hasTailCall()` into `replaceWithThunk(...)` as the `isReturn` flag.
That means thunk calls become `return_call` when the feature is enabled, and plain `call` otherwise.

Together with the `call->isReturn` preservation inside helper creation, this is why the official all-features tests can show both:

- `return_call` in the thunks
- `return_call_ref` in the shared helper

### Old locals are removed from the thunk

Binaryen clears `target->vars` before storing the new call body.
That is the direct proof that thunks do not keep now-unused original local declarations around.

## Exact profitability heuristic, not just a vibe

The existing dossier already explained that the pass is profitability-gated.
This follow-up confirmed the exact formula in `hasMergeBenefit(...)`.

Hard gate first:

- `params.size() + primaryFunction->getNumParams() > MaxSyntheticFunctionParams`
- reject the class if true

Then Binaryen uses these exact weights:

- `INSTR_WEIGHT = 1`
- `CODE_SEC_LOCALS_WEIGHT = 1`
- `CODE_SEC_ENTRY_WEIGHT = 2`
- `FUNC_SEC_ENTRY_WEIGHT = 2`

and compares:

- positive score: removed duplicated body instructions
- negative score: thunk forwarding instructions plus merged-helper local/code-entry overhead plus thunk function-entry overhead

This remains a deliberately approximate size model, but it is much more concrete than “small functions may lose.”

## What the tests prove about these mechanics

### `merge-similar-functions.wast`

This file proves:

- large constant wrappers merge
- small constant wrappers can stay separate
- repeated diff-vectors reuse one synthetic param
- non-param local indices are shifted correctly after extra params are appended
- direct-callee differences with same signatures become `ref.func` thunk payloads and `call_ref` in the shared helper

### `merge-similar-functions_types.wast`

This file proves both sides of the call-target rule:

- same structural wrapper bodies with different callee signatures do **not** merge
- same structural wrapper bodies with the same callee signature can merge
- tail-call style can be preserved through `return_call` plus `call_ref`/`return_call_ref`

### `merge-similar-functions_all-features.wast`

This file proves the subtler type barrier:

- even when one concrete operand can flow to two different callees, Binaryen still refuses to merge if there is no single safe function-ref parameter type for the helper

### `merge-similar-functions-param-limit.wast`

This file proves the hard signature-width boundary is real public behavior:

- 255 total params is allowed
- 256 is not

## Easy-to-miss corrections this follow-up adds to the dossier

### 1. The hash is narrower than the equality proof

It ignores const payloads and direct callee names, but still keeps operand structure and `isReturn`.

### 2. Parameter derivation is a lockstep DFS, not an independent constant scan

That is why same-shape proof comes first.

### 3. Parameter reuse is keyed by exact per-function diff-vector equality

It is not a looser “same sort of difference” heuristic.

### 4. Helper construction must shift all old non-param local indices upward

This is a real core invariant, not incidental plumbing.

### 5. Tail-call preservation is split across two places

- thunk replacement uses module tail-call support to choose `call` vs `return_call`
- helper cloning preserves `call->isReturn` when rebuilding parameterized call sites as `call_ref`

### 6. Original public function names stay on the thunks

The synthetic helper gets the generated name.

## What a future Starshine port must preserve

A faithful port should preserve all of the following as first-class contract, not optional cleanup:

- early import / type / local-count rejection
- same-hash versus same-equivalence-class separation
- hashing that still includes operand structure and return-call shape
- lockstep DFS parameter derivation over the primary and sibling bodies
- exact diff-vector reuse
- feature-gated call-target parameterization
- helper cloning through selective replacement rather than fresh synthesis
- non-param local-index shifting after extra params are inserted
- original-name-preserving thunk replacement
- tail-call preservation on both thunk and helper sides
- the hard `255`-param limit
- the approximate but real profitability formula

## Living-doc updates this follow-up should drive

This follow-up should be filed back into the `merge-similar-functions` folder as a dedicated mechanics page, plus landing/index wording that makes clear the folder now source-confirms:

- the exact hash-versus-class split
- the `DeepValueIterator` diff-derivation walk
- exact diff-vector reuse
- shared-helper local-index shifting
- and thunk replacement preserving original function identities and tail-call style

## Sources

### Repo sources consulted

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/index.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/profitability-indirection-and-type-barriers.md`
- `docs/wiki/binaryen/passes/merge-similar-functions/wat-shapes.md`

### Official Binaryen sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeSimilarFunctions.cpp>
