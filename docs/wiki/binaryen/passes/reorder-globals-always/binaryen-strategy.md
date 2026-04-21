---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md
  - ../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./small-module-threshold-scoring-and-proof.md
  - ./wat-shapes.md
  - ../reorder-globals/index.md
---

# Binaryen strategy for `reorder-globals-always`

## What the pass really is

The reviewed source makes `reorder-globals-always` a **whole-module declaration-layout sibling** of `reorder-globals`.

The best mental model is:

- run the same counting pass
- build the same initializer dependency graph
- try the same candidate orders
- rebuild the same global declaration list
- but do so even on tiny modules and score those candidates with a smooth synthetic model

So the pass is not:

- a separate optimization family
- a generic global simplifier
- or merely a comment-level alias for the production pass

## Public surface and sibling split

`src/passes/pass.cpp` registers two related pass names:

- `reorder-globals`
- `reorder-globals-always`

The corresponding constructors in `ReorderGlobals.cpp` and `passes.h` make the implementation split explicit too:

- `createReorderGlobalsPass()`
- `createReorderGlobalsAlwaysPass()`

That gives the sibling a real public identity even though the implementation logic is shared.

## Default scheduler placement

A key negative fact matters here:

- the repo's current canonical no-DWARF `-O` / `-Os` page schedules `reorder-globals`
- it does **not** schedule `reorder-globals-always`

So this dossier is a justified tracker expansion for a real local-registry pass outside the current parity queue.

## The shared core algorithm still applies

Because both variants live in the same `ReorderGlobals.cpp` engine, `reorder-globals-always` still performs these same phases:

1. scan `global.get` and `global.set` uses in functions and module code
2. convert name counts into original-index vectors
3. derive a dependency DAG from `global.get` traffic inside non-imported global initializers
4. generate four dependency-safe candidate orders
5. score the candidates and keep the earliest strict minimum
6. rebuild `module->globals` in the chosen order and refresh maps

The only major public differences are the small-module gate and the cost model.

## The central policy difference

In ordinary `reorder-globals`, the pass returns immediately when:

- there are fewer than `128` globals
- and the `always` flag is false

`reorder-globals-always` removes that early return.

This means:

- small modules can still reorder
- tiny lit tests become informative
- internal fixup callers can rely on the reorder even when real byte savings would be invisible

This is the first important correction to the name.
`always` does **not** mean "ignore dependencies" or "do a different transform."
It means "run the same transform even when production mode would intentionally no-op."

## The scoring-model difference

The second key split is how candidate orders are scored.
The refreshed folder now has a dedicated proof page for the exact formula and the lit-backed examples that exercise it: [`./small-module-threshold-scoring-and-proof.md`](./small-module-threshold-scoring-and-proof.md).

### Production `reorder-globals`

The production pass uses the real stepped ULEB-size intuition.
A global at index `0..127` has one-byte index cost, then later thresholds cost more bytes.
So the real pass only sees a difference when an order crosses a byte-width boundary.

### `reorder-globals-always`

The sibling uses a smooth synthetic score:

- `1.0 + (i / 128.0)`

That makes later positions gradually more expensive even before a real binary-size step would occur.
The source comments describe this as unrealistic but smooth, and mainly useful for testing.

A good beginner summary is:

- public pass = real byte model
- always sibling = smooth teaching and small-module model

## Why validity still matters

Even in always mode, the same correctness surface remains active.
The pass still preserves:

- imports before defined globals
- topological legality from initializer dependencies
- original-order tie stability when scores are equal

So `reorder-globals-always` is **less profitability-conservative**, not **less correctness-conservative**.

## Internal use by `GlobalStructInference`

The strongest source-backed practical reason the sibling matters is in `GlobalStructInference.cpp`.
When that pass adds fresh helper globals during un-nesting, it creates a nested `PassRunner`, adds `reorder-globals-always`, marks the runner nested, and runs it.

That proves the sibling is not only a teaching or test surface.
It is also a real internal repair tool.

The important lesson is:

- production `reorder-globals` is a late size pass
- `reorder-globals-always` is also the small-module declaration-repair sibling

## Positive rewrite families the sibling makes easiest to observe

## 1. Tiny independent-global modules

A tiny module with two independent globals can visibly reorder under `reorder-globals-always` even though ordinary `reorder-globals` would do nothing.

## 2. Small dependency chains with one hot prerequisite or one hot dependent

Because the sibling removes the cutoff, small hand-written modules can still demonstrate:

- dependency-before-dependent ordering
- independent-hot-global wins
- full-sum versus greedy candidate differences

## 3. Fresh-global repair after `GlobalStructInference`

The sibling is the mode that keeps helper globals before their new users even when the module is too small for the public pass to care about byte-size savings.

## Negative families that remain negative

`reorder-globals-always` still refuses or preserves:

- orders that would put imports after defined globals
- orders that violate initializer `global.get` dependencies
- meaningless name-based ordering claims
- global-value or dead-global rewrites outside declaration order

This is the most important beginner correction to the word `always`.

## What a future Starshine port must preserve

1. Separate public identity for `reorder-globals-always` in the registry and CLI.
2. Shared engine with ordinary `reorder-globals`.
3. The removed `< 128` early return in always mode.
4. The smooth synthetic scoring model in always mode.
5. The same imports-first and dependency-preserving comparator logic.
6. The same earliest-best tie behavior.
7. The same nested-use role from `GlobalStructInference`.

## Sources

- [`../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md`](../../../raw/research/0188-2026-04-21-reorder-globals-always-binaryen-research.md)
- [`../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md`](../../../raw/research/0214-2026-04-21-reorder-globals-always-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/support/topological_sort.h>
