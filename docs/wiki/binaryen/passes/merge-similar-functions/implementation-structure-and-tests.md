---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md
  - ../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md
  - ../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./profitability-indirection-and-type-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Implementation structure and test map for `merge-similar-functions`

## Core upstream implementation files

## `src/passes/MergeSimilarFunctions.cpp`

This is the real pass.
It contains all major pieces:

- `ParamInfo`
- `EquivalentClass`
- the `MergeSimilarFunctions` pass object
- hash grouping
- equivalence-class formation
- synthetic-param derivation
- profitability testing
- shared-helper construction
- thunk replacement

If you want the actual contract, read this file first.

## `src/passes/pass.cpp`

This file proves two separate facts:

1. the public pass name is **`merge-similar-functions`**
2. Binaryen schedules it in the **late global post-pass phase when `shrinkLevel >= 2`**

That scheduler fact is important enough that it should not be hidden inside the main implementation page.

## `src/pass.h`

This is supporting pass-framework context.
It matters less than the `.cpp`, but it helps anchor that this is a normal module-level pass in Binaryen's pass infrastructure.

## Important helper headers the pass depends on

## `src/ir/hashed.h`

Provides `FunctionHasher`.
This is the coarse grouping engine used before any exact body comparison.

## `src/ir/manipulation.h`

Provides `ExpressionManipulator::flexibleCopy(...)`.
This is the cloning-and-rewrite helper used to create the shared helper body from the primary function.

## `src/ir/module-utils.h`

Provides `ModuleUtils::iterDefinedFunctions(...)`.
This is part of how the pass restricts itself to defined functions.

## `src/ir/names.h`

Provides `Names::getValidFunctionName(...)`.
This is how the synthetic helper gets a safe generated name like `byn$mgfn-shared$...`.

## `src/wasm-limits.h`

Provides `MaxSyntheticFunctionParams`.
This is the hard `255` synthetic-signature-width limit that can block a merge even when the functions are otherwise legal and profitable.

## What the official tests each prove

## `test/lit/passes/merge-similar-functions.wast`

This is the main contract file.
It proves several different things.

### Large constant-only wrappers merge

The test shows large bodies that differ only by `i32.const` payloads becoming:

- one shared helper with an extra `i32` param
- tiny thunks for the originals

### Tiny constant-only wrappers do not necessarily merge

The same file keeps tiny one-instruction wrappers unchanged, demonstrating that profitability matters.

### Synthetic-param reuse works

The “use 42 twice / use 43 twice” family shows that Binaryen can reuse one synthetic param for multiple use sites with the same per-function difference-vector.

### Existing locals are reindexed correctly

The `take-param-and-local-*` and local-offset sections show that adding synthetic params does not break existing non-param locals.

### Direct-callee differences can become function-ref params

With reference types and GC enabled, wrappers that only differ by direct callee can be merged using:

- `ref.func` in thunks
- function-ref synthetic params
- `call_ref` in the shared helper

## `test/lit/passes/merge-similar-functions_all-features.wast`

This file covers harder feature interactions.

### Subtyping-related negative call cases stay unmerged

It proves that some apparently similar call families must still remain separate because there is no single safe function-ref parameter type for the merged helper.

### Tail-call preserving rewrites

It also proves that returning wrapper shapes can preserve tail-call style through `return_call` / `return_call_ref` when the rewrite is valid.

## `test/lit/passes/merge-similar-functions_types.wast`

This file is especially useful for teaching call-target parameterization.

It proves both sides of the rule:

- if differing callees have incompatible function types, the wrappers stay separate
- if differing callees share one function type, Binaryen may merge them and pass `ref.func`s into a shared helper using `call_ref`

This file is the clearest official source for the pass's type barriers.

## `test/lit/passes/merge-similar-functions-param-limit.wast`

This file isolates the signature-width boundary.
It proves:

- a merged helper with `255` params is still legal
- `256` is too many
- the pass must skip over-limit classes

That makes the param-limit rule part of the real public contract, not a hidden implementation detail.

## Practical reading order

If you are new to the pass, read the upstream sources in this order:

1. `test/lit/passes/merge-similar-functions.wast`
2. `src/passes/MergeSimilarFunctions.cpp`
3. `test/lit/passes/merge-similar-functions_types.wast`
4. `test/lit/passes/merge-similar-functions_all-features.wast`
5. `test/lit/passes/merge-similar-functions-param-limit.wast`
6. `src/passes/pass.cpp`

Why this order helps:

- first learn the visible rewrite families
- then learn the implementation that creates them
- then learn the trickier type, feature, and width barriers
- then anchor the scheduler fact

## Current-main drift check

The reviewed `main/src/passes/MergeSimilarFunctions.cpp` matched the `version_129` implementation file on the checked surface.

That means the living dossier can safely keep `version_129` as the main oracle unless later trunk-specific changes appear elsewhere in the surrounding infrastructure.

## Mechanics follow-up

The newer dedicated mechanics page is:

- [`./equivalence-classes-param-derivation-and-thunk-rewrites.md`](./equivalence-classes-param-derivation-and-thunk-rewrites.md)

Use that page when the question is not just “what files matter?” but “what exact algorithm does Binaryen run inside `MergeSimilarFunctions.cpp`?”

For the current local implementation status and exact Starshine code-map, see [`./starshine-strategy.md`](./starshine-strategy.md).

It isolates the source-confirmed details that are easiest to mis-port:

- same-hash versus same-class
- the lockstep DFS parameter-derivation walk
- exact diff-vector reuse
- helper clone-and-rewrite mechanics
- local-index shifting
- original-name-preserving thunk replacement

## Beginner checklist

When reading a potential future Starshine port, verify these concrete pieces exist:

- hash grouping that ignores only the intended differences
- exact structural equivalence checking after hashing
- synthetic-param reuse for repeated identical difference-vectors
- shared-helper creation via clone-and-rewrite
- local-index repair after appending params
- thunk replacement of originals
- feature/type-gated call-target parameterization
- profitability and hard param-count limits

If any one of those is missing, the port is not really implementing the Binaryen pass contract.

## Sources

- [`../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md`](../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md)
- [`../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md`](../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md`](../../../raw/research/0174-2026-04-21-merge-similar-functions-binaryen-research.md)
- [`../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md`](../../../raw/research/0201-2026-04-21-merge-similar-functions-mechanics-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MergeSimilarFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions_types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/merge-similar-functions-param-limit.wast>
