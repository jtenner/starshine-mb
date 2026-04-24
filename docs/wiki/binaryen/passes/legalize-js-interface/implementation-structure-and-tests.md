---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md
  - ../../../raw/research/0291-2026-04-24-legalize-js-interface-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0223-2026-04-21-legalize-js-interface-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface-exported-helpers.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./temp-ret-helpers-and-pruning-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `legalize-js-interface` implementation structure and tests

## Owner file map

## `src/passes/LegalizeJSInterface.cpp`

This is the real owner file for both public pass names:

- `legalize-js-interface`
- `legalize-and-prune-js-interface`

It contains:

- the temp-ret helper name constants
- the main `LegalizeJSInterface` pass
- export stub creation via `makeLegalStub(...)`
- import wrapper creation via `makeLegalStubForCalledImport(...)`
- call / `ref.func` repair for rewritten imports
- lazy helper lookup / import creation via `getFunctionOrImport(...)`
- the subclass `LegalizeAndPruneJSInterface`
- the wider pruning legality check and replacement logic
- both public factory functions

There is no second major implementation file hiding the prune logic somewhere else.

## `src/passes/pass.cpp`

`pass.cpp` is the public registration surface.
It proves that Binaryen exposes two distinct CLI names with distinct help text:

- `legalize-js-interface`
- `legalize-and-prune-js-interface`

That matters because the sibling relationship is real public API, not just an internal mode bit.

## Helper ownership visible from includes

The reviewed file also makes some helper ownership easy to see:

- `ir/import-utils.h`
  - import lookup support used by `getFunctionOrImport(...)`
- `ir/literal-utils.h`
  - zero/default literal support for prune-mode import replacement
- `ir/utils.h`
  - generic IR helpers used by the pass file
- `ir/element-utils.h`
  - relevant surrounding IR utility surface
- `asmjs/shared-constants.h` and `shared-constants.h`
  - stable helper/import name constants such as `ENV`

But the pass's actual algorithmic contract still lives overwhelmingly in `LegalizeJSInterface.cpp` itself.

## Proof surface in shipped tests

## `test/lit/passes/legalize-js-interface_all-features.wast`

This is the broadest direct proof file for plain legalization.
It shows:

- imported `i64` result legalization
- imported `i64` parameter splitting
- multiple `i64` params in one signature
- exported `i64` result wrapping
- `ref.func`-visible imported target repair
- all-features printing compatibility around the rewritten module

This is the best single file for the plain pass's main behavior.

## `test/lit/passes/legalize-js-interface-exported-helpers.wast`

This is the focused proof for `--pass-arg=legalize-js-interface-exported-helpers`.
It shows:

- reuse of exported `__set_temp_ret`
- reuse of exported `__get_temp_ret`
- no need to invent fresh `env` helper imports when those exports already exist

This file is the main evidence for the helper-selection mode split.

## `test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast`

This is the focused proof for `--pass-arg=legalize-js-interface-export-originals`.
It shows:

- the legalized export wrapper staying public
- an extra `orig$...` export being emitted for the original wasm ABI function

This is the clearest direct proof that `export-originals` is part of the real public contract.

## `test/lit/passes/legalize-and-prune-js-interface.wast`

This is the dedicated proof file for the pruning sibling.
It shows:

- ordinary `i64` boundary legalization still happening
- imports with unsupported JS-surface features being replaced with trivial wasm bodies
- exports with unsupported JS-surface features being removed
- prune-mode defaultable-result vs trapping-result behavior

This file is why the prune sibling should be taught as a real extra pass, not as a vague undocumented side effect.

## What the test surface does not imply

The dedicated lit files prove the public family well, but they do **not** mean:

- plain `legalize-js-interface` legalizes every unsupported wasm feature for JS
- prune mode preserves imported semantics for unsupported features
- this family is a substitute for whole-module `i64` lowering

The source makes those limits explicit, and the wiki should keep them explicit too.

## Current-`main` drift check

The immutable source URL set reviewed for this page is captured in [`../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md).
A direct spot check found these reviewed surfaces identical or teaching-equivalent between `version_129` and current `main`:

- `src/passes/LegalizeJSInterface.cpp`
- `test/lit/passes/legalize-js-interface-exported-helpers.wast`
- `test/lit/passes/legalize-js-interface_all-features.wast`
- `test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast`
- `test/lit/passes/legalize-and-prune-js-interface.wast`

So the dossier's source-confirmed structure is not currently sitting on obvious checked-surface drift.
For the current Starshine status and local code-map bridge, see [`./starshine-strategy.md`](./starshine-strategy.md).
