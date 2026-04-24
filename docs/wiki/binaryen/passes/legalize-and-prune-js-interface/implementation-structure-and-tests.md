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
  - ./binaryen-strategy.md
  - ./prune-boundary-matrix.md
  - ./starshine-strategy.md
  - ../legalize-js-interface/implementation-structure-and-tests.md
---

# `legalize-and-prune-js-interface` implementation structure and tests

Use this page with the 2026-04-24 raw primary-source capture in [`../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-and-prune-js-interface-primary-sources.md). The capture records the official release page, shared owner file, registration source, and dedicated lit fixture reviewed for this dossier.

## Owner file map

## `src/passes/LegalizeJSInterface.cpp`

This is the real owner file for the prune sibling too.
The implementation surface is small and explicit:

- subclass `LegalizeAndPruneJSInterface : LegalizeJSInterface`
- `run(Module*)`
  - call the base pass first
  - then call `prune(module)`
- `prune(Module*)`
  - collect exported function names
  - prune imported/exported functions still illegal for JS
  - run `ReFinalize()`
  - prune illegal exported globals
- subclass `isIllegal(Type type)`
  - feature-based legality check for SIMD, multivalue, EH, and stack switching
- `createLegalizeAndPruneJSInterfacePass()`

There is no separate `LegalizeAndPruneJSInterface.cpp`.
That absence is part of the correct mental model: the sibling is a small extension layer on the plain pass, not a second large pipeline.

## `src/passes/pass.cpp`

`pass.cpp` is the public registration surface.
It proves that Binaryen exposes:

- `legalize-js-interface`
- `legalize-and-prune-js-interface`

as distinct public pass names with distinct help text.
That is why the sibling deserves its own dossier even though most code lives in a shared owner file.

## Helper ownership visible from includes

The reviewed owner file also makes visible which helpers matter around the sibling:

- `ir/literal-utils.h`
  - zero/default literal construction for defaultable illegal-import stubs
- `ir/import-utils.h`
  - shared import lookup support inherited from the base pass
- `shared-constants.h` and `asmjs/shared-constants.h`
  - helper/import name constants used by the family
- `wasm-builder.h`
  - stub-body construction

But the prune-specific algorithm is still concentrated in the owner file itself.

## Proof surface in shipped tests

## `test/lit/passes/legalize-and-prune-js-interface.wast`

This is the dedicated proof file for the sibling and the main reason a separate dossier is worthwhile.
It covers all the important beginner-facing cases:

- ordinary inherited `i64` legalization still occurring
- imported illegal functions becoming trivial internal bodies
- exported illegal functions losing their exports
- imported-and-exported illegal functions being both stubbed and unexported
- defaultable-result stubs returning zero/default literals
- nondefaultable-result stubs trapping with `unreachable`
- illegal exported globals losing only the export while legal global exports remain

For this pass, the lit file is not just supplementary evidence.
It is the clearest compact statement of the whole public behavior.

## Relationship to the neighboring plain-pass tests

The sibling also depends indirectly on the same shared-family surfaces the plain dossier already maps:

- the base wrapper builders in `LegalizeJSInterface.cpp`
- temp-ret helper behavior
- import/export retargeting details

But those are already taught well in the plain folder.
This folder's unique proof surface is mainly the prune lit file.

## What the test surface most strongly proves

The strongest direct source-backed conclusions are:

- the prune sibling still performs plain `i64` legalization first
- import replacement is result-sensitive (`nop` vs zero/default vs `unreachable`)
- export removal is independent from import replacement
- global export pruning is real and narrower than function pruning

## Current-`main` drift check

A direct 2026-04-24 spot check found no teaching-relevant checked-surface drift between `version_129` and current `main` in:

- `src/passes/LegalizeJSInterface.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/legalize-and-prune-js-interface.wast`

So the folder's structure and proof map remain current on the reviewed surfaces. This is intentionally narrow; it is not a whole-repository drift proof.

For the current in-tree Starshine status, see [`./starshine-strategy.md`](./starshine-strategy.md): there is no local owner file or registry entry for this sibling today.
