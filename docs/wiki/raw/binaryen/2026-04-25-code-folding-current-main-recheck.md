# Binaryen `code-folding` current-main recheck

_Capture date:_ 2026-04-25  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/code-folding/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-04-25 `code-folding` wiki-health pass.
It complements, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-22-code-folding-primary-sources.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/code-folding/index.md`
- `docs/wiki/binaryen/passes/code-folding/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/code-folding/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/code-folding/terminating-tails.md`
- `docs/wiki/binaryen/passes/code-folding/wat-shapes.md`
- `docs/wiki/binaryen/passes/code-folding/starshine-strategy.md`

## Official sources consulted

### Binaryen `main`

- `CodeFolding.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/CodeFolding.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/CodeFolding.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `opt-utils.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/opt-utils.h>
- `passes.h`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/passes.h>
- Dedicated lit test `code-folding.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/code-folding.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/code-folding.wast>

### Tagged comparison anchor

- `CodeFolding.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodeFolding.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `passes.h` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `code-folding.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/code-folding.wast>

## Durable observations

- Current `main` still exposes `code-folding` through the same pass family: the core owner remains `src/passes/CodeFolding.cpp`, the public pass constructor remains declared through `passes.h`, and the registry/scheduler surface remains in `pass.cpp`.
- The current-main source still teaches the same two-family algorithm already captured from `version_129`: expression-exit tail folding for named block exits / foldable `if` arms, and a separate function-ending suffix-sharing algorithm for `return`, `return_call*`, and `unreachable` tails.
- The same high-value correctness boundaries remain visible in the official sources: unsupported branch forms poison label folding, branch-target scope is checked before motion, EH-sensitive `pop` / throwing movement is conservative, profitable rewrites can add helper blocks, and EH nested-pop repair can run after block-adding rewrites.
- The dedicated current-main lit file still exercises the same beginner-through-advanced teaching families: simple identical `if` arms, branch-value tail sharing, fallthrough-plus-branch exits, helper-label terminating-tail folds, `br_on_*` poisoning, and outside-target bailout cases.
- No teaching-relevant drift was found in this focused recheck. The useful 2026-04-25 wiki change is therefore an implementation/test-map page and fresher source bridge, not a semantic rewrite of the existing strategy pages.

## Uncertainty and follow-up

- This recheck is source-level and documentation-focused. It does not assert byte-for-byte equivalence between `version_129` and current `main`; it only records that the reviewed public contract and teaching examples did not change in a way that affects Starshine wiki guidance.
- The local Starshine status is unchanged by this source recheck: `code-folding` remains a removed-name / unimplemented transform with a documented future port surface.
