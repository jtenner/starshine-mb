# Binaryen `legalize-js-interface` research

- Date: 2026-04-21
- Researcher: OpenAI Codex
- Scope: justify and document Binaryen's public `legalize-js-interface` pass as a new upstream-only living dossier after the tracker ran out of obvious `none` targets.

## Why this pass, why now

The recursive Binaryen wiki campaign currently has no obvious remaining tracker entries with wiki status `none`.
That means a new pass is only justified if neighboring living docs already depend on teaching it precisely.

`legalize-js-interface` meets that bar.
The existing `i64-to-i32-lowering` dossier already says its imported-direct-call retargeting assumes `legalize-js-interface` has already run, but the wiki had no canonical home explaining what that earlier pass actually does.
Without a dedicated page, it is easy to blur together:

- `legalize-js-interface`, which legalizes the **JS boundary** for `i64` import/export signatures with wrapper functions and temp-ret helpers, and
- `i64-to-i32-lowering`, which legalizes **internal module code** by pair-lowering calls, locals, globals, loads, stores, and more.

`agent-todo.md` has **no dedicated `legalize-js-interface` or `legalize-and-prune-js-interface` slice**.
This is therefore a tracker-expansion and teaching task, not a direct implementation handoff.

## Sources consulted

Official Binaryen `version_129` sources:

- `src/passes/LegalizeJSInterface.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/legalize-js-interface-exported-helpers.wast`
- `test/lit/passes/legalize-js-interface_all-features.wast`
- `test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast`
- `test/lit/passes/legalize-and-prune-js-interface.wast`

Official current-`main` spot-check sources:

- the same implementation file and four lit files above

