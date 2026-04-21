---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0223-2026-04-21-legalize-js-interface-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface-exported-helpers.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# Temp-ret helpers, pass arguments, and the prune sibling

## Why this page exists

The easiest way to misread `legalize-js-interface` is to think it is just:

- "split `i64` into two `i32`s"

That is not enough.
The real family also depends on:

- where the high 32 bits of legalized results go
- whether helper functions come from imports or existing exports
- whether original exports are retained
- what the pruning sibling does once plain `i64` legalization is over

## Temp-ret helpers

When an `i64` result crosses the JS boundary, Binaryen does not try to return two visible values.
Instead it uses a classic temp-ret side channel:

- low 32 bits are the visible function result
- high 32 bits go through a setter/getter helper pair

### Export side

For a legalized export wrapper:

- call the original wasm function
- store the `i64` result in a temp local
- call the temp setter with the high 32 bits
- return the low 32 bits

### Import side

For a legalized import wrapper:

- call the JS-legal import and receive the low 32 bits directly
- call the temp getter to fetch the high 32 bits
- rebuild the original `i64`

## `exported-helpers` mode

In default mode, Binaryen resolves helpers as imports named:

- `setTempRet0`
- `getTempRet0`

from `env`.

But with `--pass-arg=legalize-js-interface-exported-helpers`, it instead reuses existing exported wasm functions named:

- `__set_temp_ret`
- `__get_temp_ret`

This is a real behavior change, not a documentation flourish.
The dedicated lit file proves it directly.

## `export-originals` mode

With `--pass-arg=legalize-js-interface-export-originals`, Binaryen keeps extra exports of the original wasm-ABI function under names prefixed with `orig$`.

That is useful when some non-JS consumer still needs the unlegalized wasm signature.

But Binaryen deliberately skips:

- imported functions
- `dynCall_*` exports

So this flag is not a blanket "duplicate every export" mode.

## The prune sibling is not just a flag

`legalize-and-prune-js-interface` is a separate public pass name, implemented as a subclass that first runs plain legalization and then prunes whatever remains JS-illegal.

That second phase uses a wider illegality check than the plain pass.
It looks for feature-bearing types with:

- SIMD
- multivalue results
- exception handling
- stack switching

So the sibling should be taught as:

- plain `i64` legalization
- **plus** fallback removal/stubbing for JS-boundary features still not supported here

not as just another spelling for plain legalization.

## What prune does to illegal imports

If a still-illegal boundary function is imported, Binaryen removes the import status and synthesizes a body:

- `nop` when the function returns nothing
- a zero/default literal when the result is defaultable
- `unreachable` when the result is nondefaultable and Binaryen has no value-preserving stub to emit

That is a practical fuzzing / boundary-sanitizing tactic, not a semantic preservation story.

## What prune does to illegal exports and globals

For still-illegal exported functions:

- remove the export

For exported globals with illegal JS-surface types:

- remove the export

And because function-ref-visible types may have shifted, Binaryen runs `ReFinalize()` afterward.

## Durable beginner rule

A good memory aid is:

- plain pass = **wrap** illegal `i64` function boundaries
- helper args = choose **how** the temp-ret mechanism is wired
- prune sibling = **delete or stub** whatever plain wrapping still cannot make JS-legal
