# Binaryen `legalize-and-prune-js-interface` research

- Date: 2026-04-21
- Researcher: OpenAI Codex
- Scope: justify and document Binaryen's public `legalize-and-prune-js-interface` pass as a new upstream-only living dossier after the tracker ran out of obvious `none` targets and the new plain `legalize-js-interface` dossier exposed a still-undocumented sibling gap.

## Why this pass, why now

The recursive Binaryen wiki campaign currently has no obvious remaining tracker entries with wiki status `none`.
That means another pass is only justified if neighboring living docs already depend on teaching it precisely.

`legalize-and-prune-js-interface` meets that bar.
The immediately previous thread added a canonical dossier for plain `legalize-js-interface`, but that folder now repeatedly has to say “the sibling prune pass is separate” without giving the sibling its own durable home.
Without a dedicated page, it is too easy to blur together:

- plain `legalize-js-interface`, which only rewrites `i64`-bearing function boundaries using wrappers and temp-ret helpers, and
- `legalize-and-prune-js-interface`, which first runs that same `i64` legalization and then **removes exports or synthesizes stub bodies** for boundary items that still expose JS-hostile features such as SIMD, multivalue results, exception handling, or stack switching.

`agent-todo.md` has **no dedicated `legalize-and-prune-js-interface` slice**.
This is therefore a tracker-expansion and teaching task, not a direct implementation handoff.

## Sources consulted

Official Binaryen `version_129` sources:

- `src/passes/LegalizeJSInterface.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/legalize-and-prune-js-interface.wast`
- the neighboring plain-family lit files already used by the existing `legalize-js-interface` dossier, especially `legalize-js-interface-exported-helpers.wast`

Official current-`main` spot-check sources:

- `src/passes/LegalizeJSInterface.cpp`
- `test/lit/passes/legalize-and-prune-js-interface.wast`

