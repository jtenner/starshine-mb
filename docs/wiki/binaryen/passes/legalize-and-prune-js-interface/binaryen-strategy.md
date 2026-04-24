---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md
  - ../../../raw/research/0292-2026-04-24-legalize-and-prune-js-interface-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0224-2026-04-21-legalize-and-prune-js-interface-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./prune-boundary-matrix.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../legalize-js-interface/index.md
---

# Binaryen strategy for `legalize-and-prune-js-interface`

Use this page with the 2026-04-24 raw primary-source capture in [`../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md). The raw capture records the official `version_129` release provenance and the narrow current-`main` spot check behind this strategy.

## One-sentence contract

Binaryen `version_129` implements `legalize-and-prune-js-interface` as:

- **plain `legalize-js-interface` first**
- **then a prune pass over boundary-visible functions and globals that still expose JS-hostile features**

That order is the whole pass story.

## Phase 1: inherit plain `i64` legalization

The subclass `run(Module*)` begins with:

- `LegalizeJSInterface::run(module)`

So everything the plain dossier teaches remains in scope first:

- `legalstub$...` wrappers for exported functions with `i64` in the boundary signature
- `legalimport$...` plus `legalfunc$...` pairs for imported functions with `i64`
- `call` and `ref.func` retargeting for rewritten illegal imports
- temp-ret helper use for the high 32 bits of legalized `i64` results

This is why the sibling should never be described as an unrelated implementation.

## Phase 2: build an export-name map

Inside `prune(module)`, Binaryen first records which internal function names are exported and under what public export names.
That matters because the later pruning walk needs to know, for each function:

- whether it is imported
- whether it is exported
- what export name should be removed if it is still illegal

The pass does **not** do a whole-program reachability analysis here.
It only cares about JS boundary exposure.

## Phase 3: scan functions that are still on the boundary

Binaryen iterates all functions and skips any function that is neither:

- imported, nor
- exported

So a private defined function with a SIMD or EH signature is not this pass's concern.
The pass is boundary-driven, not a general type sanitizer.

## The subclass legality predicate

For functions, Binaryen reads the signature and decides illegality in two pieces:

1. check `sig.results` as a whole
2. check each param type separately

The subclass `isIllegal(Type type)` returns true when the type's feature set has any of:

- SIMD
- multivalue
- exception handling
- stack switching

### Important subtlety: multivalue params vs multivalue results

This implementation detail creates a teaching-important distinction:

- results may not be multivalue, because `sig.results` is checked as a whole
- params may be multivalue in aggregate, because the code iterates param types one at a time instead of checking the parameter tuple as one value

The source comment says this directly: params are allowed to be multivalue, but results are not. Keep this caveat visible because it is easy to overgeneralize the pass into “all multivalue boundaries are pruned.”

## Phase 4: prune illegal imported functions by synthesizing bodies

If a boundary-visible function is still illegal and is imported, Binaryen removes its import status by clearing:

- `func->module`
- `func->base`

and then exact-ifies the type with `func->type = func->type.with(Exact)`.

After that it synthesizes a trivial body according to the result type:

- `none` result -> `nop`
- defaultable result -> `Literal::makeZeros(sig.results)`
- nondefaultable result -> `unreachable`

This is the most important semantic warning in the pass.
The sibling is not trying to emulate the removed host import.
It is choosing the smallest legal internal replacement Binaryen knows how to emit.

## Phase 5: prune illegal exported functions by removing exports

If the same function is exported and still illegal, Binaryen removes the export entry.
It does **not** delete the function body.

That means one function can experience both halves of the algorithm:

- if it is imported, it becomes a trivial internal function
- if it is also exported, the export disappears too

The lit file proves this combined case directly.

## Why function pruning happens before global pruning

After the function walk, Binaryen runs:

- `ReFinalize().run(...)`
- `ReFinalize().runOnModuleCode(...)`

The source comment mentions `RefFunc` types.
The practical reason is simple:

- converting an import into an internal function body can change exact function-reference typing facts
- some module-code `ref.func` users need those facts refreshed before the module is considered stable again

Only after that refinalization pass does Binaryen prune illegal global exports.

## Phase 6: prune illegal global exports

The global step is simpler than the function step.
Binaryen scans exports, collects export names of globals whose types are still illegal under the subclass feature test, and removes only those exports.

Important limits:

- globals are not stubbed
- globals are not deleted from the module
- only the JS-visible export is removed

So function imports and global exports are handled very differently.

## What the pass preserves vs what it intentionally does not

### Preserved

- plain `i64` boundary legalization behavior from the base pass
- legal boundary imports/exports that do not hit the subclass feature gate
- internal functions and globals that are not JS-visible

### Intentionally not preserved

- original semantics of pruned illegal imports
- original JS visibility of illegal exports
- the imported status of illegal boundary functions

That is why this pass is better described as boundary sanitization than ordinary legalization.

## Relationship to nearby passes

## Versus `legalize-js-interface`

- plain pass: adapt `i64` function boundaries
- prune sibling: adapt `i64` function boundaries, then stub or hide whatever is still JS-illegal

## Versus `i64-to-i32-lowering`

- plain/prune JS-interface passes: only rewrite the JS boundary
- `i64-to-i32-lowering`: whole-module internal ABI and opcode lowering

## Versus generic cleanup passes

This pass does not do:

- dead-code elimination
- import reachability analysis
- arbitrary feature lowering
- general host shim synthesis

Its scope is narrower and more ABI-specific.

## Beginner memory aid

A compact way to remember the strategy is:

1. **wrap `i64` boundaries**
2. **stub illegal imports**
3. **drop illegal exports**
4. **refinalize**
5. **drop illegal global exports**

For the current local Starshine status and future-port map, see [`./starshine-strategy.md`](./starshine-strategy.md).
