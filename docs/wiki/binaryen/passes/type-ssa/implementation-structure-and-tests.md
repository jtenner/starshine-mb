---
kind: concept
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0409-2026-04-26-type-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-05-06-type-ssa-current-main-recheck.md
  - ../../../raw/research/0503-2026-05-06-type-ssa-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-01-type-ssa-current-main-recheck.md
  - ../../../raw/research/0688-2026-06-01-type-ssa-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md
  - ../../../raw/research/0386-2026-04-26-type-ssa-source-correction.md
  - ../../../raw/binaryen/2026-04-23-type-ssa-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Upstream implementation structure and test map for `type-ssa`

## Why this page exists

This page maps the official Binaryen files that define `type-ssa` after the 2026-04-26 source correction and the 2026-05-06 current-main freshness recheck. The main correction is that `TypeSSA.cpp` is an allocation-subtype creation pass, not the local/global/control-value retagging pass described by the older 2026-04-23 dossier.

## Main upstream files

### 1. `src/passes/TypeSSA.cpp`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeSSA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeSSA.cpp>

This is the owner file. It defines:

- the GC feature gate,
- the `news` allocation-site collection,
- the `disallowedTypes` exact-observation collection,
- the module-code/global/element scanning surface, with table initializers explicitly left as a TODO in the current source,
- `ChildTyper`-based child exactness checks,
- the `isInteresting(...)` filter,
- `modifyNews(...)` fresh subtype / rec-group creation,
- allocation result-type rewrites,
- type-name copying,
- and final `ReFinalize` over functions and module code.

If you only read one file for `type-ssa`, read this one.

### 2. `src/passes/pass.cpp`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

This file proves that `type-ssa` is a real public pass name. That is the reason this dossier exists independently instead of being only a note inside `type-merging` or `ssa`.

### 3. `src/passes/passes.h`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>

This file exposes the `createTypeSSAPass()` factory in the pass factory surface.

### 4. `src/ir/ReFinalize.cpp`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/ir/ReFinalize.cpp>

`type-ssa` invokes `ReFinalize` after allocation type rewrites. That makes parent-type repair part of the correctness contract.

### 5. `src/wasm-type-shape.*`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type-shape.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-type-shape.h>

The owner file uses type-shape machinery when making the fresh rec group unique. This is a subtle but important implementation detail: the pass is not just appending ad-hoc duplicate type declarations.

## Dedicated official test

### `test/lit/passes/type-ssa.wast`

Source:
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-ssa.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-ssa.wast>

This is the direct public proof surface for the pass. Read it as a type-section and allocation-result oracle:

- positive `struct.new` splitting,
- array allocation splitting,
- positive interestingness cases,
- preserved allocations when exactness or type-shape safety blocks fresh subtype creation,
- refinalized output after allocation result types change.

Do not read the test as a proof of local/global get retagging; that was the stale 2026-04-23 interpretation.

## File map in one table

| File | Why it matters | Main thing it proves |
| --- | --- | --- |
| `TypeSSA.cpp` | core algorithm | selected allocations become exact fresh private subtypes |
| `pass.cpp` | public registration | `type-ssa` is a user-visible Binaryen pass |
| `passes.h` | factory surface | the pass has an ordinary pass-construction entry point |
| `ReFinalize.cpp` | correctness dependency | parent/module-code types are repaired after rewrites |
| `wasm-type-shape.*` | type uniqueness helper | fresh rec groups are canonicalized instead of blindly duplicated |
| `type-ssa.wast` | behavior oracle | official allocation-subtype positives and bailouts |

## Implementation outline

The corrected `version_129` implementation is best read in this order:

1. gate on GC,
2. scan functions and module-level expressions for allocation candidates,
3. record exact-observation blockers,
4. filter candidates with `isInteresting(...)`,
5. build fresh private subtypes in a new rec group,
6. make the new group unique,
7. rewrite each selected allocation's result type to exact non-null fresh subtype,
8. copy useful names,
9. refinalize functions and module code.

## Superseded implementation outline

The older local wiki said the implementation worked by:

1. recording created exact types in an expression map,
2. forwarding facts through `block` / `if` / `try`,
3. propagating through locals/globals,
4. retagging later gets, calls, and returns.

That outline is stale and should not be used for implementation planning.

## Starshine proof surface implied by the upstream map

A future Starshine implementation needs tests and code for:

- parsing and representing the allocation instructions listed above,
- discovering allocations in ordinary functions and module-level code,
- deciding exact-observation blockers,
- creating fresh heap types and rec groups,
- preserving or deriving type names safely,
- retagging allocation instruction result types,
- refinalizing or validating rewritten parent expression types,
- comparing generated WAT/type sections against `wasm-opt --type-ssa`.

That is module/type-section infrastructure. It is not a small HOT local-flow port.

## Current-main drift

The 2026-06-01 current-main recheck found no teaching-relevant drift from this corrected map.
