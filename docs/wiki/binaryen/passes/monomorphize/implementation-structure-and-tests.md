---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md
  - ../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-consts.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-mvp.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./binaryen-strategy.md
  - ./call-context-benefit-and-boundaries.md
  - ./clone-construction-signature-rebuild-and-dropped-call-rewrites.md
  - ./wat-shapes.md
---

# Upstream implementation structure and test map for `monomorphize`

The 2026-04-24 raw source manifest for this file map is [`../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md).

## Main implementation files

## `src/passes/Monomorphize.cpp`

This is the actual pass.
It owns almost all of the interesting contract:

- the `CallFinder` that discovers direct-call candidates
- the `CallContext` model
- the reverse-postorder effect-based movement proof for operand code
- the trivial-context fast exit
- cloning and signature rebuilding for specialized functions
- dropped-call result elimination
- local index and local-name repair
- the empirical usefulness gate based on nested optimization and `CostAnalyzer`
- the `MaxParams = 20` hard bailout
- the exported constructors for both `createMonomorphizePass()` and `createMonomorphizeAlwaysPass()`

If a future port disagrees with this file on context building or usefulness policy, it is no longer implementing the same pass.

## `src/passes/pass.cpp`

This file proves the public CLI and registry surface.
It registers:

- `monomorphize`
- `monomorphize-always`

The descriptions here are also the cleanest official proof that the sibling pass is intentionally separate public surface, not just an undocumented test hook.

## Helper files that matter because the pass actually depends on them

### `src/ir/cost.h`

Defines the cost model used for the empirical benefit calculation.
This is what makes the pass “try it, optimize it, and measure it” instead of relying only on front-end heuristics.

### `src/ir/effects.h`

Provides the effect analyses used while deciding which operand subtrees may be moved from caller to callee.
This is core correctness machinery.

### `src/ir/find_all.h`

Used when rebuilding the specialized signature from surviving dynamic `local.get` values embedded in the call context.
That point is easy to miss unless you read the clone builder closely: Binaryen derives the new param list from the transformed context IR itself, not from original operand count alone.

### `src/ir/manipulation.h`

Provides the flexible copy operations that let Binaryen copy whole trees while selectively leaving some children in the caller.

### `src/ir/module-utils.h`

Provides whole-function cloning and defined-function iteration helpers.
Those helpers are part of the pass’s whole-module boundary.

### `src/ir/names.h`

Provides valid fresh names for cloned functions and remapped locals.
This is visible in the printed output and in the lit assertions.

### `src/ir/properties.h`

Used for structural movement boundaries like control-flow-structure checks.

### `src/ir/return-utils.h`

Provides both:

- `findReturnCallers(...)` for the tail-call safety boundary
- `removeReturns(...)` for dropped-call-result specialization

### `src/ir/type-updating.h`

Relevant because specialized functions can have different signatures and result types, even though this pass’s direct type repair surface is smaller than many GC-only passes.

### `src/ir/utils.h`

Supports expression analysis and hashing helpers used around context identity.

### `src/wasm-limits.h`

Provides the broader function-param limitation that the pass’s local `MaxParams` ceiling is designed to stay under.

## Official lit files and what each one proves

## `test/lit/passes/monomorphize-benefit.wast`

This is the single most important behavior file.
It proves that:

- the pass is governed by `monomorphize-min-benefit`
- the usefulness gate is threshold-sensitive
- `0`, `33`, `66`, and `100` really lead to different specialization decisions
- context profitability is measured after nested optimization, not by a single hard-coded syntactic rule
- `-tnh` can make more cases profitable by unlocking deeper simplification

## `test/lit/passes/monomorphize-consts.wast`

This is the direct constant-specialization surface.
It proves the beginner-friendly case most people first expect: constant operands can be reverse-inlined into specialized callees.

## `test/lit/passes/monomorphize-context.wast`

This is the best evidence that the pass is about more than constants.
It exercises richer context building and shows the difference between:

- values or subtrees that may move into the specialized callee
- and values that must remain dynamic caller-side params

It is the strongest official teaching file for the pass’s “context” name.

## `test/lit/passes/monomorphize-drop.wast`

This proves the dropped-result path.
It shows that specializing a dropped call can reverse-inline the outer `drop` into the callee, enabling more cleanup and even changing the specialized function’s result type to `none`.

## `test/lit/passes/monomorphize-limits.wast`

This is the practical limit/bailout file.
It proves that:

- a target with many params can still specialize when enough inputs become fully in-context constants
- but too many surviving dynamic inputs keep the original unspecialized target because the cloned signature would exceed the allowed param budget

## `test/lit/passes/monomorphize-mvp.wast`

This proves the pass still matters without GC-heavy features.
In MVP mode, Binaryen still specializes constant-driven direct calls.
So GC/reference precision is helpful, but not required for the pass to exist.

## `test/lit/passes/monomorphize-types.wast`

This is the best proof that the pass specializes on **more-refined reference types**, not just constants.
It also clearly shows the split between:

- `monomorphize-always`, which keeps such specializations regardless of payoff
- and careful `monomorphize`, which may reject them if no useful optimization follows

## `test/lit/passes/no-inline-monomorphize-inlining.wast`

This proves a very important neighbor relationship:

- monomorphization and inlining can interact
- but monomorphization is still distinct from inlining and from no-inline controls

This file is especially useful when teaching the “reverse-inlining” mental model without collapsing the two passes into one concept.

## Practical source map for a future Starshine port

If the goal is a faithful port, the first implementation reading order should be:

1. `Monomorphize.cpp`
   - understand `CallFinder`, `CallContext`, `processCall`, `makeMonoFunctionWithContext`, and `doOpts`
2. `pass.cpp`
   - confirm CLI names and sibling surface
3. `monomorphize-benefit.wast`
   - understand the usefulness gate
4. `monomorphize-context.wast`
   - understand movable vs nonmovable context
5. `monomorphize-drop.wast`
   - understand dropped-call specialization
6. `monomorphize-types.wast`
   - understand refined-reference specialization
7. `monomorphize-limits.wast`
   - understand the param-count bailout
8. `monomorphize-mvp.wast`
   - keep the non-GC subset honest
9. `no-inline-monomorphize-inlining.wast`
   - understand interaction boundaries with inlining

## Clone-mechanics follow-up page

For the exact source-confirmed bridge from `CallContext` to emitted WAT, see:

- [`./clone-construction-signature-rebuild-and-dropped-call-rewrites.md`](./clone-construction-signature-rebuild-and-dropped-call-rewrites.md)

That page isolates the parts most likely to be mis-ported from the main file:

- signature derivation from surviving `LocalGet`s
- old-param-to-local conversion
- old-var shifting by the param-count delta
- local-name rebuild
- dropped-result `Type::none` plus `removeReturns(...)`
- caller-side `(drop (call ...))` repair in `updateCall(...)`

## What this file map clarifies for beginners

Three things are easy to miss without the source map:

1. The pass is not spread across a dozen algorithm files; most of the behavior is intentionally concentrated in one large pass file.
2. The test surface is broad because the pass’s power comes from interactions with many ordinary optimizations, not from one tiny rewrite family.
3. The sibling `monomorphize-always` mode is part of the official contract and explains why many lit files test both “always” and “careful” modes side by side.

## Sources

- [`../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md)
- [`../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md`](../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md)
- [`../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md`](../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-consts.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-mvp.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>
