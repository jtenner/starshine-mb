---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0187-2026-04-21-monomorphize-always-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./usefulness-gate-and-sibling-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../monomorphize/index.md
---

# Upstream implementation structure and test map for `monomorphize-always`

## Main implementation files

### `src/passes/Monomorphize.cpp`

This is the owner file for both `monomorphize` and `monomorphize-always`.

For the sibling, it proves:

- the implementation is shared with ordinary `monomorphize`
- an `onlyWhenHelpful` policy flag controls the final usefulness rejection
- the always pass is constructed with that flag disabled
- all earlier legality, clone-construction, and nested-optimization logic remains shared

Important mechanics owned here:

- direct-call discovery
- call-context building
- effect-safe reverse-inlining of movable operands
- specialized-function cloning
- signature rebuilding
- dropped-result specialization
- local-index and local-name repair
- parameter-limit enforcement
- nested optimization
- final keep/reject policy

### `src/passes/pass.cpp`

This file proves the public registry/CLI surface.

It registers both:

- `monomorphize`
- `monomorphize-always`

That registration is the clearest official proof that the sibling is deliberate public API surface, not just a local wiki name or hidden test flag.

## Helper files that still matter

The always sibling inherits the helper surface from ordinary `monomorphize`:

- `src/ir/cost.h` - cost model used by the usefulness story, even though always mode bypasses the final rejection
- `src/ir/effects.h` - movement legality while pulling operand code inward
- `src/ir/find_all.h` - dynamic input discovery while rebuilding signatures
- `src/ir/manipulation.h` - selective subtree copying
- `src/ir/module-utils.h` - defined-function iteration and cloning helpers
- `src/ir/names.h` - fresh function/local naming
- `src/ir/properties.h` - structural movement boundaries
- `src/ir/return-utils.h` - return-call-sensitive dropped-result checks
- `src/ir/type-updating.h` - changed signatures and result types
- `src/wasm-limits.h` - parameter-limit context

A future Starshine port should read these through the parent [`../monomorphize/index.md`](../monomorphize/index.md) dossier and use this page only for the sibling-specific policy split.

## Official lit files

### `test/lit/passes/monomorphize-types.wast`

This is the direct `monomorphize-always` lit proof.

It matters because it runs the sibling and compares it with ordinary `monomorphize` under threshold tuning on refined-reference/type-sensitive cases. Use this file when proving that the sibling's public behavior is real.

### `test/lit/passes/monomorphize-benefit.wast`

This file proves the neighboring usefulness-threshold story for ordinary `monomorphize`.

Important correction: it is not direct `--monomorphize-always` proof. Older wiki wording used it too broadly. It should now be cited as supporting evidence for the policy axis, not as a sibling execution test.

### `test/lit/passes/monomorphize-context.wast`

This file proves the inherited context-builder surface: the pass family is not free-form cloning. Context must be movable and meaningful.

### `test/lit/passes/monomorphize-drop.wast`

This file proves the inherited dropped-result specialization surface. Always mode changes whether weak-payoff versions survive, not the safety rule for absorbing a dropped result.

### `test/lit/passes/monomorphize-consts.wast`

This file proves constant-context specialization shapes inherited by the sibling.

### `test/lit/passes/monomorphize-limits.wast`

This file proves parameter-limit boundaries inherited by the sibling.

### `test/lit/passes/monomorphize-mvp.wast`

This file keeps the MVP-only feature boundary honest.

### `test/lit/passes/no-inline-monomorphize-inlining.wast`

This file proves the neighboring interaction with inlining/no-inline metadata; it is shared family evidence rather than sibling-specific proof.

## Practical reading order

For a future Starshine port:

1. `Monomorphize.cpp` - understand the shared engine and `onlyWhenHelpful` split.
2. `pass.cpp` - confirm public pass identity.
3. `monomorphize-types.wast` - study direct `--monomorphize-always` behavior.
4. `monomorphize-benefit.wast` - study ordinary benefit-threshold policy.
5. `monomorphize-context.wast` - keep movement legality honest.
6. `monomorphize-drop.wast` - keep dropped-result specialization honest.
7. Local [`./starshine-strategy.md`](./starshine-strategy.md) - map the future port into Starshine's current boundary-only surfaces.

## What this map clarifies

- The sibling is a real public pass even though it has no separate implementation file.
- The code difference is small, but the user-visible semantics are large.
- Direct sibling proof comes from `monomorphize-types.wast`; threshold-policy proof comes from `monomorphize-benefit.wast`.
- Starshine must not treat existing `monomorphize_min_benefit` option storage as implementation of the sibling.

## Sources

- [`../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-always-primary-sources.md)
- [`../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md`](../../../raw/research/0318-2026-04-24-monomorphize-always-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
