---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md
  - ../../../raw/research/0395-2026-04-26-legalize-js-interface-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md
  - ../../../raw/research/0291-2026-04-24-legalize-js-interface-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0223-2026-04-21-legalize-js-interface-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./temp-ret-helpers-and-pruning-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../i64-to-i32-lowering/index.md
---

# Binaryen strategy for `legalize-js-interface`

## One-sentence contract

Binaryen `version_129` and the 2026-04-26 checked current `main` `legalize-js-interface` are small module / boundary passes that rewrite JS-visible function imports and exports containing `i64` into wrapper-based `(i32 low, i32 high)` ABI pairs, using temp-ret helpers for high result halves.

## The pass family split

`pass.cpp` registers two public names from the same implementation file:

- `legalize-js-interface`
  - description: legalizes `i64` types on the import/export boundary
- `legalize-and-prune-js-interface`
  - description: legalizes the import/export boundary and prunes when needed

That split matters.
The plain pass handles only `i64` function-boundary legalization.
The pruning sibling runs the plain pass first and then removes or stubs still-illegal JS boundary surfaces.

## Main algorithm shape

The 2026-04-26 current-main recheck in [`../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md) found no teaching-relevant drift from this phase order. Future Starshine work should still validate against current Binaryen before landing behavior.

## Phase 1: record pass arguments

At the start of `run(Module*)`, the pass reads two flags:

- `legalize-js-interface-export-originals`
- `legalize-js-interface-exported-helpers`

Those are not separate passes.
They are mode bits inside the same implementation.

## Phase 2: rewrite illegal function exports

Binaryen scans module exports.
For each function export:

- look up the exported function
- ignore it if the function is already JS-legal
- otherwise build or reuse `legalstub$<func>`
- retarget the export to that stub

The base `isIllegal(...)` rule for this phase is narrow:

- any `i64` param makes the signature illegal for JS
- an `i64` result also makes it illegal

No other feature family is considered by the plain pass.

### What export stubs do

A `legalstub$...` wrapper is the JS-facing entrypoint.
Its job is:

- accept a legalized signature where every `i64` param became two `i32`s
- rebuild each original `i64` with `I64Utilities::recreateI64(...)`
- call the real wasm function
- if the original result was `i64`, store the high 32 bits through the temp setter and return the low 32 bits directly

So export wrappers convert:

- JS ABI -> original wasm ABI

not the other way around.

## Phase 3: optionally keep original exports

When `legalize-js-interface-export-originals` is set, Binaryen also adds `orig$<export-name>` exports pointing at the original function.

But it deliberately skips two cases:

- imported functions
- exports whose name starts with `dynCall_`

The source comment explains why: dynamic-linking and indirect-call users may still need the original wasm ABI, but imported functions will already be legalized in their own defining module, and `dynCall_*` names are only for JS anyway.

## Phase 4: wrap illegal function imports

Next Binaryen copies the original function list into a temporary vector to avoid iterator invalidation and scans imported functions.
For each imported function with an illegal `i64` boundary signature, it creates two new functions:

- `legalimport$<name>`
  - still an import
  - now has the JS-legal split signature
- `legalfunc$<name>`
  - a wasm-defined wrapper
  - keeps the original wasm-visible signature

### What import wrappers do

A `legalfunc$...` wrapper is the wasm-facing entrypoint.
Its job is:

- accept the original wasm signature
- split every `i64` argument into low/high `i32` operands
- call `legalimport$...`
- if the original result was `i64`, rebuild it from:
  - the low 32 bits returned directly by `legalimport$...`
  - the high 32 bits fetched from the temp getter

So import wrappers convert:

- original wasm ABI -> JS ABI -> original wasm result shape

## Phase 5: repair all call sites and `ref.func`

After creating import wrappers, Binaryen runs a nested walker over:

- ordinary function bodies, and
- module code via `runOnModuleCode(...)`

The repair surface is narrow but important:

- `call target=$illegalImport` becomes `call target=$legalfunc$illegalImport`
- `ref.func $illegalImport` becomes `ref.func $legalfunc$illegalImport`
- `ref.func` nodes are refinalized after the target change

This means the pass is not just an import/export table rewrite.
It also patches code that refers to imported functions directly.

## Phase 6: remove original illegal imports

Only after call-site repair does Binaryen remove the original illegal imports from the module.
That ordering is part of correctness.

## Phase 7: remove helper exports from the export list

At the end of the plain run, Binaryen removes exports named:

- `__get_temp_ret`
- `__set_temp_ret`

Those exports may have been reused in `exported-helpers` mode while building wrappers, but the pass does not leave them exported afterward.

## Temp-ret helper resolution

The high-half side channel is the most important non-obvious piece.

Binaryen resolves helper functions lazily:

- default mode:
  - import `setTempRet0` and `getTempRet0` from `env` if needed
- `exported-helpers` mode:
  - instead reuse already-exported wasm helpers exposed as `__set_temp_ret` and `__get_temp_ret`

So the pass supports both:

- "host will provide temp-ret imports"
- "module already exports emscripten-style temp-ret helpers"

## Exact signature rewriting rules

For the plain pass family:

- every `i64` param becomes two `i32` params in legalized JS-facing signatures
- an `i64` result becomes one visible `i32` result plus hidden high bits through temp-ret
- non-`i64` params/results are preserved

That is why this pass is much smaller in scope than whole-module `i64-to-i32-lowering`.
It does **not** change internal locals, memory ops, arithmetic, or non-boundary function bodies except for call/ref repair.

## The pruning sibling

`LegalizeAndPruneJSInterface` subclasses the plain pass and then runs `prune(module)`.

That extra phase does three things.

### 1. Remove or replace illegal imported/exported functions

The sibling builds a map of exported function names, then checks every imported or exported function for JS-illegal feature use.
Its wider illegality test looks for:

- SIMD
- multivalue
- exception handling
- stack switching

with one subtle rule:

- multivalue params are allowed
- multivalue results are not

If an illegal function is imported, the sibling turns it into a defined function body instead of leaving it imported:

- `nop` for `none` result
- zero literal for defaultable results
- `unreachable` for nondefaultable results

If an illegal function is exported, the sibling removes the export.

### 2. Re-finalize after function pruning

Because signature-visible function refs may have changed, the sibling runs `ReFinalize()` on:

- the module, and
- module code

### 3. Remove illegal global exports

Finally it scans exported globals and removes those whose types still carry illegal JS-surface features.

## Important boundaries

`legalize-js-interface` is **not**:

- a replacement for `i64-to-i32-lowering`
- a generic whole-module `i64` remover
- a broad legalization pass for tables, memories, or arbitrary instructions
- a pass that rewrites all unsupported JS-boundary features in plain mode

The real contract is much narrower:

- plain mode = function import/export `i64` legalization plus import-use repair
- prune sibling = extra removal/stubbing for still-illegal boundary features

## Practical porting lessons

A faithful port should preserve these details:

- export and import legalization are asymmetric wrapper directions
- imported-function repair must update both `call` and `ref.func`
- module-code traversal matters, not just function bodies
- temp-ret helper selection is lazy and flag-controlled
- original illegal imports are removed only after repair
- `export-originals` skips imported functions and `dynCall_*`
- prune mode uses defined stub bodies, not just export deletion

## Current-source drift note

A direct source spot check found the reviewed `version_129` implementation file, helper headers, registration surface, and dedicated lit files unchanged in teaching-relevant ways on current `main`.
So the wiki can treat the tagged release contract here as current on the inspected surfaces.
The immutable source URL set reviewed for this claim is captured in [`../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md).

For the current Starshine status and local code-map bridge, see [`./starshine-strategy.md`](./starshine-strategy.md).
