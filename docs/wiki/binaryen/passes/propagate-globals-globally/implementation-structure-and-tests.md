---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-propagate-globals-globally-primary-sources.md
  - ../../../raw/binaryen/2026-05-05-propagate-globals-globally-current-main-recheck.md
  - ../../../raw/research/0320-2026-04-24-propagate-globals-globally-source-correction-and-starshine-followup.md
  - ../../../raw/research/0459-2026-05-05-propagate-globals-globally-current-main-recheck.md
  - ../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./shared-engine-and-startup-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `propagate-globals-globally`: implementation structure and tests

This page maps the upstream files and tests that define Binaryen `version_129` `propagate-globals-globally`.

## Core source files

### `src/passes/SimplifyGlobals.cpp`

This is the real implementation file.

The pass does **not** live in a standalone `PropagateGlobals.cpp`. It also is not just the ordinary `SimplifyGlobals` pass constructed with a boolean flag. `SimplifyGlobals.cpp` contains both:

- the broader `SimplifyGlobals` / `simplify-globals*` machinery
- the narrow `PropagateGlobalsGlobally` subclass for this public pass

For this dossier, the important reviewed pieces are:

- `propagateConstantsToGlobals()`
  - owns the startup/global rewrite routine
  - records known global literal values
  - substitutes known values into global initializers
  - rewrites active element offsets
  - rewrites active data offsets
- `replaceGlobalGets(...)`
  - finds `GlobalGet` nodes and replaces already-known names with copied constant expressions
- `Properties::isConstantExpression(...)`
  - decides whether a rewritten initializer can be recorded as known
- `PropagateGlobalsGlobally::run(Module*)`
  - calls only `propagateConstantsToGlobals()`
  - intentionally skips the function-body propagation path used by `simplify-globals`
- `SimplifyGlobals::iteration(...)`
  - contrast point: the broader sibling calls `propagateConstantsToGlobals()` and then `propagateConstantsToCode()`

## `src/passes/pass.cpp`

This file proves `propagate-globals-globally` is a public Binaryen pass name in `version_129`.

It matters because the separate registration is what turns a small subclass into a stable public contract.

## `test/lit/passes/propagate-globals-globally.wast`

This is the dedicated behavior oracle for the pass.

It proves:

- the pass has its own `wasm-opt --propagate-globals-globally` run line
- direct immutable-global propagation is expected
- chained constant-expression propagation is expected
- a GC/string constant-expression example belongs in the direct proof surface
- function-body `global.get` preservation is expected for this pass
- `simplify-globals` is intentionally shown as the broader contrast that rewrites more runtime code

## Helper and dependency files

| Helper surface | Why it matters |
| --- | --- |
| `src/ir/find_all.h` | `FindAllPointers<GlobalGet>` is the source-backed way the pass locates global uses under startup expressions. |
| `src/ir/properties.h` | `Properties::isConstantExpression(...)` is the reviewed predicate behind “known startup value.” |
| `src/wasm-builder.h` | `Builder::makeConstantExpression(...)` materializes copied literal values during substitution. |
| `src/wasm/literal.h` | Literal extraction/storage underlies the global-name-to-literals map. |

## File map in one table

| File | Why it matters | Main thing it proves |
| --- | --- | --- |
| `src/passes/SimplifyGlobals.cpp` | Core algorithm | Narrow subclass calls startup/global propagation only; broader sibling continues into code propagation. |
| `src/passes/pass.cpp` | Public registration | `propagate-globals-globally` is a real public pass name. |
| `test/lit/passes/propagate-globals-globally.wast` | Behavior oracle | Global initializers and active offsets are rewritten; function-body uses stay for this pass. |
| current `main` `SimplifyGlobals.cpp` / lit file | Drift spot check | The same teaching-relevant family structure remained visible on 2026-05-05. |

## What the test map says about the real contract

The dedicated lit file prevents two common mistakes.

### Mistake 1: treating the pass as too broad

The lit file contrasts this pass with `simplify-globals`: `propagate-globals-globally` does not rewrite ordinary function-body global uses.

### Mistake 2: treating the pass as too tiny

The lit file also proves it is not just direct alias replacement. It handles chained constant expressions and a GC/string constant-expression shape.

## What changed from older dossier wording

The older `0196` note remains useful for the shared-owner-file correction, but this page supersedes it for these mechanics:

- no source-confirmed `canHandleAsGlobal` / `allInputsConstant` helper pair in the reviewed release
- no reverse global scan
- no “`optimize = false` is the public-pass stop point” explanation
- no hand-maintained closed list of allowed expression kinds; cite `Properties::isConstantExpression(...)` instead

## Porting takeaway

If Starshine ever ports this pass, the source map suggests a module-pass target:

- scan and rewrite `GlobalSec` initializers
- rewrite active `ElemSec` offsets
- rewrite active `DataSec` offsets
- preserve function-body `global.get` uses in this specific pass
- share helper ideas with future `simplify-globals*` work only if the smaller public contract remains testable in isolation