Local repo context:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/*`
- `agent-todo.md`
- `src/passes/optimize.mbt`

## High-level conclusion

`legalize-js-interface` is a **small JS-boundary ABI pass, not a whole-module integer lowering pass**.
In reviewed `version_129`, it does four core things:

1. for exported functions whose params/results include `i64`, create `legalstub$...` wrappers that expose split `(i32 low, i32 high)` JS-friendly params/results
2. for imported functions whose params/results include `i64`, create `legalimport$...` legalized imports plus `legalfunc$...` wasm-facing wrappers
3. rewrite direct uses of illegal imports to the wasm-facing wrappers, including both `call` and `ref.func`
4. use temp-ret helpers for high halves of legalized `i64` results

The sibling `legalize-and-prune-js-interface` is the same family plus an extra prune phase that removes or stubs boundary items still illegal for JS after plain `i64` legalization.

That is the core contract.

## Public registration and family split

`pass.cpp` registers two public pass names:

- `legalize-js-interface`
  - help text: legalizes `i64` types on the import/export boundary
- `legalize-and-prune-js-interface`
  - help text: legalizes the import/export boundary and prunes when needed

So the prune form is not just a hidden flag.
It is a distinct public pass built on the same implementation file.

## Actual implementation structure

Almost everything lives in `src/passes/LegalizeJSInterface.cpp`.
The file contains:

- the temp-ret helper name constants
- the base `LegalizeJSInterface` pass
- wrapper builders for exports and imports
- a nested fixer walker for `call` and `ref.func`
- lazy helper lookup / import creation
- the subclass `LegalizeAndPruneJSInterface`
- the wider prune-only illegality test
- both factory functions

This is another case where one small owner file carries almost the full public contract.

## Plain pass: exact algorithm

## 1. Read pass arguments

At the start of `run(Module*)`, the base pass reads two mode bits:

- `legalize-js-interface-export-originals`
- `legalize-js-interface-exported-helpers`

Those affect wrapper/export/helper behavior later.

## 2. Legalize exported functions with `i64` in the boundary signature

The base `isIllegal(...)` template is narrow:

- any `i64` param is illegal
- an `i64` result is illegal

For each exported function that matches, Binaryen:

- creates or reuses `legalstub$<func>`
- retargets the export to that wrapper

The wrapper:

- rebuilds `i64` params from two `i32`s with `I64Utilities::recreateI64(...)`
- calls the original function
- if the original result is `i64`, stores the high half via the temp setter and returns only the low half as the visible `i32` result

Important nuance: one function may be exported multiple times, so Binaryen reuses a wrapper if `legalstub$...` already exists.

## 3. Optionally keep original exports

With `legalize-js-interface-export-originals`, Binaryen also adds `orig$<exportName>` exports for the original function.

But it intentionally skips:

- imported functions
- exports whose public name starts with `dynCall_`

The source comment explains this as a dynamic-linking / indirect-call boundary concern, not a blanket duplication rule.

## 4. Legalize imported functions with `i64` in the boundary signature

Binaryen then snapshots the original function list and scans imported functions.
For each imported function with an illegal `i64` boundary signature, it creates:

- `legalimport$<name>`
  - still imported
  - now with the JS-legal split signature
- `legalfunc$<name>`
  - defined in wasm
  - still exposing the original signature to wasm code

The wasm-facing wrapper:

- splits every `i64` param into low/high `i32` pieces
- calls the legalized import
- rebuilds an `i64` result from:
  - the visible low `i32` return value
  - the high half loaded from the temp getter

## 5. Repair uses of illegal imports

If Binaryen created any legalized import wrappers, it runs a nested fixer walker over both:

- ordinary function bodies, and
- module code via `runOnModuleCode(...)`

The repair surface is precise:

- `call $illegalImport` -> `call $legalfunc$illegalImport`
- `ref.func $illegalImport` -> `ref.func $legalfunc$illegalImport`

Then `ref.func` is refinalized.

This detail matters because the pass is not just editing the import/export list.
It is also repairing IR that refers to the original imported function directly.

## 6. Remove original illegal imports

Only after the repair pass runs does Binaryen remove the original illegal imports from the module.
That ordering is part of the real contract.

## 7. Remove temp-ret exports from the export list

At the end of the plain run, Binaryen removes exports named:

- `__get_temp_ret`
- `__set_temp_ret`

This is true even though those exports may have been used in `exported-helpers` mode during legalization.

## Temp-ret helper policy

The helper policy is the most non-obvious part of the family.

For `i64` results crossing the JS boundary, Binaryen uses a temp-ret side channel:

- low 32 bits are returned directly as `i32`
- high 32 bits are sent through a helper function

Helper resolution is lazy:

- default mode:
  - use or import `setTempRet0` and `getTempRet0` from `env`
- `exported-helpers` mode:
  - reuse existing exported wasm functions named `__set_temp_ret` and `__get_temp_ret`

The dedicated `legalize-js-interface-exported-helpers.wast` file proves that mode directly.

## Pruning sibling: exact extra behavior

`LegalizeAndPruneJSInterface` subclasses the base pass and then runs `prune(module)`.
That second phase is broader than the base `i64`-only check.

For imported/exported functions, it treats a boundary as still illegal when the signature involves feature-bearing types with:

- SIMD
- multivalue results
- exception handling
- stack switching

with one subtle exception: multivalue params are okay, but multivalue results are not.

For still-illegal imported functions, Binaryen removes the import status and synthesizes a body:

- `nop` if the result is `none`
- a zero/default literal if the result is defaultable
- `unreachable` otherwise

For still-illegal exported functions, Binaryen removes the export.

Then it runs `ReFinalize()` on module and module code, and finally removes exported globals whose types are still illegal for the JS boundary.

So prune mode is best taught as:

- first do ordinary `i64` wrapper legalization
- then delete or stub what still cannot be represented safely for JS

## Proof surface in shipped tests

### `legalize-js-interface_all-features.wast`

This is the best direct proof surface for the plain pass.
It shows:

- exported `i64` result wrappers
- imported `i64` result wrappers
- imported multi-`i64` param splitting
- `ref.func`-visible repair behavior

### `legalize-js-interface-exported-helpers.wast`

This isolates the exported-helper mode.
It proves that Binaryen reuses `__set_temp_ret` / `__get_temp_ret` instead of importing new helpers.

### `legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast`

This proves the `orig$...` extra export mode for original wasm-ABI functions.

### `legalize-and-prune-js-interface.wast`

This proves the sibling pass's broader prune behavior:

- plain `i64` legalization still occurs
- unsupported boundary imports become trivial wasm bodies
- unsupported boundary exports disappear
- the replacement body choice depends on result defaultability

## Relationship to `i64-to-i32-lowering`

The most important durable teaching point is the split from the later whole-module lowering pass.

`legalize-js-interface`:

- touches only the JS import/export boundary and uses of illegal imports
- preserves internal `i64` operations everywhere else
- depends on temp-ret helpers for high halves of results

`i64-to-i32-lowering`:

- rewrites calls, locals, globals, loads, stores, and signatures throughout the module
- introduces the synthetic high-bits global for returned `i64`
- explicitly assumes `legalize-js-interface` has already run for imported direct-call retargeting to make sense

So `legalize-js-interface` is a boundary ABI pass, not a generic integer lowering pass.

## Current-source drift check

A direct spot check found these reviewed surfaces identical between `version_129` and current `main`:

- `src/passes/LegalizeJSInterface.cpp`
- `test/lit/passes/legalize-js-interface-exported-helpers.wast`
- `test/lit/passes/legalize-js-interface_all-features.wast`
- `test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast`
- `test/lit/passes/legalize-and-prune-js-interface.wast`

So the tagged release contract here is still current on the inspected surfaces.

## Practical porting constraints

A faithful future port should preserve at least these exact facts:

- illegal export handling and illegal import handling are asymmetric wrapper directions
- imported-call repair must rewrite both `call` and `ref.func`
- module-code traversal matters in addition to ordinary function bodies
- temp-ret helper selection is lazy and mode-controlled
- original illegal imports are removed only after repair
- `export-originals` skips imported functions and `dynCall_*`
- prune mode uses `nop` / zero / `unreachable` replacement bodies instead of preserving import status

## Wiki work performed from this research

This research is being filed back into the living wiki as:

- `docs/wiki/binaryen/passes/legalize-js-interface/index.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/temp-ret-helpers-and-pruning-split.md`
- `docs/wiki/binaryen/passes/legalize-js-interface/wat-shapes.md`

It also requires tracker / index / log updates because this is a newly justified upstream-only dossier expansion.