Local repo context:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/*`
- `agent-todo.md`
- `src/passes/optimize.mbt`

## High-level conclusion

`legalize-and-prune-js-interface` is **not** a separate legalization algorithm.
It is a **subclass wrapper around plain `legalize-js-interface` plus a prune phase**.
In reviewed `version_129`, its real contract is:

1. run ordinary JS-boundary `i64` legalization first
2. scan imported or exported functions that are still on the JS boundary
3. treat them as still illegal when their signatures expose feature-bearing types with SIMD, multivalue results, exception handling, or stack switching
4. for imports, strip import status and synthesize a trivial body
5. for exports, remove the export
6. `ReFinalize()` because visible function identity and exact function-ref types may have changed
7. remove exported globals whose types are still illegal for JS

That means the pass is best taught as:

- **plain JS `i64` legalization first**
- **boundary sanitization second**
- not as a generic feature lowering pass
- not as a semantic-preserving fallback for unsupported JS interop

## Public registration and family split

`pass.cpp` registers `legalize-and-prune-js-interface` as its own public pass name with its own help text:

- `legalize-and-prune-js-interface`
  - help text: legalizes the import/export boundary and prunes when needed

The implementation file makes the family relationship explicit:

- `LegalizeAndPruneJSInterface` inherits from `LegalizeJSInterface`
- `run(Module*)` calls `LegalizeJSInterface::run(module)` first
- then it calls `prune(module)`

So this is a real public sibling with one extra phase, not a mere alias.

## Actual implementation structure

Almost everything still lives in `src/passes/LegalizeJSInterface.cpp`.
For the prune sibling, the important extra code is concentrated in:

- the `LegalizeAndPruneJSInterface` subclass
- `prune(Module*)`
- `bool isIllegal(Type type)` in the subclass
- the factory `createLegalizeAndPruneJSInterfacePass()`

There is no second large pruning implementation file hidden elsewhere.
That is a key beginner takeaway: the sibling is tiny in code, but its behavioral distinction is important.

## Exact prune legality rule

The subclass legality rule is **not** the same as the base pass's `i64` test.
The base pass only looks for `i64` params or an `i64` result.
The prune sibling instead asks whether a boundary-visible type's feature set contains:

- SIMD
- multivalue
- exception handling
- stack switching

For functions there is one subtle exception:

- params may be multivalue in aggregate because the code iterates each param type separately
- results may **not** be multivalue, because the code checks `sig.results` as a whole before iterating params

That matches the source comment: multivalue params are tolerated, multivalue results are not.

## Function pruning algorithm

The pruning walk first builds a map from internal function name to exported public name.
Then it iterates all functions and only cares about functions that are still on the boundary:

- imported
- exported
- or both

For each such function:

1. compute `imported` and `exported`
2. read the signature
3. decide whether the boundary is still illegal under the subclass feature test
4. if not illegal, leave it alone
5. if illegal and imported, replace the import with a trivial defined function
6. if illegal and exported, remove the export

### Import replacement matrix

When pruning an illegal import, Binaryen deliberately does **not** try to preserve semantics.
It removes the import identity by clearing `module` and `base`, makes the type exact, and synthesizes one of three bodies:

- result `none` -> `nop`
- defaultable result -> zero/default literal via `Literal::makeZeros(...)`
- nondefaultable result -> `unreachable`

This is a practical “make the module JS-boundary-legal enough to continue” fallback, not a faithful host emulation layer.

## Why `ReFinalize()` happens in the middle

After pruning imported or exported functions, Binaryen runs:

- `ReFinalize().run(...)`
- `ReFinalize().runOnModuleCode(...)`

The source comment calls out `RefFunc` types explicitly.
That matters because pruning can turn an import into an internal function body, which can change exactness and related type facts even when the textual function name survives.

So a good mental model is:

- function pruning may change function identity/type facts visible to `ref.func`
- therefore Binaryen refinalizes before it does the later global-export cleanup

## Global export pruning

Only after function pruning and refinalization does the pass scan exports again for globals.
For exported globals:

- if the global's type still exposes illegal JS-boundary features, Binaryen removes the export
- the global itself stays in the module

So global pruning is narrower than function-import pruning:

- illegal imported functions get stub bodies
- illegal exported functions lose exports
- illegal exported globals lose exports
- globals are not rewritten into zero stubs or removed from the module entirely here

## Important WAT / IR shapes

The dedicated lit file proves several teaching-important shapes.

### 1. Ordinary `i64` legalization still happens

The sibling still creates the same family of wrappers as the plain pass:

- `legalimport$...`
- `legalfunc$...`
- `legalstub$...`
- temp-ret helper calls

So the prune pass does not replace the base algorithm; it extends it.

### 2. Illegal imports become ordinary defined functions

Examples in the lit file show imports with:

- `v128` results
- multivalue results
- `v128` params

becoming normal internal functions with trivial bodies such as:

- `v128.const 0 ...`
- `tuple.make ...` of zero/default values
- `nop`
- `unreachable`

### 3. An import can be both stubbed and unexported

The lit file includes an imported function that is also exported.
After pruning, Binaryen:

- turns it into a defined function body
- removes the export

So “imported” and “exported” are handled independently, not as mutually exclusive categories.

### 4. Defaultability decides zero literal vs trap

The lit file's `imported-v128-defaultable` and `imported-v128-nondefaultable` examples make the result policy concrete:

- defaultable illegal results become zero/default literals
- nondefaultable illegal results become `unreachable`

### 5. Illegal global exports vanish but legal ones remain

The final module in the lit file proves the global rule directly:

- export of a `v128` global disappears
- export of an `i32` global remains

## Relationship to plain `legalize-js-interface`

The sibling split is now crisp:

- plain `legalize-js-interface`
  - only legalizes `i64` function boundaries
  - never stubs SIMD/multivalue/EH/stack-switch imports just because they are JS-hostile
- `legalize-and-prune-js-interface`
  - runs the plain pass first
  - then sanitizes whatever boundary items are still illegal for JS

That means the sibling should not be filed away as merely “the plain pass, but more aggressive.”
Its second phase changes the semantic story at the boundary from **adapt** to **adapt where possible, otherwise stub or hide**.

## Current-`main` drift check

A direct current-`main` spot check found no checked-surface drift in:

- `src/passes/LegalizeJSInterface.cpp`
- `test/lit/passes/legalize-and-prune-js-interface.wast`

So the reviewed `version_129` contract still matches current upstream on the exact surfaces this dossier teaches.

## Documentation implications for Starshine

This pass is currently **upstream-only** in this repo.
It is not in `src/passes/optimize.mbt`, not in the canonical no-DWARF path page, and not represented by a dedicated `agent-todo.md` slice.

But it still deserves a living dossier because:

- the new plain `legalize-js-interface` dossier already depends on keeping the sibling split explicit
- `i64-to-i32-lowering` teaching is cleaner when the earlier JS-boundary pass family is split into plain-vs-prune variants instead of treated as one blob
- the prune sibling's import-stub matrix is non-obvious and easy to misremember without a page

## Recommended living pages

Create or maintain these living pages under `docs/wiki/binaryen/passes/legalize-and-prune-js-interface/`:

- `index.md`
  - what the pass is, why it exists, and how it differs from plain legalization
- `binaryen-strategy.md`
  - exact two-phase algorithm and legality predicates
- `implementation-structure-and-tests.md`
  - owner-file and lit-proof map
- `prune-boundary-matrix.md`
  - import/export/global and defaultable/nondefaultable behavior matrix
- `wat-shapes.md`
  - beginner-friendly before/after examples

## Sources

- Binaryen `version_129`:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface-exported-helpers.wast>
- Binaryen current `main` spot checks:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LegalizeJSInterface.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-and-prune-js-interface.wast>
- Local repo context:
  - [`../../../../docs/README.md`](../../../../docs/README.md)
  - [`../../binaryen/passes/tracker.md`](../../binaryen/passes/tracker.md)
  - [`../../binaryen/passes/index.md`](../../binaryen/passes/index.md)
  - [`../../binaryen/no-dwarf-default-optimize-path.md`](../../binaryen/no-dwarf-default-optimize-path.md)
  - [`../../binaryen/passes/legalize-js-interface/index.md`](../../binaryen/passes/legalize-js-interface/index.md)
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
  - [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
