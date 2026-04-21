# Binaryen `merge-similar-functions` research

Date: 2026-04-21
Status: archived research backing a new living pass dossier

## Scope and selection note

This thread had to continue the Binaryen pass wiki campaign after the original no-DWARF queue, the saved generated-artifact `-O4z` skipped-slot queue, and the first widened upstream-only registry wave were already dossier-covered.

I therefore re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

and then explicitly widened the tracker again for **`merge-similar-functions`**.

Why this pass is a justified expansion target:

1. it is already named in the local boundary-only registry in `src/passes/optimize.mbt`
2. it is already named in the Batch 4 registry map in `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
3. official Binaryen `version_129` has a real standalone implementation, real pass registration, and dedicated lit tests
4. it sits right beside already-documented late module neighbors like `duplicate-function-elimination`, `duplicate-import-elimination`, and `simplify-globals*`
5. unlike some other expansion candidates, it is part of Binaryen's **size-focused global post-pass scheduler** when `shrinkLevel >= 2`, so it is relevant to future `-Oz` / `-O4z` style work even though it is not in the repo's current no-DWARF `-O` / `-Os` path page

## Backlog status

`agent-todo.md` currently has **no dedicated `merge-similar-functions` slice**.

That absence matters because the pass sounds simple, but the actual Binaryen contract is not “merge duplicates again.” It is a separate whole-module parameterization pass with its own legality, profitability, and feature-gated call-indirection rules.

## Main conclusion

Binaryen `merge-similar-functions` is a **late whole-module size pass** that:

- groups functions by a hash that ignores certain constant differences
- splits those groups into exact “same shape except constants / direct callees” equivalence classes
- derives a set of synthetic extra parameters that explain the differences between the functions in one class
- clones one primary function into a new shared helper where those differing constants become `local.get` uses
- replaces every original function in the class with a small thunk that forwards original params plus the per-function constant payloads
- skips the class unless the result appears smaller and stays under Binaryen's synthetic parameter limit

A good beginner summary is:

> this is a size-driven “function parameterization” pass, not a duplicate-function pass and not a generic whole-program inliner.

## Scheduler placement

Official Binaryen `version_129` registers the pass in `src/passes/pass.cpp` under the public name `merge-similar-functions`.

The most important scheduler fact is in `PassRunner::addDefaultGlobalOptimizationPostPasses()`:

- `duplicate-function-elimination`
- `duplicate-import-elimination`
- **`merge-similar-functions` when `shrinkLevel >= 2`**
- `simplify-globals-optimizing` or `simplify-globals`
- `remove-unused-module-elements`
- `string-gathering` / `reorder-globals` / `directize`

So the pass is:

- real and public upstream: **yes**
- present in local registry: **yes**
- active in Starshine today: **no**
- part of the current no-DWARF `-O` / `-Os` page: **no**
- part of Binaryen's size-oriented late module cleanup story: **yes**

Inference: it is a better fit for future shrink / `-Oz` / `-O4z` parity work than for the repo's currently documented no-DWARF `-O` / `-Os` path.

## Source inventory reviewed

### Core implementation

- `src/passes/MergeSimilarFunctions.cpp`
- `src/passes/pass.cpp`
- `src/passes/pass.h`

### Important helper headers surfaced directly by the pass

- `src/ir/hashed.h`
- `src/ir/manipulation.h`
- `src/ir/module-utils.h`
- `src/ir/names.h`
- `src/wasm-limits.h`
- `src/wasm.h`

### Official tests

- `test/lit/passes/merge-similar-functions.wast`
- `test/lit/passes/merge-similar-functions_all-features.wast`
- `test/lit/passes/merge-similar-functions_types.wast`
- `test/lit/passes/merge-similar-functions-param-limit.wast`

### Current-main spot check

- `main/src/passes/MergeSimilarFunctions.cpp`

The checked current-main implementation file matched `version_129` byte-for-byte on the reviewed surface.

## What the pass actually matches

The pass does **not** search for arbitrary semantic equivalence.

It first rejects obvious non-candidates:

- imported functions
- different function types
- different local counts

Then it compares bodies structurally while allowing only a very small family of differences.

### Allowed differences

1. **`const` immediate values**
   - the instruction kind and result type must still match
   - the literal payload may differ

2. **direct `call` targets**, but only when call indirection is enabled
   - the module must have reference types **and** GC enabled
   - the two direct callees must themselves have the same function type
   - the call operands must still be structurally equivalent under the same comparer

Everything else must match exactly in structure and types.

That means the real pass surface is narrower than the name suggests.

## Core algorithm

### Phase 1: hash functions while ignoring some differences

`collectEquivalentClasses(...)` builds a hash per defined function using `FunctionHasher`.

The custom hasher ignores:

- the immediate payload of `Const`
- the direct callee name of `Call`

but still includes:

- operand structure
- call `isReturn`
- everything else in the ordinary expression shape

This is a **cheap grouping pre-pass**, not the final legality proof.

### Phase 2: split hash groups into real equivalence classes

Functions that collide under the “ignore constants and direct callees” hash are then compared pairwise using `ExpressionAnalyzer::flexibleEqual(...)` with a custom comparer.

The comparer requires:

- same node id
- same node type
- same expression result type
- same call operand counts
- same callee signature when the only difference is the call target

If two functions have the same coarse hash but not the same real pattern, they end up in different `EquivalentClass` buckets.

### Phase 3: derive synthetic parameters

For each equivalence class, `deriveParams(...)` walks the primary function and every sibling in lockstep.

Whenever it sees a differing:

- `Const`, or
- eligible `Call` target

it records a `ParamInfo`.

A `ParamInfo` stores:

- the actual per-function values (`Literals` or callee `Name`s)
- every use site in the primary function that should become a `local.get`

Important detail: if two different sites share the same per-function value vector, Binaryen **reuses one synthetic parameter**.

Example:

- function A uses `42` twice
- function B uses `43` twice
- the merged function gets **one** extra param, not two

This reuse behavior is one of the easiest things to miss if you only read the pass name.

### Phase 4: check profitability and hard limits

Before rewriting, Binaryen checks `hasMergeBenefit(...)`.

Hard safety / encoding gate:

- original params + synthetic params must stay `<= MaxSyntheticFunctionParams`
- `wasm-limits.h` defines `MaxSyntheticFunctionParams = 255`

Profitability model:

- estimate removed body instructions from deleting duplicate large bodies
- estimate added instructions for thunks and shared entry overhead
- estimate extra locals / code-section / function-section costs
- only merge when the positive score beats the negative score

So tiny functions with tiny differences intentionally stay untouched.

### Phase 5: create the shared helper

`createShared(...)`:

- creates a fresh valid function name using `Names::getValidFunctionName(...)`
- appends synthetic params after the original params
- clones the primary body with `ExpressionManipulator::flexibleCopy(...)`
- rewrites each parameterized site to a `local.get` of the new synthetic param
- if the parameterized site was a direct `call`, rebuilds it as `call_ref` using the synthetic function-ref param
- renumbers non-param locals so original vars move past the new synthetic params

This local renumbering is a crucial invariant.

Without it, the newly inserted params would shift the local index space and silently corrupt accesses.

### Phase 6: replace originals with thunks

Each original function becomes a thin wrapper that:

- forwards all original params via `local.get`
- materializes the per-function constant payloads or `ref.func` payloads
- calls the shared helper
- uses `return_call` if tail calls are enabled in the module and the original call shape was a returning one

The original bodies disappear; the function names stay as the public stable entrypoints.

## Important helper dependencies

### `FunctionHasher` from `ir/hashed.h`

This provides the coarse first-stage grouping so the pass does not do pairwise body comparisons across the entire module.

### `ExpressionAnalyzer::flexibleEqual`

This provides the real structural comparison with a narrowly customized equality relation.

### `ExpressionManipulator::flexibleCopy`

This is how the pass clones the primary function while selectively substituting synthetic param reads and reindexing locals.

### `ModuleUtils::iterDefinedFunctions`

This keeps the scan restricted to defined functions instead of imports.

### `Names::getValidFunctionName`

This guarantees the synthetic shared helper gets a legal non-conflicting function name like `byn$mgfn-shared$...`.

### `MaxSyntheticFunctionParams`

This is the hard stop that prevents Binaryen from creating illegal or overly wide synthetic signatures.

## Key positive shapes from tests

### 1. Large constant-only differences

The base lit file shows the simplest positive family:

- several large functions are identical except for one `i32.const`
- Binaryen creates one shared helper with an extra `i32` param
- each original becomes a tiny thunk passing its literal
- tiny one-instruction functions are left alone because they do not pass the benefit check

### 2. Multiple identical difference-vectors reuse one synthetic param

`merge-similar-functions.wast` explicitly checks the “use 42 twice / use 43 twice” family.

The merged helper uses a single extra param twice instead of adding one synthetic param per site.

### 3. Original params plus synthetic params plus local-offset repair

The tests also cover functions that already have params and extra locals.

The shared helper keeps original params first, appends synthetic params, then shifts original non-param locals upward so old local variables still refer to the correct slots.

### 4. Different direct callees become function-ref params

When reference types and GC are enabled, two functions that differ only by which same-signature callee they call can be merged.

The shared helper then uses:

- `ref.func` thunk arguments
- a function-ref synthetic param
- `call_ref` or `return_call_ref`

This is the pass's most non-obvious feature.

### 5. Tail-call preserving rewrite

`merge-similar-functions_all-features.wast` covers the `return_call` family.

When the original functions are returning-tail-call wrappers, the shared helper and thunks preserve that tail-call style instead of degrading everything to plain call + return.

## Key bailout shapes from tests and source

### 1. Imports never merge

The source immediately rejects imported functions.

### 2. Different function signatures never merge

The pass requires the original functions themselves to have identical function types.

### 3. Different local counts never merge

Even if the bodies look very similar, differing local layouts are rejected early.

### 4. Different callee signatures do not qualify for call-target parameterization

`merge-similar-functions_types.wast` shows the important negative case:

- bodies differ only by direct callees
- but those callees have different function types
- so there is no single function-ref parameter type to use safely
- therefore the wrapper functions remain separate

### 5. Some subtype-related call families still do not merge

`merge-similar-functions_all-features.wast` shows that even when the same concrete operand can flow to two different callees, Binaryen refuses to merge if the callee parameter-type relationship does not provide one safe synthetic parameter type for the call-indirection rewrite.

### 6. Classes above the synthetic parameter limit stay untouched

`merge-similar-functions-param-limit.wast` checks the hard boundary:

- 255 params is still allowed
- 256 is not

### 7. Small functions may fail the benefit check

The basic lit file keeps very small constant-only wrappers unchanged to prove that the pass is size-sensitive, not just legality-sensitive.

## What the pass is not

It is **not**:

- `duplicate-function-elimination`
  - DFE merges truly duplicate bodies
  - merge-similar-functions merges near-duplicates by inventing params and thunks
- inlining
  - it does not inline callees into callers
- generic whole-program devirtualization
  - it only parameterizes direct call targets inside already-similar wrappers
- generic CFG-aware function outlining
  - it clones one whole primary function body, not arbitrary regions
- a semantic equivalence prover
  - it works on a narrow source-backed structural pattern

## Easy-to-miss implementation details

### The pass only parameterizes `Call`, not every function reference use

The reviewed source handles direct `Call` differences by turning the shared copy into `call_ref`.
It is not a generic “parameterize any function reference constant anywhere” pass.

### Calls are only parameterized when both reference types and GC are enabled

The helper `isCallIndirectionEnabled(...)` requires both features.
So the same module may merge constant-only functions but still refuse call-target differences unless those feature gates are on.

### The shared function is cloned from one primary body

Binaryen does not synthesize a brand-new abstract body. It picks one primary function, clones it, and swaps just the parameterized nodes.

### Thunks keep original function names stable

The public symbol identity stays on the original functions; the synthetic helper gets the `byn$mgfn-shared$...` internal-ish name.

### Profitability is deliberately approximate

The score uses measured expression size and small constant weights, not byte-perfect wasm encoding simulation.
A future Starshine port should preserve the conservative intent, not necessarily every literal constant in the heuristic, unless parity demands it.

## Current-main drift

A spot check comparing `version_129` and `main` for `src/passes/MergeSimilarFunctions.cpp` found no diff in the implementation file.

That does **not** prove every neighboring helper is identical on trunk, but it does support using `version_129` as the stable oracle for this dossier.

## Implications for a future Starshine port

A faithful port must preserve:

- whole-module late-pass scheduling, not hot single-function scheduling
- the two-step hash-then-structural-compare design
- the narrow allowed-difference surface (`Const`, and some direct `Call` targets)
- feature-gated call-target parameterization
- parameter reuse for repeated identical difference-vectors
- local-index offset repair after inserting synthetic params
- thunk replacement of originals instead of public-name reassignment
- the hard synthetic-param limit
- a profitability gate strong enough to leave tiny functions alone

## Open questions and uncertainty

I did **not** find evidence in the reviewed sources that this pass is in the repo's current canonical no-DWARF `-O` / `-Os` path. The official scheduler evidence instead places it in the late global post-pass phase when `shrinkLevel >= 2`.

Inference: for Starshine planning, this pass should currently be taught as a **shrink-family late module pass**, not as an immediate no-DWARF `-O` / `-Os` blocker.

## Sources

### Repo sources consulted

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

### Official Binaryen sources

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeSimilarFunctions.cpp>
