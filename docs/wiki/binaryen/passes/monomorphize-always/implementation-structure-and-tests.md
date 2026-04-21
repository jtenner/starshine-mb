---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./usefulness-gate-and-sibling-split.md
  - ./wat-shapes.md
  - ../monomorphize/index.md
---

# Upstream implementation structure and test map for `monomorphize-always`

## Main implementation files

## `src/passes/Monomorphize.cpp`

This is still the real implementation file for the sibling.
It owns almost all of the contract that matters here:

- direct-call discovery
- call-context building
- effect-safe reverse-inlining of movable operands
- specialized-function cloning and signature rebuilding
- dropped-result specialization
- local-index and local-name repair
- parameter-limit enforcement
- the shared nested optimizer
- the constructors for both `createMonomorphizePass()` and `createMonomorphizeAlwaysPass()`

That file structure proves the crucial point:

- `monomorphize-always` is a sibling pass
- but it is not a sibling implementation file

The two public passes are different policy surfaces built on one engine.

## `src/passes/pass.cpp`

This file proves the public CLI and registry surface.
It registers both:

- `monomorphize`
- `monomorphize-always`

That is the cleanest official proof that the sibling is deliberate public API surface, not a local repo invention.

## Helper files that still matter

Even for the always sibling, these helpers matter because the same engine is shared:

- `src/ir/cost.h`
  - still relevant because the family is designed around usefulness measurement even when the sibling bypasses the final rejection policy
- `src/ir/effects.h`
  - core legality proof for moving operand code inward
- `src/ir/find_all.h`
  - used while rebuilding specialized signatures from surviving dynamic `local.get` inputs
- `src/ir/manipulation.h`
  - supports selective subtree copying
- `src/ir/module-utils.h`
  - whole-function cloning and defined-function iteration helpers
- `src/ir/names.h`
  - fresh function and local naming support
- `src/ir/properties.h`
  - structural movement boundaries
- `src/ir/return-utils.h`
  - return-call sensitivity plus dropped-result cleanup support
- `src/ir/type-updating.h`
  - relevant because specialized signatures and result types can change
- `src/wasm-limits.h`
  - broader param-limit context for the pass-local hard cap

## Official lit files and what each one proves for the sibling

## `test/lit/passes/monomorphize-benefit.wast`

This is the single most important file for `monomorphize-always`.
It proves that the sibling exists to bypass the default usefulness policy.

The file shows:

- threshold-sensitive ordinary `monomorphize`
- multiple `monomorphize-min-benefit` settings
- and the sibling mode that keeps the legal specialization without that measured-benefit rejection

Without this file, it would be too easy to describe the sibling as a vague convenience alias.

## `test/lit/passes/monomorphize-types.wast`

This is the best file for understanding why the sibling is pedagogically useful.
It shows refined-reference contexts where specialization is real but the immediate payoff is not always dramatic.

That makes the split visible:

- careful `monomorphize` may reject
- `monomorphize-always` keeps

## `test/lit/passes/monomorphize-context.wast`

This proves the sibling still depends on the same hard context-builder.
It is not free-form cloning.
The same movable-vs-nonmovable context distinction still applies.

## `test/lit/passes/monomorphize-drop.wast`

This proves the sibling still shares the dropped-result specialization surface.
The outer `drop` can still be absorbed into a specialized clone when safe.
The sibling only changes whether weak-payoff versions of that shape survive.

## Practical source map for a future Starshine port

If the goal is a faithful `monomorphize-always` port, the best reading order is:

1. `Monomorphize.cpp`
   - understand the shared engine and find where the always-vs-careful policy split happens
2. `pass.cpp`
   - confirm public pass-name identity
3. `monomorphize-benefit.wast`
   - understand why the sibling exists at all
4. `monomorphize-types.wast`
   - understand the weak-benefit refined-type shapes the sibling keeps visible
5. `monomorphize-context.wast`
   - keep the legality surface honest
6. `monomorphize-drop.wast`
   - keep dropped-result specialization honest

## What this file map clarifies for beginners

Three things are easy to miss without the source map:

1. The sibling is a real public pass name even though it reuses the same main implementation file.
2. The difference is small in code structure but large in user-facing semantics.
3. The official tests rely on the sibling to reveal weak-benefit specialization cases that the default pass intentionally hides.

## Sources

- [`../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md`](../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
