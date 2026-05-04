---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md
  - ../../../raw/research/0341-2026-04-25-de-nan-current-main-recheck.md
  - ../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/denan.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DeNaN.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/denan.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./helper-functions-fallthrough-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Upstream implementation structure and tests for `de-nan` / `denan`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md`](../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md), the focused current-main recheck in [`../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md), and the current Starshine status bridge in [`./starshine-strategy.md`](./starshine-strategy.md).

This page answers a narrow question:

- which upstream files actually define the public `denan` contract?

## Main files

## 1. `src/passes/DeNaN.cpp`

This is the whole implementation.
It defines:

- the pass type and `addsEffects()` contract
- the `visitExpression(...)` rewrite surface
- the `visitFunction(...)` entry-param repair phase
- the nested `merge-blocks` cleanup step
- helper-name generation
- helper-function emission
- the constant `v128` NaN check helper

If you are porting the pass, this is the main oracle.

## 2. `src/passes/pass.cpp`

This file proves:

- the official public pass name is `denan`
- the public CLI description is `instrument the wasm to convert NaNs into 0 at runtime`

This matters because the local registry still uses the alias `de-nan`.

## 3. `test/lit/passes/denan.wast`

This file is the practical behavior surface.
It proves and/or demonstrates:

- NaN global constants become zero global constants
- non-imported float params are sanitized on entry
- call results are wrapped
- `local.get` uses are deliberately left alone
- constant NaNs in bodies become zero constants without helper calls
- repeated `local.tee` / pass-through ladders stay structurally intact
- `select` shells stay intact
- helper names are made collision-safe when the module already defines functions named `deNan32` or `deNan64`

## Important helper headers

## `src/ir/properties.h`

This file matters because it defines `Properties::isResultFallthrough(...)`.
That helper is the main reason `denan` does not wrap every float-typed shell node.

## `src/ir/names.h`

This file matters because it defines `Names::getValidFunctionName(...)`.
That makes helper naming a real source-backed contract instead of an implicit assumption.

## `src/wasm-builder.h`

This is not where policy lives, but it matters because the pass constructs all of its rewrites and helper functions through `Builder` APIs.
A port that wants to preserve exact shape should mirror those emitted forms closely.

## What the lit file covers explicitly

## Coverage family 1: global constant fixup

The first module in `denan.wast` checks that:

- `(global (mut f32) (f32.const nan))`

becomes:

- `(global (mut f32) (f32.const 0))`

and that ordinary non-NaN constants remain unchanged.

This is the clearest proof of the “constant repair is legal outside function context” rule.

## Coverage family 2: parameter-entry sanitization

The lit file checks functions like:

- `foo32`
- `foo64`
- `various`

and verifies that float params are rewritten at entry with `local.set param (call $deNanXX (local.get param))`.

This proves the parameter-entry phase is part of the public contract, not an implementation accident.

## Coverage family 3: `local.get` skip and producer wrapping

The `ignore-local.get` function is the single best teaching test.
It shows that:

- `drop (local.get $f)` stays a plain `local.get`
- `local.set $f (local.get $f)` stays a plain `local.get` source
- but `f32.abs` and `f64.abs` producers get wrapped in helper calls

That is the cleanest official evidence for the distinction between:

- pass-through reads, and
- value-producing computations

## Coverage family 4: constant NaN in function bodies

The `constants` function demonstrates that:

- normal constants stay normal constants
- NaN constants become zero constants
- helper calls are not inserted when compile-time replacement is possible

## Coverage family 5: fallthrough shell preservation

The `tees` and `select` functions show that the pass preserves shell structure in cases where the value already falls through from a child.
That aligns directly with the `Properties::isResultFallthrough(...)` source rule.

## Coverage family 6: helper-name collision avoidance

The second module defines user functions named:

- `$deNan32`
- `$deNan64`

The checks then show Binaryen creating fresh helpers named:

- `$deNan32_4`
- `$deNan64_4`

This is the strongest official test evidence that helper naming is collision-safe and intentionally part of the implementation contract.

## What the lit file does **not** cover very well

## 1. SIMD helper internals

The shipped `denan.wast` file does not deeply exercise the `v128` path.
The source file still gives high-confidence details for it, but this is a place where the implementation is more informative than the lit coverage.

## 2. Imported-function skip

The implementation clearly skips imported functions, but the lit file is not built around a focused imported-function example.
This is source-backed, not test-led.

## 3. Warning path outside function context

The warning path for nonconstant nonfunction contexts is visible in the implementation, but not meaningfully exercised by the shipped lit file.

## Current-main drift check

A narrow 2026-04-24 freshness check found:

- `src/passes/DeNaN.cpp`
  - same implementation as `version_129` except for a comment typo fix (`contant` -> `constant`)
- `src/passes/pass.cpp`
  - unchanged registration block for `denan`
- `test/lit/passes/denan.wast`
  - byte-identical to `version_129`

The 2026-04-25 recheck in [`../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md) widened that spot check to the helper/legality context files (`properties.h`, `names.h`, `wasm-builder.h`, and `pass.h`) and still found no teaching-relevant current-main drift. So the tagged `version_129` sources remain a reliable oracle here.

## Porting checklist from the file map

If you want the minimum file-guided port checklist, preserve these things in this order:

1. public pass naming (`denan` upstream, `de-nan` local alias)
2. `addsEffects()` truthfulness
3. `visitExpression` type/const/skip matrix
4. `visitFunction` parameter-entry repair phase
5. nested `merge-blocks` cleanup
6. helper-name collision avoidance
7. scalar helper self-equality contract
8. SIMD helper lane-extraction strategy
9. constant global repair without call insertion

## Sources

- [`../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md`](../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md)
- [`../../../raw/research/0341-2026-04-25-de-nan-current-main-recheck.md`](../../../raw/research/0341-2026-04-25-de-nan-current-main-recheck.md)
- [`../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md`](../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md`](../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/denan.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DeNaN.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/denan.wast>
